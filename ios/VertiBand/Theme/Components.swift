import SwiftUI

// MARK: - Buttons --------------------------------------------------------

struct PillButton: View {
    let title: String
    var kind: Kind = .primary
    var icon: String? = nil
    var action: () -> Void

    enum Kind { case primary, ghost, destructive }

    var body: some View {
        Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); action() }) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(Theme.Font.body(15, weight: .semibold))
            .padding(.horizontal, 22)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(background)
            .foregroundStyle(foreground)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.R.pill)
                    .strokeBorder(strokeColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.R.pill))
        }
        .buttonStyle(.plain)
    }

    private var background: Color {
        switch kind {
        case .primary: return Theme.Palette.ink
        case .ghost: return .clear
        case .destructive: return Theme.Palette.danger
        }
    }
    private var foreground: Color {
        switch kind {
        case .primary, .destructive: return Theme.Palette.paper
        case .ghost: return Theme.Palette.ink
        }
    }
    private var strokeColor: Color {
        switch kind {
        case .primary: return Theme.Palette.ink
        case .ghost: return Theme.Palette.line2
        case .destructive: return Theme.Palette.danger
        }
    }
}

// MARK: - Cards ----------------------------------------------------------

struct PaperCard<Content: View>: View {
    let content: () -> Content
    var padding: CGFloat = Theme.Space.s5

    init(padding: CGFloat = Theme.Space.s5, @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .background(Theme.Palette.canvas)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.R.lg)
                    .strokeBorder(Theme.Palette.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.R.lg))
            .shadow(color: Theme.Palette.ink.opacity(0.04), radius: 2, y: 1)
            .shadow(color: Theme.Palette.ink.opacity(0.05), radius: 20, y: 8)
    }
}

struct DarkCard<Content: View>: View {
    let content: () -> Content
    var padding: CGFloat = Theme.Space.s5

    init(padding: CGFloat = Theme.Space.s5, @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .background(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.R.xl)
                    .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.R.xl))
    }
}

// MARK: - Status pill ----------------------------------------------------

struct StatusPill: View {
    enum Tone { case neutral, success, warning, signal }
    let tone: Tone
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(dotColor).frame(width: 6, height: 6)
                .shadow(color: dotColor.opacity(0.7), radius: 5)
            Text(label).font(Theme.Font.body(12, weight: .semibold))
                .foregroundStyle(textColor)
                .kerning(0.4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(bg)
        .overlay(RoundedRectangle(cornerRadius: Theme.R.pill).strokeBorder(bg.opacity(2), lineWidth: 0))
        .clipShape(RoundedRectangle(cornerRadius: Theme.R.pill))
    }

    private var dotColor: Color {
        switch tone {
        case .neutral: return Theme.Palette.fgMute
        case .success: return Theme.Palette.success
        case .warning: return Theme.Palette.warning
        case .signal:  return Theme.Palette.signal
        }
    }
    private var textColor: Color {
        switch tone {
        case .neutral: return Theme.Palette.fg2
        case .success: return Theme.Palette.success
        case .warning: return Theme.Palette.warning
        case .signal:  return Theme.Palette.signal
        }
    }
    private var bg: Color {
        switch tone {
        case .neutral: return Theme.Palette.paper2
        case .success: return Color(hex: 0x3ACF8E).opacity(0.12)
        case .warning: return Color(hex: 0xE5B93A).opacity(0.12)
        case .signal:  return Theme.Palette.signalSoft
        }
    }
}

// MARK: - Eyebrow label --------------------------------------------------

struct Eyebrow: View {
    let label: String
    var body: some View {
        Text(label).eyebrow()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Wordmark -------------------------------------------------------

struct Wordmark: View {
    var body: some View {
        HStack(spacing: 2) {
            Text("Verti").font(Theme.Font.display(22, weight: .regular))
            Text("Band").font(Theme.Font.display(22, weight: .semibold))
            Text(".").font(Theme.Font.display(22, weight: .regular, italic: true))
        }
        .foregroundStyle(Theme.Palette.ink)
        .kerning(-0.3)
    }
}

struct BrandMark: View {
    var size: CGFloat = 36
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Theme.Palette.ink, Theme.Palette.ink2],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Text("V").font(Theme.Font.display(size * 0.5, weight: .semibold, italic: true))
                .foregroundStyle(Theme.Palette.paper)
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.Palette.signalGlow, radius: 10)
    }
}

// MARK: - Section header -------------------------------------------------

struct SectionHeader: View {
    let eyebrow: String
    let title: String
    var italicTail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s3) {
            Text(eyebrow).eyebrow()
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title).displayM()
                if let italicTail {
                    Text(italicTail).displayM(italic: true)
                        .foregroundStyle(Theme.Palette.fg2)
                }
            }
        }
    }
}
