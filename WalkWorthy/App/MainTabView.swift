import SwiftUI

struct MainTabView: View {
    @Binding var selectedTab: RootTab

    let profile: OnboardingProfile
    let isPremium: Bool
    let onRequirePaywall: (PaywallTriggerReason) -> Void

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(profile: profile)
                .tabItem {
                    Label("Home", systemImage: "leaf")
                }
                .tag(RootTab.home)

            JournalView(isPremium: isPremium, onRequirePaywall: onRequirePaywall)
                .tabItem {
                    Label("Journal", systemImage: "book")
                }
                .tag(RootTab.journal)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(RootTab.settings)
        }
        .tint(WWColor.growGreen)
    }
}
