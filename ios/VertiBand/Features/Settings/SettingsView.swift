import SwiftUI

struct SettingsView: View {
    @Environment(GeminiService.self) private var gemini
    @Environment(PiBridge.self) private var pi
    @Environment(AudioService.self) private var audio
    @Environment(SessionStore.self) private var store

    @State private var keyInput: String = ""
    @State private var piURLInput: String = ""
    @State private var savedToast: Bool = false
    @State private var confirmClear = false

    private let langs: [(String, String)] = [
        ("en", "English"), ("es", "Spanish"), ("zh", "Mandarin"), ("hi", "Hindi"),
        ("fr", "French"), ("ar", "Arabic"), ("bn", "Bengali"), ("pt", "Portuguese"),
        ("ru", "Russian"), ("ja", "Japanese")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.s5) {
                SectionHeader(eyebrow: "Settings", title: "Your", italicTail: "preferences.")
                voiceCard
                geminiCard
                piCard
                dataCard
                aboutCard
            }
            .padding(.horizontal, Theme.Space.s6)
            .padding(.top, Theme.Space.s4)
            .padding(.bottom, Theme.Space.s16)
        }
        .background(Theme.Palette.paper.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            keyInput = gemini.apiKey ?? ""
            piURLInput = pi.baseURL
        }
        .overlay(alignment: .bottom) {
            if savedToast {
                Text("Saved")
                    .font(Theme.Font.mono(11)).kerning(1.4).textCase(.uppercase)
                    .foregroundStyle(Theme.Palette.paper)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Theme.Palette.ink)
                    .clipShape(Capsule())
                    .padding(.bottom, Theme.Space.s16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Cards

    private var voiceCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: Theme.Space.s3) {
                Text("Voice").eyebrow()
                HStack {
                    Text("Language").font(Theme.Font.body(14, weight: .semibold))
                        .foregroundStyle(Theme.Palette.ink)
                    Spacer()
                    Picker("", selection: Binding(get: { audio.language },
                                                  set: { audio.language = $0 })) {
                        ForEach(langs, id: \.0) { Text($0.1).tag($0.0) }
                    }.pickerStyle(.menu).tint(Theme.Palette.signal)
                }
                Divider().overlay(Theme.Palette.line)
                HStack {
                    Text("Gender").font(Theme.Font.body(14, weight: .semibold))
                        .foregroundStyle(Theme.Palette.ink)
                    Spacer()
                    Picker("", selection: Binding(get: { audio.gender },
                                                  set: { audio.gender = $0 })) {
                        Text("Male").tag(AudioService.Gender.male)
                        Text("Female").tag(AudioService.Gender.female)
                    }.pickerStyle(.segmented).frame(width: 160)
                }
                Divider().overlay(Theme.Palette.line)
                PillButton(title: "Preview voice", kind: .ghost, icon: "speaker.wave.2") {
                    audio.speak("Vertiband is ready. Let's begin your session.")
                }
            }
        }
    }

    private var geminiCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: Theme.Space.s3) {
                Text("Gemini API key").eyebrow()
                Text("Unlocks live coaching and post-session notes. Free key at aistudio.google.com/app/apikey. Stored in the iOS keychain.")
                    .font(Theme.Font.body(13)).foregroundStyle(Theme.Palette.fg3)
                SecureField("paste key", text: $keyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Theme.Palette.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .font(Theme.Font.mono(13))
                HStack {
                    if gemini.hasKey {
                        StatusPill(tone: .success, label: "Key saved")
                    } else {
                        StatusPill(tone: .neutral, label: "Not configured")
                    }
                    Spacer()
                    Button("Save") {
                        gemini.apiKey = keyInput
                        toast()
                    }
                    .font(Theme.Font.body(13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.signal)
                }
            }
        }
    }

    private var piCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: Theme.Space.s3) {
                Text("VertiBand hardware").eyebrow()
                Text("Optional. If the physical band is running on your Wi-Fi, put its URL here and voice cues will play through the band's speaker.")
                    .font(Theme.Font.body(13)).foregroundStyle(Theme.Palette.fg3)
                TextField("http://192.168.254.53", text: $piURLInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding(12)
                    .background(Theme.Palette.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .font(Theme.Font.mono(13))
                HStack {
                    StatusPill(tone: pi.isReachable ? .success : .neutral,
                               label: pi.isReachable ? "Reachable" : "Offline")
                    Spacer()
                    Button("Test") {
                        pi.baseURL = piURLInput
                        Task { await pi.probe() }
                    }
                    .font(Theme.Font.body(13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.signal)
                    Button("Save") {
                        pi.baseURL = piURLInput
                        Task { await pi.probe() }
                        toast()
                    }
                    .font(Theme.Font.body(13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.signal)
                }
            }
        }
    }

    private var dataCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: Theme.Space.s3) {
                Text("Data").eyebrow()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Saved sessions").font(Theme.Font.body(14, weight: .semibold))
                            .foregroundStyle(Theme.Palette.ink)
                        Text("\(store.records.count) on this device")
                            .font(Theme.Font.body(13)).foregroundStyle(Theme.Palette.fg3)
                    }
                    Spacer()
                    Button("Clear all", role: .destructive) { confirmClear = true }
                        .font(Theme.Font.body(13, weight: .semibold))
                }
            }
        }
        .confirmationDialog("Erase all sessions?", isPresented: $confirmClear) {
            Button("Erase all", role: .destructive) { store.clearAll(); toast() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var aboutCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: Theme.Space.s3) {
                Text("About").eyebrow()
                HStack { Text("Version"); Spacer(); Text("0.1.0 · V-01") }
                HStack { Text("Built in"); Spacer(); Text("Texas") }
                HStack {
                    Text("Website")
                    Spacer()
                    Link("vertiband.us", destination: URL(string: "https://vertiband.us")!)
                        .foregroundStyle(Theme.Palette.signal)
                }
            }
            .font(Theme.Font.body(14))
            .foregroundStyle(Theme.Palette.fg2)
        }
    }

    private func toast() {
        withAnimation(Theme.Motion.easeFast) { savedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(Theme.Motion.easeFast) { savedToast = false }
        }
    }
}
