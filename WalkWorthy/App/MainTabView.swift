import SwiftUI

struct MainTabView: View {
    @Binding var selectedTab: RootTab

    let profile: OnboardingProfile
    let isPremium: Bool
    let onRequirePaywall: (PaywallTriggerReason) -> Void

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(profile: profile)
                .tabItem {
                    Label("Today", systemImage: "sun.max")
                }
                .tag(RootTab.today)

            JourneysView(isPremium: isPremium, onRequirePaywall: onRequirePaywall)
                .tabItem {
                    Label("Journeys", systemImage: "list.bullet.rectangle")
                }
                .tag(RootTab.journeys)

            TimelineView(isPremium: isPremium, onRequirePaywall: onRequirePaywall)
                .tabItem {
                    Label("Timeline", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                }
                .tag(RootTab.timeline)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(RootTab.settings)
        }
        .tint(WWColor.sapphire)
    }
}
