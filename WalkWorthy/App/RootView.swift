import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var connectivityService: ConnectivityService

    @Query(sort: \OnboardingProfile.createdAt) private var profiles: [OnboardingProfile]
    @Query(sort: \AppSettings.lastSessionDate, order: .reverse) private var settingsRows: [AppSettings]
    @Query(filter: #Predicate<PrayerJourney> { !$0.isArchived }, sort: \PrayerJourney.createdAt, order: .reverse)
    private var activeJourneys: [PrayerJourney]
    @Query(sort: \PrayerEntry.createdAt, order: .reverse) private var allEntries: [PrayerEntry]
    @Query(sort: \JourneyMemorySnapshot.updatedAt, order: .reverse) private var memorySnapshots: [JourneyMemorySnapshot]

    @State private var selectedTab: RootTab = .today
    @State private var showPaywall = false

    private let cardGenerator = TemplateTodayCardGenerator()
    private let journeyContentService = JourneyContentService()

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
            }
        }
        .task {
            await subscriptionService.initialize()
            await notificationService.refreshAuthorizationStatus()
            bootstrapSettingsIfNeeded()
            registerSessionIfNeeded()
            showPaywall = MonetizationPolicy.requiresPaywall(hasPremium: subscriptionService.isPremium, settings: settings)
            await prefetchDailyPackagesIfPossible()
        }
        .onChange(of: subscriptionService.isPremium) { _, isPremium in
            if isPremium {
                settings?.pendingPaywallReason = nil
                showPaywall = false
            } else {
                showPaywall = MonetizationPolicy.requiresPaywall(hasPremium: false, settings: settings)
            }
        }
        .onChange(of: connectivityService.isOnline) { _, isOnline in
            guard isOnline else { return }
            Task { await prefetchDailyPackagesIfPossible() }
        }
        .onChange(of: activeJourneys.count) { _, _ in
            Task { await prefetchDailyPackagesIfPossible() }
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
        JourneyProgressService.logEvent(
            journeyID: firstJourney.id,
            type: .packageGenerated,
            notes: "Initial onboarding package seeded.",
            modelContext: modelContext
        )
        JourneyMemoryService.refreshSnapshot(
            for: firstJourney,
            entries: [entry],
            profile: completedProfile,
            modelContext: modelContext
        )

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

    private func prefetchDailyPackagesIfPossible() async {
        guard connectivityService.isOnline, let profile else { return }
        guard !activeJourneys.isEmpty else { return }

        var entriesByJourneyID: [UUID: [PrayerEntry]] = [:]
        for entry in allEntries {
            guard let journeyID = entry.journey?.id else { continue }
            entriesByJourneyID[journeyID, default: []].append(entry)
        }

        let memoryByJourneyID = Dictionary(uniqueKeysWithValues: memorySnapshots.map { ($0.journeyID, $0) })

        await journeyContentService.prefetchForTodayAndTomorrow(
            profile: profile,
            journeys: activeJourneys,
            entriesByJourneyID: entriesByJourneyID,
            memoryByJourneyID: memoryByJourneyID,
            isOnline: true,
            modelContext: modelContext
        )
    }
}

enum RootTab: Hashable {
    case today
    case journeys
    case timeline
    case settings
}
