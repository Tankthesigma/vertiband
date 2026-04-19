import SwiftUI

struct CompleteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(GeminiService.self) private var gemini
    @Environment(AudioService.self) private var audio
    @Environment(SessionStore.self) private var store

    let record: SessionRecord
    let score: Double
    @State private var scoreAnim: Double = 0
    @State private var aiNote: String? = nil
    @State private var loadingNote = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.s6) {
                header
                scoreCard
                recoveryCard
                aiNoteCard
                stepBreakdown
                bottomActions
            }
            .padding(.horizontal, Theme.Space.s6)
            .padding(.top, Theme.Space.s8)
            .padding(.bottom, Theme.Space.s16)
        }
        .background(Theme.Palette.paper.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 1.3, dampingFraction: 0.78).delay(0.1)) {
                scoreAnim = score
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Task { await fetchNote() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s3) {
            HStack {
                Text("Session complete").eyebrow()
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Palette.fg2)
                        .frame(width: 36, height: 36)
                        .background(Theme.Palette.paper2)
                        .clipShape(Circle())
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Nicely").displayXL()
                Text("done.").displayXL(italic: true).foregroundStyle(Theme.Palette.fg2)
            }
        }
    }

    private var scoreCard: some View {
        PaperCard(padding: Theme.Space.s6) {
            VStack(alignment: .leading, spacing: Theme.Space.s5) {
                Text("VertiScore").eyebrow()
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s5) {
                    Text(String(format: "%.0f", scoreAnim))
                        .font(Theme.Font.display(112, weight: .bold))
                        .foregroundStyle(Theme.Palette.ink)
                        .contentTransition(.numericText(value: scoreAnim))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Grade").font(Theme.Font.mono(11)).kerning(1.4)
                            .textCase(.uppercase).foregroundStyle(Theme.Palette.fg3)
                        Text(record.grade ?? "—")
                            .font(Theme.Font.display(36, weight: .semibold))
                            .foregroundStyle(Theme.Palette.signal)
                    }
                }
                Divider().overlay(Theme.Palette.line)
                Text(label(for: score))
                    .font(Theme.Font.body(15)).foregroundStyle(Theme.Palette.fg2)
            }
        }
    }

    private var recoveryCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: Theme.Space.s3) {
                Text("Recovery probability").eyebrow()
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%.0f%%", (record.recoveryProbability ?? 0) * 100))
                        .font(Theme.Font.display(48, weight: .semibold))
                        .foregroundStyle(Theme.Palette.ink)
                    Spacer()
                    Text(expected(record.recoveryProbability ?? 0))
                        .font(Theme.Font.body(13))
                        .foregroundStyle(Theme.Palette.fg3)
                }
                probabilityBar(value: record.recoveryProbability ?? 0)
            }
        }
    }

    private func probabilityBar(value: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Palette.paper2)
                Capsule().fill(LinearGradient(colors: [Theme.Palette.signal, Color(hex: 0xF7D3B0)],
                                              startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * value)
            }
        }
        .frame(height: 10)
    }

    private var aiNoteCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: Theme.Space.s3) {
                Text("Clinical note").eyebrow()
                if let note = aiNote {
                    Text(note).bodyLg()
                } else if loadingNote {
                    HStack(spacing: 8) {
                        ProgressView().tint(Theme.Palette.signal)
                        Text("Writing your note…").font(Theme.Font.body(14))
                            .foregroundStyle(Theme.Palette.fg3)
                    }
                } else {
                    Text("Add a Gemini API key in Settings to get a personalized note after each session.")
                        .font(Theme.Font.body(13))
                        .foregroundStyle(Theme.Palette.fg3)
                }
            }
        }
    }

    private var stepBreakdown: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: Theme.Space.s3) {
                Text("By step").eyebrow()
                ForEach(record.steps, id: \.name) { s in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name).font(Theme.Font.body(14, weight: .semibold))
                                .foregroundStyle(Theme.Palette.ink)
                            Text(s.description).font(Theme.Font.body(12))
                                .foregroundStyle(Theme.Palette.fg3)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(String(format: "%.0f s", s.holdActualS))
                                .font(Theme.Font.mono(13))
                                .foregroundStyle(Theme.Palette.ink)
                            Text("hold").font(Theme.Font.mono(10))
                                .foregroundStyle(Theme.Palette.fg3)
                        }
                    }
                    .padding(.vertical, 6)
                    if s.name != record.steps.last?.name {
                        Divider().overlay(Theme.Palette.line)
                    }
                }
            }
        }
    }

    private var bottomActions: some View {
        VStack(spacing: Theme.Space.s3) {
            PillButton(title: "Done", kind: .primary) { dismiss() }
            PillButton(title: "Speak clinical note", kind: .ghost, icon: "speaker.wave.2") {
                if let n = aiNote { audio.speak(n) }
            }
            .disabled(aiNote == nil)
            .opacity(aiNote == nil ? 0.4 : 1)
        }
    }

    // MARK: - AI fetch

    private func fetchNote() async {
        guard gemini.hasKey else { return }
        loadingNote = true
        let note = await gemini.sessionSummary(record, language: audio.language)
        aiNote = note
        loadingNote = false
        // Persist the note back to the record
        if let note, var r = store.records.first(where: { $0.id == record.id }) {
            r.aiSummary = note
            store.save(r)
        }
    }

    // MARK: - Copy

    private func label(for score: Double) -> String {
        switch score {
        case 85...:   return "That was a textbook execution. Save this one."
        case 75..<85: return "Very solid. A couple of stages were a little loose — try for steadier holds next time."
        case 65..<75: return "Okay. Some stages drifted out of tolerance. Try again after a short rest."
        case 50..<65: return "You pushed through. Tomorrow will be easier if you take it slower."
        default:      return "Something was off. Try again in a quieter spot with the phone held firmly."
        }
    }

    private func expected(_ p: Double) -> String {
        if p > 0.85 { return "This session alone may be enough." }
        if p > 0.6  { return "1 more session likely." }
        if p > 0.35 { return "2 more sessions likely." }
        return "A few sessions may be needed."
    }
}
