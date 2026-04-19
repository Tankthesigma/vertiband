import Foundation

/// Optional connection to a VertiBand hardware Pi on the local network.
/// When configured, the app can:
///   • push text to the Pi's amplifier for spoken cues
///   • check connectivity + battery (future)
@MainActor
@Observable
final class PiBridge {
    var baseURL: String {
        get { UserDefaults.standard.string(forKey: "us.vertiband.pi.url") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "us.vertiband.pi.url") }
    }

    private(set) var isReachable: Bool = false
    private(set) var lastError: String?

    func probe() async {
        guard let url = URL(string: baseURL + ":5060/") else {
            isReachable = false; return
        }
        var req = URLRequest(url: url); req.timeoutInterval = 3
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                isReachable = true; lastError = nil
            } else { isReachable = false; lastError = "HTTP error" }
        } catch {
            isReachable = false
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    func speak(_ text: String, lang: String = "en", gender: String = "male") async -> Bool {
        guard !baseURL.isEmpty else { return false }
        guard let url = URL(string: baseURL + ":5060/api/speak") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 4
        let body: [String: Any] = ["text": text, "lang": lang, "gender": gender]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func stop() async {
        guard !baseURL.isEmpty, let url = URL(string: baseURL + ":5060/api/stop") else { return }
        var req = URLRequest(url: url); req.httpMethod = "POST"; req.timeoutInterval = 2
        _ = try? await URLSession.shared.data(for: req)
    }
}
