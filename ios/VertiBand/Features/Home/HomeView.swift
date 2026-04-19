import SwiftUI

struct HomeView: View {
    @Environment(SessionStore.self) private var store
    @Environment(PiBridge.self) private var pi
    @State private var showPreSession = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.s6) {
                header
                readyCard
                if !store.records.isEmpty { trendCard }
                aboutRow
            }
            .padding(.horizontal, Theme.Space.s6)
            .padding(.top, Theme.Space.s4)
            .padding(.bottom, Theme.Space.s16)
        }
        .background(Theme.Palette.paper.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await pi.probe() }
        .fullScreenCover(isPresented: $showPreSession) { PreSessionView() }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: Theme.Space.s2) {
                Wordmark()
                Text(greeting).eyebrow()
            }
            Spacer()
            StatusPill(tone: pi.isReachable ? .success : .neutral,
                       label: pi.isReachable ? "Band connected" : "Phone mode")
        }
        .padding(.top, Theme.Space.s3)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello"
        }
    }

    private var readyCard: some View {
        PaperCard(padding: Theme.Space.s6) {
            VStack(alignment: .leading, spacing: Theme.Space.s5) {
                Text("Ready to begin?").displayL()
                Text("The session takes about three minutes. Find a quiet place to sit and a bed or couch behind you.")
                    .bodyLg()
                HStack(spacing: Theme.Space.s3) {
                    statBubble("3", "min")
                    statBubble("5", "steps")
                    statBubble("30s", "holds")
                }
                PillButton(title: "Begin session", kind: .primary, icon: "arrow.right") {
                    showPreSession = true
                }
                .padding(.top, Theme.Space.s2)
            }
        }
    }

    private func statBubble(_ v: String, _ k: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(Theme.Font.display(30, weight: .semibold))
                .foregroundStyle(Theme.Palette.ink)
            Text(k).font(Theme.Font.mono(11))
                .kerning(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Palette.fg3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Space.s3)
        .padding(.horizontal, Theme.Space.s4)
        .background(Theme.Palette.paper2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.R.md))
    }

    private var trendCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: Theme.Space.s4) {
                HStack {
                    Text("Recent trend").eyebrow()
                    Spacer()
                    Text("\(store.records.count) sessions")
                        .font(Theme.Font.mono(11)).foregroundStyle(Theme.Palette.fg3)
                }
                SparklineView(values: Array(store.records.prefix(10).reversed().compactMap { $0.vertiscore }))
                    .frame(height: 64)
                HStack {
                    VStack(alignment: .leading) {
                        Text(String(format: "%.0f", store.averageScore))
                            .font(Theme.Font.display(36, weight: .semibold))
                        Text("Average VertiScore").font(Theme.Font.mono(11))
                            .kerning(1.4).textCase(.uppercase).foregroundStyle(Theme.Palette.fg3)
                    }
                    Spacer()
                }
            }
        }
    }

    private var aboutRow: some View {
        NavigationLink(destination: AboutView()) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("About this method").font(Theme.Font.body(15, weight: .semibold))
                        .foregroundStyle(Theme.Palette.ink)
                    Text("What the Epley maneuver does, and why it works")
                        .font(Theme.Font.body(13))
                        .foregroundStyle(Theme.Palette.fg3)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.Palette.fg3)
            }
            .padding(.vertical, Theme.Space.s3)
        }
    }
}

struct SparklineView: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Axes
                Path { p in
                    p.move(to: CGPoint(x: 0, y: geo.size.height * 0.5))
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height * 0.5))
                }
                .stroke(Theme.Palette.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                // Line
                if values.count > 1 {
                    let minV = max(0, (values.min() ?? 0) - 10)
                    let maxV = min(100, (values.max() ?? 100) + 10)
                    let range = max(1, maxV - minV)
                    Path { p in
                        for i in values.indices {
                            let x = CGFloat(i) / CGFloat(max(values.count - 1, 1)) * geo.size.width
                            let y = geo.size.height - CGFloat((values[i] - minV) / range) * geo.size.height
                            if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                            else { p.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(Theme.Palette.signal, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    // Last point glow
                    let last = values.last ?? 0
                    let x = geo.size.width
                    let y = geo.size.height - CGFloat((last - minV) / range) * geo.size.height
                    Circle().fill(Theme.Palette.signal)
                        .frame(width: 8, height: 8)
                        .position(x: x, y: y)
                        .shadow(color: Theme.Palette.signalGlow, radius: 8)
                }
            }
        }
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.s5) {
                Text("About").eyebrow()
                Text("The Epley maneuver.").displayL()
                Group {
                    Text("Benign paroxysmal positional vertigo (BPPV) happens when tiny calcium crystals in your inner ear shift into the wrong canal. The Epley maneuver is a sequence of head positions that uses gravity to move them back where they belong.")
                    Text("Each position has a target angle, held for about thirty seconds. Done correctly, most people see relief in one to three sessions. Done incorrectly, it feels pointless — and that is the problem VertiBand solves.")
                    Text("VertiBand tracks your head orientation one hundred times per second. If your pose is within 15° of the target, the stage unlocks and the timer starts. If you drift, you hear a gentle tone. If you want a calmer experience, toggle voice off in settings.")
                }
                .bodyLg()
            }
            .padding(Theme.Space.s6)
        }
        .background(Theme.Palette.paper.ignoresSafeArea())
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
