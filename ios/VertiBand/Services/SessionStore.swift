import Foundation

/// Persists session records to UserDefaults as JSON. For a production
/// shipping app you'd use SwiftData or CoreData; for a conference demo
/// + <200 sessions this is perfectly adequate and zero-friction.
@MainActor
@Observable
final class SessionStore {
    private let key = "us.vertiband.app.sessions"
    private(set) var records: [SessionRecord] = []

    init() { load() }

    func save(_ record: SessionRecord) {
        if let idx = records.firstIndex(where: { $0.id == record.id }) {
            records[idx] = record
        } else {
            records.insert(record, at: 0)
        }
        persist()
    }

    func remove(_ record: SessionRecord) {
        records.removeAll { $0.id == record.id }
        persist()
    }

    func clearAll() { records = []; persist() }

    var averageScore: Double {
        let scored = records.compactMap { $0.vertiscore }
        guard !scored.isEmpty else { return 0 }
        return scored.reduce(0, +) / Double(scored.count)
    }

    // MARK: - JSON ------------------------------------------------------

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        if let list = try? dec.decode([SessionRecord].self, from: data) {
            self.records = list
        }
    }
    private func persist() {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
