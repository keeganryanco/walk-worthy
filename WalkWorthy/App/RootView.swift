import SwiftUI
import SwiftData
import os

private let rootLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "co.keeganryan.tend", category: "RootView")

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var connectivityService: ConnectivityService

    @Query(sort: \OnboardingProfile.createdAt) private var profiles: [OnboardingProfile]
    @Query(sort: \AppSettings.lastSessionDate, order: .reverse) private var settingsRows: [AppSettings]
    @Query(sort: \PrayerJourney.createdAt, order: .reverse) private var allJourneys: [PrayerJourney]
    @Query(filter: #Predicate<PrayerJourney> { !$0.isArchived }, sort: \PrayerJourney.createdAt, order: .reverse)
    private var activeJourneys: [PrayerJourney]
    @Query(sort: \PrayerEntry.createdAt, order: .reverse) private var allEntries: [PrayerEntry]
    @Query(sort: \JourneyMemorySnapshot.updatedAt, order: .reverse) private var memorySnapshots: [JourneyMemorySnapshot]

    @State private var selectedTab: RootTab = .home
    @State private var showPaywall = false
    @State private var trackedOnboardingStart = false
    @State private var onboardingErrorMessage: String?
    @State private var isBootstrappingJourney = false

    private let journeyContentService = JourneyContentService()
    private let bootstrapProvider = BackendJourneyBootstrapProvider()
    private let analytics: AnalyticsTracking = AnalyticsServiceFactory.makeDefault()

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
                ExperimentalOnboardingFlowView { completedProfile in
                    Task { await seedInitialExperience(with: completedProfile) }
                }
            }
        }
        .task {
            await subscriptionService.initialize()
            await notificationService.refreshAuthorizationStatus()
            bootstrapSettingsIfNeeded()
            registerSessionIfNeeded()
            showPaywall = MonetizationPolicy.requiresPaywall(hasPremium: subscriptionService.isPremium, settings: settings)
            await bootstrapFirstJourneyIfNeeded()
            await prefetchDailyPackagesIfPossible()
            syncWidgetSnapshot()
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
            Task {
                await bootstrapFirstJourneyIfNeeded()
                await prefetchDailyPackagesIfPossible()
                syncWidgetSnapshot()
            }
        }
        .onChange(of: activeJourneys.count) { _, _ in
            syncWidgetSnapshot()
            Task { await prefetchDailyPackagesIfPossible() }
        }
        .onOpenURL(perform: handleDeepLink)
        .onAppear {
            trackOnboardingStartedIfNeeded()
        }
        .onChange(of: showPaywall) { _, isShown in
            guard isShown else { return }
            analytics.track(
                .paywallShown,
                properties: [
                    "trigger_reason": settings?.pendingPaywallReason ?? "unspecified",
                    "has_premium": subscriptionService.isPremium ? "true" : "false"
                ]
            )
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(
                triggerReason: settings?.pendingPaywallReason,
                isPremium: subscriptionService.isPremium
            )
            .environmentObject(subscriptionService)
        }
        .alert(
            "Unable to Create Journey",
            isPresented: Binding(
                get: { onboardingErrorMessage != nil },
                set: { if !$0 { onboardingErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(onboardingErrorMessage ?? "")
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

    private func seedInitialExperience(with completedProfile: OnboardingProfile) async {
        modelContext.insert(completedProfile)
        try? modelContext.save()

        await bootstrapFirstJourneyIfNeeded()

        if settings == nil {
            modelContext.insert(AppSettings())
        }

        try? modelContext.save()
        analytics.track(.onboardingCompleted, properties: [:])

        Task {
            let granted = await notificationService.requestAuthorization()
            guard granted else { return }
            let reminder = hourForReminderWindow(completedProfile.reminderWindow)
            await notificationService.scheduleDailyReminder(hour: reminder, minute: 0)
        }
    }

    private func trackOnboardingStartedIfNeeded() {
        guard profile == nil, !trackedOnboardingStart else { return }
        trackedOnboardingStart = true
        analytics.track(.onboardingStarted, properties: [:])
    }

    private func prefetchDailyPackagesIfPossible() async {
        guard connectivityService.isOnline, let profile else { return }
        guard !activeJourneys.isEmpty else {
            syncWidgetSnapshot()
            return
        }

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
        syncWidgetSnapshot()
    }

    private func bootstrapFirstJourneyIfNeeded() async {
        guard connectivityService.isOnline else {
            rootLogger.log("bootstrap skipped: offline")
            return
        }
        guard !isBootstrappingJourney else {
            rootLogger.log("bootstrap skipped: already running")
            return
        }
        guard allJourneys.isEmpty else {
            rootLogger.log("bootstrap skipped: journey already exists count=\(allJourneys.count)")
            return
        }
        guard let profile else {
            rootLogger.log("bootstrap skipped: onboarding profile missing")
            return
        }

        isBootstrappingJourney = true
        defer { isBootstrappingJourney = false }
        rootLogger.log("bootstrap started")

        do {
            let payload = try await bootstrapProvider.bootstrap(
                name: profile.name,
                prayerIntentText: profile.prayerFocus,
                goalIntentText: profile.growthGoal,
                reminderWindow: profile.reminderWindow
            )

            let theme = JourneyThemeKey(rawValue: payload.themeKey.lowercased()) ?? .basic
            let firstJourney = PrayerJourney(
                title: payload.journeyTitle,
                category: payload.journeyCategory,
                themeKey: theme,
                status: .active
            )
            modelContext.insert(firstJourney)

            let entry = PrayerEntry(
                prompt: payload.initialPackage.prayer,
                scriptureReference: payload.initialPackage.scriptureReference,
                scriptureText: payload.initialPackage.scriptureParaphrase,
                actionStep: "",
                journey: firstJourney
            )
            modelContext.insert(entry)

            let dayKey = JourneyContentService.dayKey(for: .now)
            let record = DailyJourneyPackageRecord(
                journeyID: firstJourney.id,
                dayKey: dayKey,
                reflectionThought: payload.initialPackage.reflectionThought,
                scriptureReference: payload.initialPackage.scriptureReference,
                scriptureParaphrase: payload.initialPackage.scriptureParaphrase,
                prayer: payload.initialPackage.prayer,
                smallStepQuestion: payload.initialPackage.smallStepQuestion,
                suggestedSteps: payload.initialPackage.suggestedSteps,
                completionSuggestion: payload.initialPackage.completionSuggestion,
                generatedAt: payload.initialPackage.generatedAt,
                source: .remote,
                linkedEntryID: entry.id
            )
            modelContext.insert(record)

            let snapshot = JourneyMemorySnapshot(
                journeyID: firstJourney.id,
                summary: payload.initialMemory.summary,
                winsSummary: payload.initialMemory.winsSummary,
                blockersSummary: payload.initialMemory.blockersSummary,
                preferredTone: payload.initialMemory.preferredTone
            )
            modelContext.insert(snapshot)

            JourneyProgressService.logEvent(
                journeyID: firstJourney.id,
                type: .packageGenerated,
                notes: "Initial onboarding package seeded from bootstrap endpoint.",
                modelContext: modelContext
            )

            try? modelContext.save()
            syncWidgetSnapshot()
            rootLogger.log("bootstrap succeeded journeyTitle=\(payload.journeyTitle, privacy: .public) theme=\(payload.themeKey, privacy: .public)")
            analytics.track(.journeyCreated, properties: ["source": "bootstrap"])
        } catch {
            let details = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            rootLogger.error("bootstrap failed error=\(details, privacy: .public)")
            onboardingErrorMessage = details.isEmpty
                ? "We couldn't create your first journey right now. Connect to the internet and try again."
                : "We couldn't create your first journey: \(details)"
        }
    }

    private func hourForReminderWindow(_ value: String) -> Int {
        switch value.lowercased() {
        case "morning":
            return 8
        case "afternoon":
            return 13
        case "evening":
            return 19
        default:
            return 8
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == AppConstants.DeepLink.scheme else { return }

        let host = url.host?.lowercased()
        let normalizedPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        if host == AppConstants.DeepLink.homeHost || normalizedPath == AppConstants.DeepLink.homeHost {
            selectedTab = .home
        }
    }

    private func syncWidgetSnapshot() {
        guard !activeJourneys.isEmpty else {
            WidgetSyncService.clearWidgetSnapshot()
            return
        }
        WidgetSyncService.publishFromModelContext(modelContext)
    }
}

enum RootTab: Hashable {
    case home
    case journal
    case settings
}
