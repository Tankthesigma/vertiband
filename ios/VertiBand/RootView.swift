import SwiftUI

struct RootView: View {
    @Binding var seenOnboarding: Bool
    @State private var selectedTab: Tab = .home
    @State private var path = NavigationPath()

    enum Tab: Hashable { case home, history, settings }

    var body: some View {
        Group {
            if !seenOnboarding {
                OnboardingView(done: { withAnimation(Theme.Motion.easeBase) { seenOnboarding = true } })
            } else {
                MainTabs(selectedTab: $selectedTab)
            }
        }
        .background(Theme.Palette.paper.ignoresSafeArea())
    }
}

private struct MainTabs: View {
    @Binding var selectedTab: RootView.Tab

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house") }
                .tag(RootView.Tab.home)
            NavigationStack { HistoryView() }
                .tabItem { Label("History", systemImage: "list.bullet.rectangle") }
                .tag(RootView.Tab.history)
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(RootView.Tab.settings)
        }
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Theme.Palette.paper, for: .tabBar)
    }
}
