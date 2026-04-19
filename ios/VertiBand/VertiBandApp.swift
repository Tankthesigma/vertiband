import SwiftUI

@main
struct VertiBandApp: App {
    @State private var motion = MotionService()
    @State private var audio = AudioService()
    @State private var gemini = GeminiService()
    @State private var pi = PiBridge()
    @State private var store = SessionStore()
    @AppStorage("us.vertiband.app.seenOnboarding") private var seenOnboarding = false

    var body: some Scene {
        WindowGroup {
            RootView(seenOnboarding: $seenOnboarding)
                .environment(motion)
                .environment(audio)
                .environment(gemini)
                .environment(pi)
                .environment(store)
                .tint(Theme.Palette.signal)
                .preferredColorScheme(.light)
        }
    }
}
