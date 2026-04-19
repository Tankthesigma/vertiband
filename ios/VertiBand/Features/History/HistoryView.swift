import SwiftUI

struct HistoryView: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.s5) {
                SectionHeader(eyebrow: "Sessions", title: "Your", italicTail: "trace.")
                    .padding(.horizontal, Theme.Space.s6)
                    .padding(.top, Theme.Space.s4)

                if store.records.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: Theme.Space.s3) {
                        ForEach(store.records) { r in
                            NavigationLink(destination: HistoryDetailView(record: r)) {
                                HistoryRow(record: r).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.Space.s6)
                }
            }
            .padding(.bottom, Theme.Space.s16)
        }
        .background(Theme.Palette.paper.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: Theme.Space.s3) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(Theme.Palette.fg3)
            Text("No sessions yet").font(Theme.Font.body(15, weight: .medium))
                .foregroundStyle(Theme.Palette.ink)
            Text("Finish a session and it will appear here.")
                .font(Theme.Font.body(13))
                .foregroundStyle(Theme.Palette.fg3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.s20)
    }
}

struct HistoryRow: View {
    let record: SessionRecord
    var body: some View {
        PaperCard {
            HStack(alignment: .center, spacing: Theme.Space.s4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateString).font(Theme.Font.mono(11)).kerning(1.4)
                        .textCase(.uppercase).foregroundStyle(Theme.Palette.fg3)
                    Text(record.side.title).font(Theme.Font.body(15, weight: .semibold))
                        .foregroundStyle(Theme.Palette.ink)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(record.vertiscore.map { String(format: "%.0f", $0) } ?? "—")
                        .font(Theme.Font.display(28, weight: .semibold))
                        .foregroundStyle(Theme.Palette.ink)
                    Text(record.grade.map { "Grade \($0)" } ?? "")
                        .font(Theme.Font.mono(10))
                        .foregroundStyle(Theme.Palette.signal)
                }
                Image(systemName: "chevron.right").foregroundStyle(Theme.Palette.fg3)
            }
        }
    }
    private var dateString: String {
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
        return df.string(from: record.startDate)
    }
}

struct HistoryDetailView: View {
    let record: SessionRecord
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.s5) {
                VStack(alignment: .leading, spacing: Theme.Space.s2) {
                    Text(dateString).eyebrow()
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Session").displayL()
                        Text(record.side.title.lowercased() + ".").displayL(italic: true)
                            .foregroundStyle(Theme.Palette.fg2)
                    }
                }
                PaperCard {
                    HStack(spacing: Theme.Space.s6) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("VertiScore").eyebrow()
                            Text(String(format: "%.0f", record.vertiscore ?? 0))
                                .font(Theme.Font.display(56, weight: .bold))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Grade").eyebrow()
                            Text(record.grade ?? "—")
                                .font(Theme.Font.display(28, weight: .semibold))
                                .foregroundStyle(Theme.Palette.signal)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recovery").eyebrow()
                            Text(String(format: "%.0f%%", (record.recoveryProbability ?? 0) * 100))
                                .font(Theme.Font.display(28, weight: .semibold))
                        }
                    }
                }
                if let note = record.aiSummary {
                    PaperCard {
                        VStack(alignment: .leading, spacing: Theme.Space.s2) {
                            Text("Clinical note").eyebrow()
                            Text(note).bodyLg()
                        }
                    }
                }
                PaperCard {
                    VStack(alignment: .leading, spacing: Theme.Space.s3) {
                        Text("By step").eyebrow()
                        ForEach(record.steps, id: \.name) { s in
                            HStack {
                                Text(s.name).font(Theme.Font.body(14, weight: .semibold))
                                    .foregroundStyle(Theme.Palette.ink)
                                Spacer()
                                Text(String(format: "%.1f°", s.sway.driftDeg))
                                    .font(Theme.Font.mono(12))
                                    .foregroundStyle(Theme.Palette.fg3)
                                Text(String(format: "%.0f / %.0f s", s.holdActualS, s.holdTargetS))
                                    .font(Theme.Font.mono(12))
                                    .foregroundStyle(Theme.Palette.fg3)
                            }
                            if s.name != record.steps.last?.name {
                                Divider().overlay(Theme.Palette.line)
                            }
                        }
                    }
                }
            }
            .padding(Theme.Space.s6)
        }
        .background(Theme.Palette.paper.ignoresSafeArea())
        .navigationTitle(record.side.title)
        .navigationBarTitleDisplayMode(.inline)
    }
    private var dateString: String {
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
        return df.string(from: record.startDate)
    }
}
