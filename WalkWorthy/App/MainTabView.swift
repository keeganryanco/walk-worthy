import SwiftUI

struct MainTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("homeOverlayActive") private var homeOverlayActive = false
    @Binding var selectedTab: RootTab
    @State private var suppressHorizontalTabSwipe = false

    let profile: OnboardingProfile
    let isPremium: Bool
    let onRequirePaywall: (PaywallTriggerReason) -> Void
    let onRequestDailyWarmup: (UUID) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView(
                    profile: profile,
                    isPremium: isPremium,
                    onRequirePaywall: onRequirePaywall,
                    onRequestDailyWarmup: onRequestDailyWarmup
                )
                    .tag(RootTab.home)
                    .toolbar(.hidden, for: .tabBar)
                
                JournalView(
                    isPremium: isPremium,
                    onRequirePaywall: onRequirePaywall,
                    suppressHorizontalTabSwipe: $suppressHorizontalTabSwipe
                )
                    .tag(RootTab.journal)
                    .toolbar(.hidden, for: .tabBar)
                
                SettingsView()
                    .tag(RootTab.settings)
                    .toolbar(.hidden, for: .tabBar)
            }
            
            // Custom Tab Bar
            if !(selectedTab == .home && homeOverlayActive) {
                HStack(spacing: 0) {
                    tabButton(
                        title: L10n.string("tab.home", default: "Home"),
                        accessibilityHint: L10n.string("tab.home.hint", default: "Switches to the home tab."),
                        systemImage: "leaf.fill",
                        tab: .home
                    )
                    tabButton(
                        title: L10n.string("tab.journal", default: "Journal"),
                        accessibilityHint: L10n.string("tab.journal.hint", default: "Switches to the journal tab."),
                        systemImage: "book.fill",
                        tab: .journal
                    )
                    tabButton(
                        title: L10n.string("tab.settings", default: "Settings"),
                        accessibilityHint: L10n.string("tab.settings.hint", default: "Switches to the settings tab."),
                        systemImage: "gearshape.fill",
                        tab: .settings
                    )
                }
                .accessibilityElement(children: .contain)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(WWColor.tabBarBackground.opacity(colorScheme == .dark ? 0.95 : 0.98))
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.14), radius: 30, y: 15)
                )
                .overlay(
                    Capsule().stroke(
                        WWColor.nearBlack.opacity(colorScheme == .dark ? 0.12 : 0.1),
                        lineWidth: 1
                    )
                )
                .padding(.horizontal, 48)
                .padding(.bottom, 24)
                .transition(.opacity)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .simultaneousGesture(horizontalTabSwipeGesture, including: .all)
    }
    
    private func tabButton(title: String, accessibilityHint: String, systemImage: String, tab: RootTab) -> some View {
        let isSelected = selectedTab == tab
        let inactiveColor: Color = colorScheme == .dark ? .white : WWColor.nearBlack
        return Button {
            selectTab(tab)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: isSelected ? .bold : .medium))
                
                Text(title)
                    .font(WWTypography.caption(10).weight(isSelected ? .bold : .medium))
            }
            .foregroundStyle(isSelected ? WWColor.growGreen : inactiveColor.opacity(0.92))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? L10n.string("tab.selected", default: "Selected") : "")
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var horizontalTabSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 22)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical) + 16 else { return }

                // Home handles horizontal journey+tab progression internally.
                guard selectedTab != .home else { return }
                guard !suppressHorizontalTabSwipe else { return }

                if horizontal < -56 {
                    switch selectedTab {
                    case .journal:
                        selectTab(.settings)
                    case .settings, .home:
                        break
                    }
                } else if horizontal > 56 {
                    switch selectedTab {
                    case .settings:
                        selectTab(.journal)
                    case .journal:
                        selectTab(.home)
                    case .home:
                        break
                    }
                }
            }
    }

    private func selectTab(_ tab: RootTab) {
        if reduceMotion {
            selectedTab = tab
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedTab = tab
            }
        }
    }
}
