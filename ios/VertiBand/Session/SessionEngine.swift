import Foundation
import SwiftUI

/// State machine that drives one Epley session. Consumes pose samples
/// from MotionService, emits phase changes, and accumulates per-step
/// SwayMetrics. Modeled after `state_machine.py` + `sway.py` on the Pi.
@MainActor
@Observable
final class SessionEngine {
    enum Phase: Equatable {
        case idle, calibrating, align, hold, transitionBetweenSteps, complete
    }

    // ---- inputs ------------------------------------------------------------
    let side: EpleyConfig.Side

    // ---- services ---------------------------------------------------------
    private let motion: MotionService
    private let audio: AudioService
    private let gemini: GeminiService
    private let pi: PiBridge

    // ---- state exposed to views ------------------------------------------
    private(set) var phase: Phase = .idle
    private(set) var stepIndex: Int = -1
    private(set) var currentStep: EpleyConfig.Step? = nil
    private(set) var holdElapsed: Double = 0
    private(set) var alignElapsed: Double = 0
    private(set) var pose: Pose = .zero
    private(set) var isAligned: Bool = false
    private(set) var latestHint: String? = nil
    private(set) var record: SessionRecord
    private(set) var hints: [String] = []

    struct Pose: Equatable { var pitch: Double = 0; var roll: Double = 0; var yaw: Double = 0
        static let zero = Pose() }

    // ---- working buffers --------------------------------------------------
    private var samplePitch: [Double] = []
    private var sampleRoll: [Double] = []
    private var sampleGyroMag: [Double] = []
    private var stepStart: Date? = nil
    private var alignStart: Date? = nil
    private var holdStart: Date? = nil
    private var tickTimer: Timer? = nil
    private var lastHintTime: Date = .distantPast

    // ---- language/voice (surfaced from UI) --------------------------------
    var language: String = "en"
    var voice: AudioService.Gender = .male

    init(side: EpleyConfig.Side, motion: MotionService, audio: AudioService,
         gemini: GeminiService, pi: PiBridge) {
        self.side = side
        self.motion = motion
        self.audio = audio
        self.gemini = gemini
        self.pi = pi
        self.record = SessionRecord(side: side, steps: EpleyConfig.steps(for: side).map {
            SessionRecord.StepRecord(name: $0.name, description: $0.description,
                                     targetPitch: $0.pitch, targetRoll: $0.roll,
                                     targetYaw: $0.yaw, holdTargetS: $0.holdS)
        })
    }

    // MARK: - Lifecycle -----------------------------------------------------

    func start() {
        motion.start()
        motion.calibrate()
        phase = .calibrating
        audio.gender = voice
        audio.language = language
        speak("Starting \(side.title) Epley maneuver. Sit up and look straight ahead.")
        // Calibration window
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.advanceStep()
        }
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / EpleyConfig.sampleRateHz, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func abort() {
        phase = .idle
        tickTimer?.invalidate()
        motion.stop()
        audio.stopSpeaking()
        Task { await pi.stop() }
    }

    // MARK: - Tick ----------------------------------------------------------

    private func tick() {
        // Pull latest pose from motion service.
        pose = Pose(pitch: motion.pitch, roll: motion.roll, yaw: motion.yaw)
        guard let step = currentStep else { return }

        // Alignment check uses pitch+roll only; yaw can drift on a phone.
        let within = abs(pose.pitch - step.pitch) <= EpleyConfig.pitchToleranceDeg
                  && abs(pose.roll  - step.roll)  <= EpleyConfig.rollToleranceDeg
        isAligned = within

        samplePitch.append(pose.pitch)
        sampleRoll.append(pose.roll)
        sampleGyroMag.append(motion.gyroMag)

        switch phase {
        case .align:
            alignElapsed = stepStart?.timeIntervalSinceNow.magnitude ?? 0
            if within {
                if alignStart == nil { alignStart = Date() }
                if Date().timeIntervalSince(alignStart!) >= EpleyConfig.stabilityTimeS {
                    enterHold()
                }
            } else {
                alignStart = nil
            }
            // Distance pacing beep
            let dist = max(abs(pose.pitch - step.pitch), abs(pose.roll - step.roll))
            if !within && motion.gyroMag > 3 {
                maybePacingBeep(distance: dist, tolerance: 15)
            }
        case .hold:
            if let s = holdStart { holdElapsed = Date().timeIntervalSince(s) }
            if holdElapsed >= step.holdS {
                completeStep()
            } else {
                maybeRequestLiveHint(step: step, within: within)
            }
        default: break
        }
    }

