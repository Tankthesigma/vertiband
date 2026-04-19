import Foundation

/// Thin wrapper over the Gemini REST API. Uses a Gemini API key
/// (aistudio.google.com/app/apikey) which the user pastes into Settings
/// and which is stored in the iOS keychain.
///
/// Two flows:
///   • liveHint(context:) — one short coaching sentence for the current
///     held position. Low latency, max 60 tokens.
///   • sessionSummary(session:) — 3-paragraph therapist-style note.
@MainActor
@Observable
final class GeminiService {
    private let keychainKey = "us.vertiband.app.geminiApiKey"
    private let model = "gemini-2.5-flash"

    var hasKey: Bool { apiKey?.isEmpty == false }
    var apiKey: String? {
        get { Keychain.string(forKey: keychainKey) }
        set { Keychain.set(newValue, forKey: keychainKey) }
    }

    private let liveSystem = """
    You are a calm, encouraging physical therapist guiding a patient through the Epley \
    maneuver for BPPV vertigo. You see realtime pose and sway data. Reply with ONE short \
    spoken sentence (max 12 words) that coaches the patient in this exact moment. \
    No preamble, no punctuation other than a period. Be warm, confident, and concrete.
    """

    private let summarySystem = """
    You are a vestibular physical therapist writing a brief post-session note for a \
    patient who just completed the Epley maneuver at home. Use plain language a patient \
    understands. 3 short paragraphs: (1) what went well, (2) what to improve, \
    (3) a clear next step. No medical jargon unless you explain it. Total under 120 words.
    """

    // MARK: - API calls --------------------------------------------------

    func liveHint(context: [String: Any], language: String = "en") async -> String? {
        await generate(systemInstruction: liveSystem + langSuffix(language),
                       prompt: jsonString(context),
                       maxTokens: 80,
                       temperature: 0.4)
    }

    func sessionSummary(_ session: SessionRecord, language: String = "en") async -> String? {
        let compact: [String: Any] = [
            "side": session.side.rawValue,
            "vertiscore": session.vertiscore ?? NSNull(),
            "recovery_probability": session.recoveryProbability ?? NSNull(),
            "nystagmus_peak_ratio": session.nystagmusPeakRatio ?? NSNull(),
            "steps": session.steps.map { s in
                [
                    "name": s.name,
                    "align_time_s": s.alignTimeS,
                    "hold_actual_s": s.holdActualS,
                    "hold_target_s": s.holdTargetS,
                    "sway": [
                        "rms_gyro_deg_s": s.sway.rmsGyroDegS,
                        "drift_deg": s.sway.driftDeg,
                        "aligned_fraction": s.sway.alignedFraction
                    ]
                ] as [String: Any]
            }
        ]
        return await generate(systemInstruction: summarySystem + langSuffix(language),
                              prompt: jsonString(compact),
                              maxTokens: 400,
                              temperature: 0.5)
    }

    // MARK: - Core call --------------------------------------------------

    private func generate(systemInstruction: String,
                          prompt: String,
                          maxTokens: Int,
                          temperature: Double) async -> String? {
        guard let key = apiKey, !key.isEmpty else { return nil }
        let urlStr = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)"
        guard let url = URL(string: urlStr) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "systemInstruction": [
                "parts": [ ["text": systemInstruction] ]
            ],
            "contents": [
                [ "role": "user", "parts": [ ["text": prompt] ] ]
            ],
            "generationConfig": [
                "temperature": temperature,
                "maxOutputTokens": maxTokens,
                "thinkingConfig": ["thinkingBudget": 0]
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return parseText(data)
        } catch {
            return nil
        }
    }

    private func parseText(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = obj["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String
        else { return nil }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func jsonString(_ v: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: v, options: [.sortedKeys]),
              let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }

    private func langSuffix(_ code: String) -> String {
        let code = code.prefix(2).lowercased()
        switch code {
        case "en": return ""
        case "es": return " Your entire reply MUST be written in Spanish (Latin script). No English words."
        case "zh": return " Your entire reply MUST be written in Mandarin Chinese (Simplified Han characters). No English words."
        case "hi": return " Your entire reply MUST be written in Hindi (Devanagari script). No English words."
        case "fr": return " Your entire reply MUST be written in French. No English words."
        case "ar": return " Your entire reply MUST be written in Arabic (Arabic script). No English words."
        case "bn": return " Your entire reply MUST be written in Bengali (Bengali script). No English words."
        case "pt": return " Your entire reply MUST be written in Portuguese. No English words."
        case "ru": return " Your entire reply MUST be written in Russian (Cyrillic). No English words."
        case "ja": return " Your entire reply MUST be written in Japanese (native script). No English words."
        default:   return ""
        }
    }
}

// MARK: - Keychain helper ------------------------------------------------

enum Keychain {
    static func string(forKey key: String) -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var ref: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &ref) == errSecSuccess,
              let data = ref as? Data,
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }
    static func set(_ value: String?, forKey key: String) {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(q as CFDictionary)
        guard let v = value, !v.isEmpty, let data = v.data(using: .utf8) else { return }
        var attrs = q
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attrs as CFDictionary, nil)
    }
}
