import Foundation
import AVFoundation

/// Plays voice cues and short tones through the phone speaker. TTS for
/// coaching is produced either by AVSpeechSynthesizer (offline, works on
/// any phone) or by the Gemini / Pi route when configured.
@MainActor
@Observable
final class AudioService {
    private let synth = AVSpeechSynthesizer()
    private var engine: AVAudioEngine?

    /// Voice gender preference — maps to an AVSpeechSynthesisVoice.
    var gender: Gender = .male
    enum Gender: String, CaseIterable, Identifiable, Codable {
        case male, female
        var id: String { rawValue }
        var label: String { self == .male ? "Male" : "Female" }
    }

    /// Language code for voice (en, es, zh, hi, fr, ar, bn, pt, ru, ja).
    var language: String = "en"

    /// Master volume, 0…1
    var volume: Double = 1.0

    private(set) var isSpeaking = false

    init() {
        // Configure the audio session so the app plays in the background
        // mix and doesn't duck ambient audio aggressively.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio,
                                                         options: [.mixWithOthers, .duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Speech -----------------------------------------------------

    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        synth.stopSpeaking(at: .immediate)
        let utter = AVSpeechUtterance(string: text)
        utter.voice = pickVoice()
        utter.rate = 0.47            // slightly below AVSpeechUtteranceDefaultSpeechRate
        utter.pitchMultiplier = 0.98
        utter.volume = Float(volume)
        utter.preUtteranceDelay = 0.05
        synth.speak(utter)
        isSpeaking = true
    }

    func stopSpeaking() {
        synth.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    private func pickVoice() -> AVSpeechSynthesisVoice? {
        let target = regionCode(for: language)
        let all = AVSpeechSynthesisVoice.speechVoices()
        let filtered = all.filter { $0.language.hasPrefix(target) }
        // Prefer premium/enhanced voices if the user has downloaded them.
        let ranked = filtered.sorted { a, b in
            rank(a) > rank(b)
        }
        if let gendered = ranked.first(where: { voiceGender($0) == gender }) { return gendered }
        return ranked.first ?? AVSpeechSynthesisVoice(language: target)
    }

    private func rank(_ v: AVSpeechSynthesisVoice) -> Int {
        switch v.quality {
        case .premium: return 3
        case .enhanced: return 2
        default: return 1
        }
    }

    /// Heuristic gender assignment — AVSpeechSynthesisVoice.gender is
    /// available on iOS 17+ but can be .unspecified. Fall back to name.
    private func voiceGender(_ v: AVSpeechSynthesisVoice) -> Gender {
        if v.gender == .female { return .female }
        if v.gender == .male { return .male }
        let maleNames = ["Daniel", "Alex", "Thomas", "Fred", "Aaron", "Diego", "Jorge"]
        if maleNames.contains(where: { v.name.contains($0) }) { return .male }
        return .female
    }

    private func regionCode(for code: String) -> String {
        switch code {
        case "en": return "en-US"
        case "es": return "es-US"
        case "zh": return "zh-CN"
        case "hi": return "hi-IN"
        case "fr": return "fr-FR"
        case "ar": return "ar-SA"
        case "bn": return "bn-IN"
        case "pt": return "pt-BR"
        case "ru": return "ru-RU"
        case "ja": return "ja-JP"
        default:   return "en-US"
        }
    }

    // MARK: - Tones ------------------------------------------------------

    /// Play a short pacing beep. Used during align phase when the user is
    /// moving but not yet inside tolerance — pitch + tempo scale with
    /// distance to target (handled by the session engine caller).
    func beep(frequency: Double = 820, durationS: Double = 0.08, volume: Double = 0.3) {
        // Build a sine tone in memory and play via AVAudioEngine.
        let sampleRate = 44100.0
        let frameCount = AVAudioFrameCount(sampleRate * durationS)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        let ch = buffer.floatChannelData![0]
        let amp = Float(volume)
        let a = Int(sampleRate * 0.008), d = Int(sampleRate * 0.035)
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            var env: Float = 1
            if i < a { env = Float(i) / Float(a) }
            if i > Int(frameCount) - d {
                let u = Float(Int(frameCount) - i) / Float(d)
                env = u * u
            }
            ch[i] = amp * env * Float(sin(2 * .pi * frequency * t))
        }

        let eng = engine ?? AVAudioEngine()
        if engine == nil { engine = eng }
        let player = AVAudioPlayerNode()
        eng.attach(player)
        eng.connect(player, to: eng.mainMixerNode, format: format)
        if !eng.isRunning { try? eng.start() }
        player.scheduleBuffer(buffer, completionHandler: {
            DispatchQueue.main.async { eng.detach(player) }
        })
        player.play()
    }
}
