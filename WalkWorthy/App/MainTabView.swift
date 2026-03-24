import SwiftUI

struct MainTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedTab: RootTab

    let profile: OnboardingProfile
    let isPremium: Bool
    let onRequirePaywall: (PaywallTriggerReason) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView(
                    profile: profile,
                    isPremium: isPremium,
                    onRequirePaywall: onRequirePaywall,
                    onNavigateToJournal: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedTab = .journal
                        }
                    },
                    onNavigateToSettings: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedTab = .settings
                        }
                    }
                )
                    .tag(RootTab.home)
                    .toolbar(.hidden, for: .tabBar)
                
                JournalView(isPremium: isPremium, onRequirePaywall: onRequirePaywall)
                    .tag(RootTab.journal)
                    .toolbar(.hidden, for: .tabBar)
                
                SettingsView()
                    .tag(RootTab.settings)
                    .toolbar(.hidden, for: .tabBar)
            }
            
            // Custom Tab Bar
            HStack(spacing: 0) {
                tabButton(title: "Home", systemImage: "leaf.fill", tab: .home)
                tabButton(title: "Journal", systemImage: "book.fill", tab: .journal)
                tabButton(title: "Settings", systemImage: "gearshape.fill", tab: .settings)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(WWColor.darkBackground.opacity(0.95))
                    .shadow(color: .black.opacity(0.4), radius: 30, y: 15)
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 48)
            .padding(.bottom, 24)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .simultaneousGesture(horizontalTabSwipeGesture, including: .all)
    }
    
    private func tabButton(title: String, systemImage: String, tab: RootTab) -> some View {
        let isSelected = selectedTab == tab
        let inactiveColor: Color = colorScheme == .dark ? .white : WWColor.nearBlack
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: isSelected ? .bold : .medium))
                
                Text(title)
                    .font(WWTypography.caption(10).weight(isSelected ? .bold : .medium))
            }
            .foregroundStyle(isSelected ? WWColor.growGreen : inactiveColor.opacity(0.92))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var horizontalTabSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 22)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical) + 16 else { return }

                // Home handles horizontal journey+tab progression internally.
                guard selectedTab != .home else { return }

                if horizontal < -56 {
                    switch selectedTab {
                    case .journal:
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedTab = .settings
                        }
                    case .settings, .home:
                        break
                    }
                } else if horizontal > 56 {
                    switch selectedTab {
                    case .settings:
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedTab = .journal
                        }
                    case .journal:
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedTab = .home
                        }
                    case .home:
                        break
                    }
                }
            }
    }
}
