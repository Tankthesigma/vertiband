import SwiftUI

struct SessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MotionService.self) private var motion
    @Environment(AudioService.self) private var audio
    @Environment(GeminiService.self) private var gemini
    @Environment(PiBridge.self) private var pi
    @Environment(SessionStore.self) private var store

    let side: EpleyConfig.Side
    let severity: Int

    @State private var engine: SessionEngine? = nil
    @State private var showComplete = false
    @State private var confirmAbort = false

    var body: some View {
        ZStack {
            // Dark canvas for the session — focus mode
            LinearGradient(colors: [Color(hex: 0x0A0F1A), Color(hex: 0x13192A)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            starfield.ignoresSafeArea()

            if let engine {
                VStack(spacing: Theme.Space.s5) {
                    topBar(engine: engine)
                    Spacer(minLength: 0)
                    stepTitle(engine: engine)
                    PoseCanvas(pose: engine.pose,
                               target: PoseCanvas.Pose(pitch: engine.currentStep?.pitch ?? 0,
                                                       roll: engine.currentStep?.roll ?? 0),
                               aligned: engine.isAligned,
                               phase: engine.phase)
                        .frame(maxWidth: 360)
                        .aspectRatio(1, contentMode: .fit)
                    phaseMeter(engine: engine)
                    hintStack(engine: engine)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Theme.Space.s5)
                .padding(.vertical, Theme.Space.s6)
                .foregroundStyle(Theme.Palette.fgD1)
            } else {
                ProgressView().tint(.white)
            }
        }
        .statusBarHidden()
        .onAppear {
            let e = SessionEngine(side: side, motion: motion, audio: audio, gemini: gemini, pi: pi)
            e.language = audio.language
            e.voice = audio.gender
            engine = e
            e.start()
        }
        .onChange(of: engine?.phase) {
            if engine?.phase == .complete {
                if let e = engine { store.save(e.record) }
                showComplete = true
            }
        }
        .fullScreenCover(isPresented: $showComplete, onDismiss: { dismiss() }) {
            if let e = engine, let score = e.record.vertiscore {
                CompleteView(record: e.record, score: score)
            }
        }
        .confirmationDialog("End session now?", isPresented: $confirmAbort) {
            Button("End session", role: .destructive) { engine?.abort(); dismiss() }
            Button("Keep going", role: .cancel) { }
        }
    }

    // MARK: - Top bar + meters

    private func topBar(engine: SessionEngine) -> some View {
        HStack {
            Button { confirmAbort = true } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.08))
                    .clipShape(Circle())
            }
            Spacer()
            Text(phaseLabel(engine))
                .font(Theme.Font.mono(11)).kerning(1.9).textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            StepCounter(index: engine.stepIndex, total: EpleyConfig.steps(for: engine.side).count)
        }
    }

    private func phaseLabel(_ e: SessionEngine) -> String {
        switch e.phase {
        case .idle, .calibrating: return "Calibrating"
        case .align: return "Find the pose"
        case .hold: return "Hold steady"
        case .transitionBetweenSteps: return "Nice"
        case .complete: return "Complete"
        }
    }

    private func stepTitle(engine: SessionEngine) -> some View {
        VStack(spacing: Theme.Space.s2) {
            if let step = engine.currentStep {
                Text(step.name).font(Theme.Font.mono(11)).kerning(1.8).textCase(.uppercase)
                    .foregroundStyle(Theme.Palette.cyan)
                Text(step.description)
                    .font(Theme.Font.display(32, weight: .medium, italic: false))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .id(step.id)
            } else {
                Text("Get ready").displayM(italic: true).foregroundStyle(.white)
            }
        }
        .animation(Theme.Motion.easeBase, value: engine.currentStep?.id)
    }

    private func phaseMeter(engine: SessionEngine) -> some View {
        VStack(spacing: Theme.Space.s2) {
            // Hold progress ring — visible during hold
            if engine.phase == .hold, let step = engine.currentStep {
                let frac = min(1, engine.holdElapsed / step.holdS)
                HStack {
                    Text("Hold").font(Theme.Font.mono(11)).kerning(1.6).textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text(String(format: "%0.0f / %0.0f s", engine.holdElapsed, step.holdS))
                        .font(Theme.Font.mono(12))
                        .foregroundStyle(.white.opacity(0.9))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.08))
                        Capsule().fill(
                            LinearGradient(colors: [Theme.Palette.cyan, Color(hex: 0x7BDDEB)],
                                           startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * frac)
                    }
                }
                .frame(height: 8)
            } else {
                HStack {
                    Text(engine.isAligned ? "Locked" : "Move into the box")
                        .font(Theme.Font.mono(11)).kerning(1.6).textCase(.uppercase)
                        .foregroundStyle(engine.isAligned ? Theme.Palette.success : Theme.Palette.cyan)
                    Spacer()
                }
                Capsule().fill(.white.opacity(0.06)).frame(height: 8)
            }
        }
    }

    private func hintStack(engine: SessionEngine) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(engine.hints.prefix(3), id: \.self) { h in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle().fill(Theme.Palette.cyan).frame(width: 6, height: 6)
                    Text(h).font(Theme.Font.body(14)).foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(.vertical, 2)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(Theme.Motion.easeFast, value: engine.hints)
    }

    // MARK: - Starfield background
    private var starfield: some View {
        Canvas { ctx, size in
            let count = 60
            var rng = SeededRNG(seed: 42)
            for _ in 0..<count {
                let x = Double(rng.next()) * size.width
                let y = Double(rng.next()) * size.height
                let r = 0.4 + Double(rng.next()) * 1.4
                let a = 0.08 + Double(rng.next()) * 0.22
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(a)))
            }
        }
    }
}

struct StepCounter: View {
    let index: Int
    let total: Int
    var body: some View {
        let i = max(0, min(index + 1, total))
        return HStack(spacing: 3) {
            Text(String(format: "%02d", i))
                .font(Theme.Font.mono(12))
                .foregroundStyle(Theme.Palette.cyan)
            Text("/ \(total)")
                .font(Theme.Font.mono(12))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

// Deterministic small RNG so the starfield doesn't re-shuffle on every frame
struct SeededRNG {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}
