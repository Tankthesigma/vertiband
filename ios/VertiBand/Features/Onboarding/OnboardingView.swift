import SwiftUI

struct OnboardingView: View {
    let done: () -> Void
    @State private var page = 0
    private let pages: [Page] = [
        .init(eyebrow: "Welcome to VertiBand",
              title: "Vertigo. Verified.",
              body: "VertiBand watches your head while you do the Epley maneuver, and tells you when you got it right.",
              icon: "waveform.path.ecg"),
        .init(eyebrow: "How it works",
              title: "Five positions. Thirty seconds each.",
              body: "We guide you through each step. The sensor confirms each stage before advancing — no skipping, no guessing.",
              icon: "figure.mind.and.body"),
        .init(eyebrow: "Your data",
              title: "Every session, logged.",
              body: "Angles, timing, and a clinical note you can share with your doctor. Stored on your phone. Yours alone.",
              icon: "lock.shield")
    ]
    struct Page { let eyebrow, title, body, icon: String }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Palette.paper.ignoresSafeArea()

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    pageView(pages[i]).tag(i).padding(.horizontal, Theme.Space.s6)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(Theme.Motion.easeBase, value: page)

            VStack(spacing: Theme.Space.s5) {
                dots
                PillButton(title: page == pages.count - 1 ? "Begin" : "Continue",
                           kind: .primary,
                           icon: page == pages.count - 1 ? "arrow.right" : nil) {
                    if page < pages.count - 1 { withAnimation(Theme.Motion.easeBase) { page += 1 } }
                    else { done() }
                }
                Button("Skip", action: done)
                    .font(Theme.Font.body(13, weight: .medium))
                    .foregroundStyle(Theme.Palette.fg3)
            }
            .padding(Theme.Space.s6)
            .padding(.bottom, Theme.Space.s4)
        }
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Theme.Palette.signal : Theme.Palette.line2)
                    .frame(width: i == page ? 24 : 6, height: 6)
                    .animation(Theme.Motion.easeBase, value: page)
            }
        }
    }

    @ViewBuilder
    private func pageView(_ p: Page) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s5) {
            Spacer(minLength: 0)
            ZStack {
                RoundedRectangle(cornerRadius: Theme.R.xxl)
                    .fill(Theme.Palette.paper2)
                    .aspectRatio(1.05, contentMode: .fit)
                    .overlay(RoundedRectangle(cornerRadius: Theme.R.xxl).strokeBorder(Theme.Palette.line, lineWidth: 1))
                Image(systemName: p.icon)
                    .font(.system(size: 92, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.Palette.ink, Theme.Palette.signal],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            .padding(.horizontal, Theme.Space.s2)
            VStack(alignment: .leading, spacing: Theme.Space.s3) {
                Text(p.eyebrow).eyebrow()
                Text(p.title).displayL()
                Text(p.body).bodyLg()
            }
            Spacer(minLength: Theme.Space.s20)
        }
    }
}
