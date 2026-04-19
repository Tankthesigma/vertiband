import SwiftUI

struct PreSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var stage: Stage = .side
    @State private var selectedSide: EpleyConfig.Side? = nil
    @State private var severity: Int = 5
    @State private var startSession = false

    enum Stage { case side, severity, ready }

    var body: some View {
        ZStack {
            Theme.Palette.paper.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Theme.Space.s6) {
                topBar
                Spacer(minLength: 0)
                content.transition(.opacity.combined(with: .move(edge: .trailing)))
                Spacer(minLength: 0)
                bottomNav
            }
            .padding(.horizontal, Theme.Space.s6)
        }
        .fullScreenCover(isPresented: $startSession) {
            if let side = selectedSide {
                SessionView(side: side, severity: severity)
            }
        }
    }

    // MARK: - Bars

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Palette.fg2)
                    .frame(width: 36, height: 36)
                    .background(Theme.Palette.paper2)
                    .clipShape(Circle())
            }
            Spacer()
            Text(stageLabel).font(Theme.Font.mono(11)).kerning(1.6).textCase(.uppercase)
                .foregroundStyle(Theme.Palette.fg3)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.top, Theme.Space.s4)
    }

    private var bottomNav: some View {
        VStack(spacing: Theme.Space.s3) {
            HStack(spacing: 6) {
                progressDot(.side)
                progressDot(.severity)
                progressDot(.ready)
            }
            PillButton(title: primaryTitle, kind: .primary,
                       icon: stage == .ready ? "arrow.right" : nil) { advance() }
                .disabled(stage == .side && selectedSide == nil)
                .opacity(stage == .side && selectedSide == nil ? 0.4 : 1)
        }
        .padding(.bottom, Theme.Space.s6)
    }

    private func progressDot(_ s: Stage) -> some View {
        let active = s == stage
        return Capsule()
            .fill(active ? Theme.Palette.signal : Theme.Palette.line2)
            .frame(width: active ? 24 : 6, height: 6)
            .animation(Theme.Motion.easeBase, value: stage)
    }

    private var stageLabel: String {
        switch stage {
        case .side:     return "01 · Which side"
        case .severity: return "02 · How you feel"
        case .ready:    return "03 · Get ready"
        }
    }

    private var primaryTitle: String {
        switch stage {
        case .side:     return "Continue"
        case .severity: return "Continue"
        case .ready:    return "Start session"
        }
    }

    private func advance() {
        withAnimation(Theme.Motion.easeBase) {
            switch stage {
            case .side:     stage = .severity
            case .severity: stage = .ready
            case .ready:    startSession = true
            }
        }
    }

    // MARK: - Pages

    @ViewBuilder private var content: some View {
        switch stage {
        case .side:     sidePicker
        case .severity: severityPicker
        case .ready:    readyPage
        }
    }

    private var sidePicker: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s5) {
            Text("Which ear feels off?").displayL()
            Text("Pick the side where positional vertigo is worst. Not sure? Pick the side you felt spinning last.")
                .bodyLg()
            HStack(spacing: Theme.Space.s3) {
                sideCard(.left)
                sideCard(.right)
            }
        }
    }

    private func sideCard(_ side: EpleyConfig.Side) -> some View {
        let picked = selectedSide == side
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(Theme.Motion.easeBase) { selectedSide = side }
        } label: {
            VStack(alignment: .leading, spacing: Theme.Space.s3) {
                Text(side == .left ? "Left" : "Right").displayM()
                Text(side == .left ? "Left ear affected" : "Right ear affected")
                    .font(Theme.Font.body(13)).foregroundStyle(Theme.Palette.fg3)
                Spacer()
                HStack {
                    Circle().fill(picked ? Theme.Palette.signal : Theme.Palette.paper2)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.Palette.paper)
                                .opacity(picked ? 1 : 0)
                        )
                    Spacer()
                }
            }
            .padding(Theme.Space.s5)
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
            .background(picked ? Theme.Palette.ink : Theme.Palette.canvas)
            .foregroundStyle(picked ? Theme.Palette.paper : Theme.Palette.ink)
            .overlay(RoundedRectangle(cornerRadius: Theme.R.lg)
                .strokeBorder(picked ? Theme.Palette.ink : Theme.Palette.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.R.lg))
        }
        .buttonStyle(.plain)
    }

    private var severityPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s5) {
            Text("How intense today?").displayL()
            Text("Your current vertigo, roughly 0 (gone) to 10 (can't stand up).")
                .bodyLg()
            VStack(spacing: Theme.Space.s4) {
                Text("\(severity)")
                    .font(Theme.Font.display(96, weight: .bold))
                    .foregroundStyle(severity > 7 ? Theme.Palette.danger
                                     : severity > 3 ? Theme.Palette.signal
                                     : Theme.Palette.success)
                    .contentTransition(.numericText(value: Double(severity)))
                    .animation(Theme.Motion.easeFast, value: severity)
                Slider(value: Binding(get: { Double(severity) },
                                      set: { severity = Int($0.rounded()) }), in: 0...10, step: 1)
                    .tint(Theme.Palette.signal)
                HStack {
                    Text("Gone").font(Theme.Font.mono(11))
                    Spacer()
                    Text("Severe").font(Theme.Font.mono(11))
                }
                .foregroundStyle(Theme.Palette.fg3)
            }
            .padding(Theme.Space.s5)
            .background(Theme.Palette.canvas)
            .clipShape(RoundedRectangle(cornerRadius: Theme.R.lg))
            .overlay(RoundedRectangle(cornerRadius: Theme.R.lg)
                .strokeBorder(Theme.Palette.line, lineWidth: 1))
        }
    }

    private var readyPage: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s5) {
            Text("You're set.").displayL()
            PaperCard {
                VStack(alignment: .leading, spacing: Theme.Space.s4) {
                    row("Side", selectedSide?.title ?? "—")
                    row("Severity", "\(severity) / 10")
                    row("Estimated time", "3 min")
                    Divider().overlay(Theme.Palette.line)
                    Text("Tips")
                        .font(Theme.Font.mono(11)).kerning(1.4).textCase(.uppercase).foregroundStyle(Theme.Palette.fg3)
                    Label("Sit on the edge of a bed", systemImage: "bed.double")
                    Label("Hold the phone flat against your forehead like a headband", systemImage: "iphone")
                    Label("Or place the phone on a table and wear the VertiBand band", systemImage: "waveform")
                }
                .font(Theme.Font.body(14))
                .foregroundStyle(Theme.Palette.fg2)
            }
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(Theme.Font.mono(11)).kerning(1.4).textCase(.uppercase)
                .foregroundStyle(Theme.Palette.fg3)
            Spacer()
            Text(v).font(Theme.Font.body(15, weight: .medium))
                .foregroundStyle(Theme.Palette.ink)
        }
    }
}