    // MARK: - Transitions ---------------------------------------------------

    private func advanceStep() {
        stepIndex += 1
        let steps = EpleyConfig.steps(for: side)
        guard stepIndex < steps.count else {
            finish()
            return
        }
        currentStep = steps[stepIndex]
        phase = .align
        stepStart = Date()
        alignStart = nil
        holdStart = nil
        alignElapsed = 0
        holdElapsed = 0
        isAligned = false
        samplePitch = []; sampleRoll = []; sampleGyroMag = []
        speak(currentStep!.description)
    }

    private func enterHold() {
        guard currentStep != nil else { return }
        phase = .hold
        holdStart = Date()
        speak("Hold steady.")
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func completeStep() {
        guard let step = currentStep else { return }
        phase = .transitionBetweenSteps
        let holdActual = holdElapsed
        let alignSec = stepStart.map { Date().timeIntervalSince($0) - holdActual } ?? 0
        let sway = computeSway(target: step)
        if let idx = record.steps.firstIndex(where: { $0.name == step.name }) {
            record.steps[idx].alignTimeS = alignSec
            record.steps[idx].holdActualS = holdActual
            record.steps[idx].sway = sway
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        speak("Good. Next.")
        // Brief transition pause, then next step
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            self?.advanceStep()
        }
    }

    private func finish() {
        phase = .complete
        tickTimer?.invalidate()
        motion.stop()
        let scored = VertiScore.compute(from: record.steps)
        record.vertiscore = scored.score
        record.grade = scored.grade
        record.recoveryProbability = scored.recoveryProbability
        record.endDate = Date()
        speak("Session complete. Your VertiScore is \(Int(scored.score.rounded())).")
    }

    // MARK: - Sway math -----------------------------------------------------

    private func computeSway(target: EpleyConfig.Step) -> SessionRecord.SwayMetrics {
        let n = samplePitch.count
        guard n > 1 else { return .zero }
        let dt = 1.0 / EpleyConfig.sampleRateHz
        var path = 0.0
        var within = 0
        for i in 1..<n {
            let dp = samplePitch[i] - samplePitch[i-1]
            let dr = sampleRoll[i]  - sampleRoll[i-1]
            path += sqrt(dp*dp + dr*dr)
        }
        for i in 0..<n {
            if abs(samplePitch[i] - target.pitch) <= 15
            && abs(sampleRoll[i]  - target.roll)  <= 15 {
                within += 1
            }
        }
        let rmsGyro = sqrt(sampleGyroMag.map { $0*$0 }.reduce(0, +) / Double(n))
        let duration = Double(n) * dt
        return .init(
            swayAreaDeg2: ellipseArea(x: sampleRoll, y: samplePitch),
            pathLengthDeg: path,
            meanVelocityDegS: path / duration,
            rmsGyroDegS: rmsGyro,
            f50Hz: 0, f95Hz: 0,
            driftDeg: hypot(samplePitch.last! - samplePitch.first!,
                            sampleRoll.last!  - sampleRoll.first!),
            alignedFraction: Double(within) / Double(n),
            nSamples: n, durationS: duration
        )
    }

    private func ellipseArea(x: [Double], y: [Double]) -> Double {
        guard x.count > 2, y.count == x.count else { return 0 }
        let mx = x.reduce(0, +) / Double(x.count)
        let my = y.reduce(0, +) / Double(y.count)
        var cxx = 0.0, cyy = 0.0, cxy = 0.0
        for i in 0..<x.count {
            let dx = x[i] - mx, dy = y[i] - my
            cxx += dx*dx; cyy += dy*dy; cxy += dx*dy
        }
        let n = Double(x.count - 1)
        cxx /= n; cyy /= n; cxy /= n
        let trace = cxx + cyy
        let det   = cxx * cyy - cxy * cxy
        let disc  = max(0, trace*trace/4 - det)
        let l1 = max(0, trace/2 + disc.squareRoot())
        let l2 = max(0, trace/2 - disc.squareRoot())
        return .pi * 5.991 * (l1 * l2).squareRoot()
    }

    // MARK: - Audio coordination -------------------------------------------

    private func speak(_ text: String) {
        audio.speak(text)
        if !pi.baseURL.isEmpty {
            Task { await pi.speak(text, lang: language, gender: voice.rawValue) }
        }
    }

    private var lastBeepAt: Date = .distantPast
    private func maybePacingBeep(distance: Double, tolerance: Double) {
        // Closer = higher pitch, shorter interval, capped ranges
        let maxDist = 45.0
        let x = max(0, min(1, (distance - tolerance) / max(maxDist - tolerance, 1)))
        let freq = 420 + (1000 - 420) * (1 - x)
        let interval = 0.22 + (1.4 - 0.22) * x
        if Date().timeIntervalSince(lastBeepAt) >= interval {
            lastBeepAt = Date()
            audio.beep(frequency: freq, volume: 0.25)
        }
    }

    private func maybeRequestLiveHint(step: EpleyConfig.Step, within: Bool) {
        guard gemini.hasKey, Date().timeIntervalSince(lastHintTime) > 5.0,
              holdElapsed > 2, step.holdS - holdElapsed > 3 else { return }
        lastHintTime = Date()
        let ctx: [String: Any] = [
            "target": ["pitch": step.pitch, "roll": step.roll, "yaw": step.yaw],
            "actual": ["pitch": Int(pose.pitch.rounded()), "roll": Int(pose.roll.rounded())],
            "step_name": step.id,
            "seconds_held": Int(holdElapsed.rounded()),
            "seconds_remaining": Int((step.holdS - holdElapsed).rounded()),
            "aligned": within
        ]
        Task { [weak self] in
            guard let self, let hint = await self.gemini.liveHint(context: ctx, language: self.language) else { return }
            await MainActor.run {
                self.latestHint = hint
                self.hints.insert(hint, at: 0)
                if self.hints.count > 6 { self.hints.removeLast() }
                self.speak(hint)
            }
        }
    }
}

// MARK: - VertiScore composite -------------------------------------------

enum VertiScore {
    struct Result { let score: Double; let grade: String; let recoveryProbability: Double }
    static func compute(from steps: [SessionRecord.StepRecord]) -> Result {
        guard !steps.isEmpty else { return .init(score: 0, grade: "N/A", recoveryProbability: 0) }
        // Per-step sub-scores
        let perStep = steps.map { step -> Double in
            let hold = min(step.holdActualS / max(step.holdTargetS, 1), 1.2) - 0.5
            let align = -log(max(step.alignTimeS, 0.1) / 3.0)
            let stab = -log(max(step.sway.rmsGyroDegS, 0.01) / 6.0)
            let prec = (step.sway.alignedFraction - 0.5) * 2.0
            let drift = -log(max(step.sway.driftDeg, 0.1) / 6.0)
            let z = 0.9*align + 1.2*hold + 1.0*stab + 1.6*prec + 0.6*drift
            return 100 / (1 + exp(-z * 0.6))
        }
        let weights = steps.map { max($0.holdTargetS, 1) }
        let total = zip(perStep, weights).map(*).reduce(0, +) / weights.reduce(0, +)
        let grade: String = total >= 85 ? "A" : total >= 75 ? "B" : total >= 65 ? "C" : total >= 50 ? "D" : "F"
        // Rough recovery probability: sigmoid of (score - 70)/10
        let p = 1 / (1 + exp(-(total - 70) / 10))
        return .init(score: total, grade: grade, recoveryProbability: p)
    }
}
