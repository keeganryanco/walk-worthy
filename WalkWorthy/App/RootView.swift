import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @EnvironmentObject private var notificationService: NotificationService

    @Query(sort: \OnboardingProfile.createdAt) private var profiles: [OnboardingProfile]
    @Query(sort: \AppSettings.lastSessionDate, order: .reverse) private var settingsRows: [AppSettings]
    @Query(filter: #Predicate<PrayerJourney> { !$0.isArchived }, sort: \PrayerJourney.createdAt, order: .reverse)
    private var activeJourneys: [PrayerJourney]

    @State private var selectedTab: RootTab = .today
    @State private var showPaywall = false

    private let cardGenerator = TemplateTodayCardGenerator()

    private var profile: OnboardingProfile? {
        profiles.first
    }

    private var settings: AppSettings? {
        settingsRows.first
    }

    var body: some View {
        ZStack {
            WWColor.white.ignoresSafeArea()

            if let profile {
                MainTabView(
                    selectedTab: $selectedTab,
                    profile: profile,
                    isPremium: subscriptionService.isPremium,
                    onRequirePaywall: triggerPaywall
                )
            } else {
                OnboardingFlowView { completedProfile in
                    seedInitialExperience(with: completedProfile)
                }
                .padding(.horizontal, 20)
            }
        }
        .task {
            await subscriptionService.initialize()
            await notificationService.refreshAuthorizationStatus()
            bootstrapSettingsIfNeeded()
            registerSessionIfNeeded()
            showPaywall = MonetizationPolicy.requiresPaywall(hasPremium: subscriptionService.isPremium, settings: settings)
        }
        .onChange(of: subscriptionService.isPremium) { _, isPremium in
            if isPremium {
                settings?.pendingPaywallReason = nil
                showPaywall = false
            } else {
                showPaywall = MonetizationPolicy.requiresPaywall(hasPremium: false, settings: settings)
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(
                triggerReason: settings?.pendingPaywallReason,
                isPremium: subscriptionService.isPremium
            )
            .environmentObject(subscriptionService)
        }
    }

    private func bootstrapSettingsIfNeeded() {
        guard settings == nil else { return }
        let row = AppSettings()
        modelContext.insert(row)
        try? modelContext.save()
    }

    private func registerSessionIfNeeded() {
        guard let settings else { return }
        let calendar = Calendar.current
        let today = Date.now

        if let lastSessionDate = settings.lastSessionDate, calendar.isDate(lastSessionDate, inSameDayAs: today) {
            return
        }

        settings.lastSessionDate = today
        settings.totalSessions += 1

        if settings.totalSessions >= MonetizationPolicy.sessionPaywallThreshold {
            settings.pendingPaywallReason = PaywallTriggerReason.sessionCount.rawValue
        }

        try? modelContext.save()
    }

    private func triggerPaywall(_ reason: PaywallTriggerReason) {
        settings?.pendingPaywallReason = reason.rawValue
        try? modelContext.save()
        showPaywall = true
    }

    private func seedInitialExperience(with completedProfile: OnboardingProfile) {
        modelContext.insert(completedProfile)

        let firstJourney = PrayerJourney(title: "First Journey", category: completedProfile.prayerFocus)
        modelContext.insert(firstJourney)

        let card = cardGenerator.generateTodayCard(profile: completedProfile, journeys: [firstJourney], date: .now)
        let entry = PrayerEntry(
            prompt: card.prayerPrompt,
            scriptureReference: card.scriptureReference,
            scriptureText: card.scriptureText,
            actionStep: card.actionStep,
            journey: firstJourney
        )
        modelContext.insert(entry)

        if settings == nil {
            modelContext.insert(AppSettings())
        }

        try? modelContext.save()

        Task {
            let granted = await notificationService.requestAuthorization()
            guard granted else { return }
            await notificationService.scheduleDailyReminder(hour: 8, minute: 0)
        }
    }
}

enum RootTab: Hashable {
    case today
    case journeys
    case timeline
    case settings
}
