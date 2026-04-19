import SwiftUI

/// Design tokens that mirror `tokens.css` on the marketing site.
/// Paper-cream canvas, ink-navy text, warm terracotta accent.
enum Theme {
    // MARK: - Palette
    enum Palette {
        static let paper     = Color(hex: 0xF4F1EC)   // canvas
        static let paper2    = Color(hex: 0xECE8E1)
        static let paper3    = Color(hex: 0xE3DBC9)
        static let canvas    = Color.white
        static let ink       = Color(hex: 0x0F2341)   // primary text
        static let ink2      = Color(hex: 0x1B3358)
        static let line      = Color(hex: 0x1D2C38).opacity(0.10)
        static let line2     = Color(hex: 0x1D2C38).opacity(0.22)

        static let fg1       = Color(hex: 0x1D2C38)
        static let fg2       = Color(hex: 0x3A4A5E)
        static let fg3       = Color(hex: 0x6B7687)
        static let fgMute    = Color(hex: 0x96A0AE)

        // on dark surfaces
        static let fgD1      = Color(hex: 0xF2F5FA)
        static let fgD2      = Color(hex: 0xAEB7C8)
        static let fgD3      = Color(hex: 0x6E7A8F)

        // accent — warm terracotta, never electric
        static let signal      = Color(hex: 0xC85A3A)
        static let signalGlow  = Color(red: 0.78, green: 0.35, blue: 0.23).opacity(0.35)
        static let signalSoft  = Color(hex: 0xC85A3A).opacity(0.10)

        // semantic
        static let success   = Color(hex: 0x3ACF8E)
        static let warning   = Color(hex: 0xE5B93A)
        static let danger    = Color(hex: 0xE5624F)

        // cool cyan available for dark UI if needed (matches the live-gyro page)
        static let cyan      = Color(hex: 0x5ED4E5)
    }

    // MARK: - Typography (built into the system; falls back to SF Pro-style defaults)
    enum Font {
        // "Fraunces" is our brand display face on web. Ship the app without a bundled font
        // to keep the initial install small — the system New York serif is the nearest
        // match on iOS 17+ and reads as editorial. Swap to a bundled Fraunces TTF later.
        static func display(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular, italic: Bool = false) -> SwiftUI.Font {
            var f: SwiftUI.Font = .system(size: size, weight: weight, design: .serif)
            if italic { f = f.italic() }
            return f
        }
        static func body(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .default)
        }
        static func mono(_ size: CGFloat, weight: SwiftUI.Font.Weight = .medium) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
        static let eyebrow = body(11, weight: .semibold)
        static let metric  = display(56, weight: .bold)
    }

    // MARK: - Spacing scale (4px base, same as the site)
    enum Space {
        static let s1: CGFloat = 4
        static let s2: CGFloat = 8
        static let s3: CGFloat = 12
        static let s4: CGFloat = 16
        static let s5: CGFloat = 20
        static let s6: CGFloat = 24
        static let s8: CGFloat = 32
        static let s10: CGFloat = 40
        static let s12: CGFloat = 48
        static let s16: CGFloat = 64
        static let s20: CGFloat = 80
    }

    // MARK: - Radii
    enum R {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
        static let pill: CGFloat = 999
    }

    // MARK: - Motion
    enum Motion {
        static let easeBase: Animation = .spring(response: 0.55, dampingFraction: 0.82)
        static let easeFast: Animation = .spring(response: 0.35, dampingFraction: 0.85)
        static let easeSlow: Animation = .spring(response: 0.80, dampingFraction: 0.78)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Text styles ----------------------------------------------------

extension Text {
    func eyebrow() -> some View {
        self.font(Theme.Font.eyebrow)
            .kerning(1.9)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Palette.fg3)
    }
    func displayXL(italic: Bool = false) -> some View {
        self.font(Theme.Font.display(56, weight: .medium, italic: italic))
            .kerning(-1)
            .foregroundStyle(Theme.Palette.ink)
    }
    func displayL(italic: Bool = false) -> some View {
        self.font(Theme.Font.display(40, weight: .medium, italic: italic))
            .kerning(-0.5)
            .foregroundStyle(Theme.Palette.ink)
    }
    func displayM(italic: Bool = false) -> some View {
        self.font(Theme.Font.display(28, weight: .medium, italic: italic))
            .kerning(-0.3)
            .foregroundStyle(Theme.Palette.ink)
    }
    func bodyLg() -> some View {
        self.font(Theme.Font.body(17, weight: .regular))
            .foregroundStyle(Theme.Palette.fg2)
    }
    func bodyRegular() -> some View {
        self.font(Theme.Font.body(15))
            .foregroundStyle(Theme.Palette.fg2)
    }
    func mono(_ size: CGFloat = 13) -> some View {
        self.font(Theme.Font.mono(size))
            .kerning(0.6)
            .foregroundStyle(Theme.Palette.fg3)
    }
}
