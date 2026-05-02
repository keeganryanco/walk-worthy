import SwiftUI
import SwiftData
import os

private let rootLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "co.keeganryan.tend", category: "RootView")

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var connectivityService: ConnectivityService

    @Query(sort: \OnboardingProfile.createdAt) private var profiles: [OnboardingProfile]
    @Query(sort: \AppSettings.lastSessionDate, order: .reverse) private var settingsRows: [AppSettings]
    @Query(sort: \ReminderSchedule.sortOrder) private var reminderSchedules: [ReminderSchedule]
    @Query(sort: \PrayerJourney.createdAt, order: .reverse) private var allJourneys: [PrayerJourney]
    @Query(filter: #Predicate<PrayerJourney> { !$0.isArchived }, sort: \PrayerJourney.createdAt, order: .reverse)
    private var activeJourneys: [PrayerJourney]
    @Query(sort: \PrayerEntry.createdAt, order: .reverse) private var allEntries: [PrayerEntry]
    @Query(sort: \JourneyMemorySnapshot.updatedAt, order: .reverse) private var memorySnapshots: [JourneyMemorySnapshot]
    @Query(sort: \DailyJourneyPackageRecord.generatedAt, order: .reverse) private var packageRecords: [DailyJourneyPackageRecord]

    @State private var selectedTab: RootTab = .home
    @State private var showPaywall = false
    @State private var showDownsellPaywall = false
    @State private var hasShownDownsellThisForegroundSession = false
    @State private var trackedOnboardingStart = false
    @State private var onboardingErrorMessage: String?
    @State private var isBootstrappingJourney = false
    @State private var onboardingExperimentConfig: OnboardingExperimentConfig = .default
    @AppStorage(AppConstants.DeepLink.pendingJourneyStorageKey) private var pendingJourneyIDRaw = ""
    @AppStorage(AppConstants.DeepLink.pendingActionStorageKey) private var pendingHomeActionRaw = ""

    private let journeyContentService = JourneyContentService()
    private let bootstrapProvider = BackendJourneyBootstrapProvider()
    private let analytics: AnalyticsTracking = AnalyticsServiceFactory.makeDefault()
    private let onboardingExperimentProvider: OnboardingExperimentConfigProviding = OnboardingExperimentServiceFactory.makeDefault()
    @State private var packageWarmupService = JourneyPackageWarmupService()

    private var profile: OnboardingProfile? {
        profiles.first
    }

    private var settings: AppSettings? {
        settingsRows.first
    }

    var body: some View {
        presentationLayer
    }

    private var lifecycleLayer: some View {
        AnyView(rootContent)
            .task {
                await handleInitialTask()
            }
            .onChange(of: subscriptionService.isPremium) { _, isPremium in
                handlePremiumStatusChanged(isPremium)
            }
            .onChange(of: subscriptionService.hasEligibleDownsellOffer) { _, _ in
                maybePresentDownsellOffer()
            }
            .onChange(of: subscriptionService.paywallMode) { _, _ in
                syncPaywallPresentationState()
            }
            .onChange(of: connectivityService.isOnline) { _, isOnline in
                handleConnectivityChanged(isOnline)
            }
            .onChange(of: activeJourneys.count) { _, _ in
                syncWidgetSnapshot()
                Task { await prefetchDailyPackagesIfPossible() }
            }
            .onChange(of: allEntries.count) { _, _ in
                Task { await prefetchDailyPackagesIfPossible() }
            }
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChanged(newPhase)
            }
            .onOpenURL(perform: handleDeepLink)
            .onChange(of: notificationService.pendingDeepLinkURL) { _, value in
                guard let value else { return }
                handleDeepLink(value)
                notificationService.consumePendingDeepLink()
            }
            .onAppear {
                trackOnboardingStartedIfNeeded()
            }
            .onChange(of: showPaywall) { _, isShown in
                handlePaywallShownChanged(isShown)
            }
    }

    private var presentationLayer: some View {
        AnyView(lifecycleLayer)
            .fullScreenCover(isPresented: $showPaywall, onDismiss: {
                handlePaywallDismissed()
            }) {
                paywallCoverContent()
            }
            .fullScreenCover(isPresented: $showDownsellPaywall, onDismiss: {
                trackDownsellDismissedIfNeeded()
            }) {
                downsellPaywallCoverContent()
            }
            .alert(
                L10n.string("journey.error.create_title", default: "Unable to Create Journey"),
                isPresented: Binding(
                    get: { onboardingErrorMessage != nil },
                    set: { if !$0 { onboardingErrorMessage = nil } }
                )
            ) {
                Button(L10n.string("common.ok", default: "OK"), role: .cancel) {}
            } message: {
                Text(onboardingErrorMessage ?? "")
            }
    }

    @ViewBuilder
    private var rootContent: some View {
        ZStack {
            WWColor.white.ignoresSafeArea()

            if let profile {
                mainTabs(profile: profile)
            } else {
                onboardingFlow
            }
        }
    }

    private func mainTabs(profile: OnboardingProfile) -> some View {
        MainTabView(
            selectedTab: $selectedTab,
            profile: profile,
            isPremium: subscriptionService.isPremium,
            onRequirePaywall: triggerPaywall,
            onRequestDailyWarmup: { journeyID in
                await warmJourneyIfPossible(journeyID: journeyID)
            }
        )
    }

    private var onboardingFlow: some View {
        ExperimentalOnboardingFlowView(
            onPrepare: { name, prayer in
                await prepareJourneyInline(name: name, prayer: prayer, reminderWindow: "System")
            },
            onGenerate: { name, prayer in
                if let prepared = await prepareJourneyInline(name: name, prayer: prayer, reminderWindow: "System") {
                    return await commitPreparedJourney(prepared, name: name, prayer: prayer)
                }
                return nil
            },
            onCommitPrepared: { prepared, name, prayer in
                await commitPreparedJourney(prepared, name: name, prayer: prayer)
            },
            isPremium: subscriptionService.isPremium,
            onComplete: { completedProfile in
                Task { await completeOnboarding(with: completedProfile) }
            },
            onRequirePaywall: triggerPaywall,
            experimentConfig: onboardingExperimentConfig
        )
    }

    private func handleInitialTask() async {
        rootLogger.log(
            "debug flags resolved bypassPaywall=\(AppConstants.Debug.bypassPaywall, privacy: .public) fastDayTesting=\(AppConstants.Debug.fastDayTesting, privacy: .public)"
        )
        onboardingExperimentConfig = await onboardingExperimentProvider.fetchConfig()
        analytics.track(
            .onboardingExperimentAssigned,
            properties: [
                "variant": onboardingExperimentConfig.variant,
                "pre_count": String(onboardingExperimentConfig.preJourneyOrder.count),
                "post_count": String(onboardingExperimentConfig.postJourneyOrder.count),
                "pre_steps": onboardingExperimentConfig.preJourneyOrder.joined(separator: ","),
                "post_steps": onboardingExperimentConfig.postJourneyOrder.joined(separator: ",")
            ]
        )
        await subscriptionService.initialize()
        await notificationService.refreshAuthorizationStatus()
        notificationService.recordAppOpen(modelContext: modelContext)
        bootstrapSettingsIfNeeded()
        registerSessionIfNeeded()
        syncPaywallPresentationState()
        await bootstrapFirstJourneyIfNeeded()
        await prefetchDailyPackagesIfPossible()
        maybePresentDownsellOffer()
        DailyPackageBackgroundRefreshService.schedule(earliestBeginDate: nextLikelyRefreshDate())
        syncWidgetSnapshot()
        if notificationService.authorizationStatus == .authorized {
            let reminders = fetchReminderSchedules()
            await notificationService.scheduleReminderSchedules(
                reminders.filter(\.isEnabled),
                modelContext: modelContext
            )
        }
    }

    private func handlePremiumStatusChanged(_ isPremium: Bool) {
        if isPremium {
            settings?.pendingPaywallReason = nil
            settings?.clearPaywallDismissed()
            try? modelContext.save()
            showPaywall = false
            showDownsellPaywall = false
        } else {
            syncPaywallPresentationState()
            maybePresentDownsellOffer()
        }
    }

    private func handleConnectivityChanged(_ isOnline: Bool) {
        guard isOnline else { return }
        Task {
            await bootstrapFirstJourneyIfNeeded()
            await prefetchDailyPackagesIfPossible()
            syncWidgetSnapshot()
        }
    }

    private func handleScenePhaseChanged(_ newPhase: ScenePhase) {
        if newPhase == .background {
            hasShownDownsellThisForegroundSession = false
            DailyPackageBackgroundRefreshService.schedule(earliestBeginDate: nextLikelyRefreshDate())
            return
        }
        guard newPhase == .active else { return }
        syncPaywallPresentationState()
        maybePresentDownsellOffer()
        Task {
            await notificationService.refreshAuthorizationStatus()
            notificationService.recordAppOpen(modelContext: modelContext)
            await prefetchDailyPackagesIfPossible()
            guard notificationService.authorizationStatus == .authorized else { return }
            await notificationService.scheduleReminderSchedules(
                fetchReminderSchedules().filter(\.isEnabled),
                modelContext: modelContext
            )
        }
    }

    private func handlePaywallShownChanged(_ isShown: Bool) {
        guard isShown else { return }
        let triggerReason = settings?.pendingPaywallReason ?? "unspecified"
        let personalizationContext = paywallPersonalizationContext(for: triggerReason)
        if subscriptionService.paywallMode == .firstTendReviewThenPaywall {
            FirstTendMilestoneService.markPaywallShownAfterFirstTend(settings: settings)
            try? modelContext.save()
        }
        analytics.track(
            .paywallShown,
            properties: [
                "trigger_reason": triggerReason,
                "paywall_variant": paywallVariant(for: triggerReason),
                "has_personalized_preview": personalizationContext.hasPreview ? "true" : "false",
                "default_package": paywallConfigForCurrentState().defaultPackageToken,
                "paywall_mode": subscriptionService.paywallMode.rawValue,
                "has_premium": subscriptionService.isPremium ? "true" : "false",
                "is_dismiss_offer": triggerReason == PaywallTriggerReason.paywallDismissOffer.rawValue ? "true" : "false"
            ]
        )
    }

    private func trackDownsellDismissedIfNeeded() {
        guard !subscriptionService.isPremium else { return }
        let personalizationContext = paywallPersonalizationContext(for: nil)
        analytics.track(
            .paywallDismissed,
            properties: [
                "paywall_variant": "downsell_personalized",
                "trigger_reason": "trial_cancel_downsell",
                "has_personalized_preview": personalizationContext.hasPreview ? "true" : "false"
            ]
        )
    }

    @ViewBuilder
    private func paywallCoverContent() -> some View {
        let config = paywallConfigForCurrentState()
        let triggerReason = settings?.pendingPaywallReason
        PaywallView(
            triggerReason: triggerReason,
            isPremium: subscriptionService.isPremium,
            copyOverride: config,
            personalizationContext: paywallPersonalizationContext(for: triggerReason)
        )
        .interactiveDismissDisabled(!config.isDismissable)
        .environmentObject(subscriptionService)
    }

    @ViewBuilder
    private func downsellPaywallCoverContent() -> some View {
        DownsellPaywallView(personalizationContext: paywallPersonalizationContext(for: nil))
            .environmentObject(subscriptionService)
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

        try? modelContext.save()
    }

    private func triggerPaywall(_ reason: PaywallTriggerReason) {
        guard !AppConstants.Debug.bypassPaywall else { return }
        // Paywall should only be presented during onboarding flow.
        guard profile == nil else { return }
        settings?.pendingPaywallReason = reason.rawValue
        try? modelContext.save()
        showPaywall = true
    }

    private func completeOnboarding(with completedProfile: OnboardingProfile) async {
        modelContext.insert(completedProfile)
        
        if settings == nil {
            modelContext.insert(AppSettings())
        }
        ensureDefaultReminderScheduleIfNeeded(from: completedProfile.reminderWindow)

        try? modelContext.save()
        analytics.track(
            .onboardingCompleted,
            properties: [
                "variant": onboardingExperimentConfig.variant,
                "pre_count": String(onboardingExperimentConfig.preJourneyOrder.count),
                "post_count": String(onboardingExperimentConfig.postJourneyOrder.count),
                "pre_steps": onboardingExperimentConfig.preJourneyOrder.joined(separator: ","),
                "post_steps": onboardingExperimentConfig.postJourneyOrder.joined(separator: ",")
            ]
        )

        Task {
            await notificationService.refreshAuthorizationStatus()
            guard notificationService.authorizationStatus == .authorized else { return }
            let reminders = fetchReminderSchedules()
            if reminders.isEmpty {
                let reminder = hourForReminderWindow(completedProfile.reminderWindow)
                await notificationService.scheduleDailyReminder(hour: reminder, minute: 0)
            } else {
                await notificationService.scheduleReminderSchedules(reminders, modelContext: modelContext)
            }
        }
    }

    private func generateJourneyInline(
        name: String,
        prayer: String,
        reminderWindow: String
    ) async -> OnboardingBootstrapResult? {
        guard let prepared = await prepareJourneyInline(name: name, prayer: prayer, reminderWindow: reminderWindow) else {
            return nil
        }
        return await commitPreparedJourney(prepared, name: name, prayer: prayer)
    }

    private func prepareJourneyInline(
        name: String,
        prayer: String,
        reminderWindow: String
    ) async -> PreparedOnboardingJourney? {
        guard connectivityService.isOnline else {
            rootLogger.log("inline prepare skipped: offline")
            return nil
        }
        guard !isBootstrappingJourney else {
            rootLogger.log("inline prepare skipped: already running")
            return nil
        }

        isBootstrappingJourney = true
        defer { isBootstrappingJourney = false }
        rootLogger.log("inline prepare started")

        do {
            let seed = try await bootstrapProvider.seed(
                name: name,
                prayerIntentText: prayer,
                goalIntentText: nil,
                reminderWindow: reminderWindow
            )
            let inferredGrowthFocus = seed.growthFocus ?? seed.journeyCategory

            let theme = JourneyThemeKey(rawValue: seed.themeKey.lowercased()) ?? .basic
            let temporaryJourney = PrayerJourney(
                title: seed.journeyTitle,
                category: seed.journeyCategory,
                themeKey: theme,
                growthFocus: inferredGrowthFocus,
                journeyArc: encodeJourneyArc(seed.journeyArc),
                status: .active
            )
            let temporaryProfile = OnboardingProfile(
                name: name,
                prayerFocus: prayer,
                growthGoal: inferredGrowthFocus,
                reminderWindow: reminderWindow,
                blocker: ""
            )
            let temporaryMemory = JourneyMemorySnapshot(
                journeyID: temporaryJourney.id,
                summary: seed.initialMemory.summary,
                winsSummary: seed.initialMemory.winsSummary,
                blockersSummary: seed.initialMemory.blockersSummary,
                preferredTone: seed.initialMemory.preferredTone
            )
            let package = try await BackendDailyJourneyPackageProvider().generatePackage(
                profile: temporaryProfile,
                journey: temporaryJourney,
                recentEntries: [],
                memory: temporaryMemory
            )
            rootLogger.log("inline prepare succeeded journeyTitle=\(seed.journeyTitle, privacy: .public)")
            return PreparedOnboardingJourney(seed: seed, package: package)
        } catch {
            let details = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            rootLogger.error("inline prepare failed error=\(details, privacy: .public)")
            onboardingErrorMessage = details.isEmpty
                ? "We couldn't create your first journey right now. Connect to the internet and try again."
                : "We couldn't create your first journey: \(details)"
            return nil
        }
    }

    @MainActor
    private func commitPreparedJourney(
        _ prepared: PreparedOnboardingJourney,
        name: String,
        prayer: String
    ) async -> OnboardingBootstrapResult? {
        let seed = prepared.seed
        let initialPackage = DailyJourneyPackageValidation.validated(prepared.package)
        let inferredGrowthFocus = seed.growthFocus ?? seed.journeyCategory
        let theme = JourneyThemeKey(rawValue: seed.themeKey.lowercased()) ?? .basic
        let firstJourney = PrayerJourney(
            title: seed.journeyTitle,
            category: seed.journeyCategory,
            themeKey: theme,
            growthFocus: inferredGrowthFocus,
            journeyArc: encodeJourneyArc(seed.journeyArc),
            status: .active
        )
        modelContext.insert(firstJourney)

        let entry = PrayerEntry(
            prompt: initialPackage.prayer,
            scriptureReference: initialPackage.scriptureReference,
            scriptureText: initialPackage.scriptureParaphrase,
            actionStep: "",
            journey: firstJourney
        )
        modelContext.insert(entry)

        let dayKey = JourneyContentService.dayKey(for: .now)
        let record = DailyJourneyPackageRecord(
            journeyID: firstJourney.id,
            dayKey: dayKey,
            dailyTitle: initialPackage.dailyTitle,
            reflectionThought: initialPackage.reflectionThought,
            scriptureReference: initialPackage.scriptureReference,
            scriptureParaphrase: initialPackage.scriptureParaphrase,
            prayer: initialPackage.prayer,
            todayAim: initialPackage.todayAim,
            smallStepQuestion: initialPackage.smallStepQuestion,
            suggestedSteps: initialPackage.suggestedSteps,
            completionSuggestion: initialPackage.completionSuggestion,
            updatedJourneyArc: initialPackage.updatedJourneyArc,
            qualityVersion: initialPackage.qualityVersion,
            generatedAt: initialPackage.generatedAt,
            source: .remote,
            linkedEntryID: entry.id
        )
        modelContext.insert(record)

        let snapshot = JourneyMemorySnapshot(
            journeyID: firstJourney.id,
            summary: seed.initialMemory.summary,
            winsSummary: seed.initialMemory.winsSummary,
            blockersSummary: seed.initialMemory.blockersSummary,
            preferredTone: seed.initialMemory.preferredTone
        )
        modelContext.insert(snapshot)

        JourneyProgressService.logEvent(
            journeyID: firstJourney.id,
            type: .packageGenerated,
            notes: "Initial onboarding package seeded from prepared staged endpoints.",
            modelContext: modelContext
        )

        try? modelContext.save()
        syncWidgetSnapshot()
        analytics.track(.journeyCreated, properties: ["source": "inline_staged_prepare"])
        return OnboardingBootstrapResult(package: record, inferredGrowthFocus: inferredGrowthFocus)
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

        await packageWarmupService.warmActiveJourneys(
            profile: profile,
            journeys: activeJourneys,
            entriesByJourneyID: entriesByJourneyID,
            memoryByJourneyID: memoryByJourneyID,
            isOnline: true,
            modelContext: modelContext
        )
        syncWidgetSnapshot()
    }

    private func warmJourneyIfPossible(journeyID: UUID) async -> JourneyPackageWarmupResult {
        guard connectivityService.isOnline, let profile else { return .skipped }
        guard let journey = activeJourneys.first(where: { $0.id == journeyID }) else { return .skipped }
        let entries = allEntries.filter { $0.journey?.id == journeyID }
        let memory = memorySnapshots.first(where: { $0.journeyID == journeyID })
        let result = await packageWarmupService.warmToday(
            profile: profile,
            journey: journey,
            entries: entries,
            memory: memory,
            isOnline: true,
            modelContext: modelContext
        )
        syncWidgetSnapshot()
        return result
    }

    private func nextLikelyRefreshDate() -> Date {
        let enabled = fetchReminderSchedules().filter(\.isEnabled)
        let targetHour = enabled.first?.hour ?? hourForReminderWindow(profile?.reminderWindow ?? "Morning")
        var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        components.hour = max(0, targetHour - 1)
        components.minute = 0
        let todayTarget = Calendar.current.date(from: components) ?? .now
        if todayTarget > .now {
            return todayTarget
        }
        return Calendar.current.date(byAdding: .day, value: 1, to: todayTarget) ?? Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now
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
            let seed = try await bootstrapProvider.seed(
                name: profile.name,
                prayerIntentText: profile.prayerFocus,
                goalIntentText: profile.growthGoal,
                reminderWindow: profile.reminderWindow
            )

            let theme = JourneyThemeKey(rawValue: seed.themeKey.lowercased()) ?? .basic
            let firstJourney = PrayerJourney(
                title: seed.journeyTitle,
                category: seed.journeyCategory,
                themeKey: theme,
                growthFocus: seed.growthFocus ?? seed.journeyCategory,
                journeyArc: encodeJourneyArc(seed.journeyArc),
                status: .active
            )
            modelContext.insert(firstJourney)

            let snapshot = JourneyMemorySnapshot(
                journeyID: firstJourney.id,
                summary: seed.initialMemory.summary,
                winsSummary: seed.initialMemory.winsSummary,
                blockersSummary: seed.initialMemory.blockersSummary,
                preferredTone: seed.initialMemory.preferredTone
            )
            modelContext.insert(snapshot)

            JourneyProgressService.logEvent(
                journeyID: firstJourney.id,
                type: .packageGenerated,
                notes: "Initial journey seeded; package warmup requested.",
                modelContext: modelContext
            )

            try? modelContext.save()
            syncWidgetSnapshot()
            rootLogger.log("bootstrap seed succeeded journeyTitle=\(seed.journeyTitle, privacy: .public) theme=\(seed.themeKey, privacy: .public)")
            analytics.track(.journeyCreated, properties: ["source": "bootstrap_seed"])
            _ = await warmJourneyIfPossible(journeyID: firstJourney.id)
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

    private func ensureDefaultReminderScheduleIfNeeded(from reminderWindow: String) {
        guard reminderSchedules.isEmpty else { return }
        let reminder = ReminderSchedule(
            hour: hourForReminderWindow(reminderWindow),
            minute: 0,
            isEnabled: true,
            sortOrder: 0
        )
        modelContext.insert(reminder)
    }

    private func paywallPersonalizationContext(for triggerReason: String?) -> PaywallPersonalizationContext {
        let journey = personalizationJourney(for: triggerReason)
        let todayKey = JourneyContentService.dayKey(for: .now)
        let package = packageRecords.first { record in
            guard let journey else { return false }
            return record.journeyID == journey.id && record.dayKey == todayKey
        } ?? packageRecords.first { record in
            guard let journey else { return false }
            return record.journeyID == journey.id
        }

        return PaywallPersonalizationContext(
            journeyTitle: journey?.title,
            dailyTitle: package?.dailyTitle,
            scriptureReference: package?.scriptureReference,
            reflectionExcerpt: package?.reflectionThought,
            plantProgressText: plantProgressSummary(for: journey),
            prayerConcern: profile?.prayerFocus ?? journey?.growthFocus
        )
    }

    private func personalizationJourney(for triggerReason: String?) -> PrayerJourney? {
        if triggerReason == PaywallTriggerReason.onboardingCompletion.rawValue {
            return activeJourneys.first ?? allJourneys.first
        }
        return allJourneys.first ?? activeJourneys.first
    }

    private func plantProgressSummary(for journey: PrayerJourney?) -> String? {
        guard let journey else { return nil }
        let entries = allEntries.filter { $0.journey?.id == journey.id }
        let streakCount = JourneyEngagementService.effectiveStreakCount(
            for: journey,
            entries: entries,
            now: .now
        )
        let completedCount = max(journey.completedTends, entries.filter { $0.completedAt != nil }.count)

        if streakCount > 0 {
            let format = L10n.string("paywall.progress.streak", default: "%d day streak")
            return String(format: format, streakCount)
        }
        if completedCount > 0 {
            let format = L10n.string("paywall.progress.completed", default: "%d Tends completed")
            return String(format: format, completedCount)
        }
        return nil
    }

    private func paywallVariant(for triggerReason: String) -> String {
        if triggerReason == PaywallTriggerReason.onboardingCompletion.rawValue {
            return "onboarding_hard"
        }
        return "standard_personalized"
    }

    private func maybePresentDownsellOffer() {
        guard DownsellPresentationPolicy.shouldPresent(
            profileExists: profile != nil,
            hasEligibleOffer: subscriptionService.hasEligibleDownsellOffer,
            alreadyShownThisForegroundSession: hasShownDownsellThisForegroundSession,
            isStandardPaywallPresented: showPaywall
        ) else {
            return
        }

        hasShownDownsellThisForegroundSession = true
        showDownsellPaywall = true
        analytics.track(
            .paywallShown,
            properties: [
                "paywall_variant": "downsell_personalized",
                "trigger_reason": "trial_cancel_downsell",
                "has_personalized_preview": paywallPersonalizationContext(for: nil).hasPreview ? "true" : "false",
                "default_package": "monthly",
                "paywall_mode": subscriptionService.paywallMode.rawValue,
                "has_premium": subscriptionService.isPremium ? "true" : "false"
            ]
        )
    }

    private func syncPaywallPresentationState(now: Date = .now) {
        if AppConstants.Debug.bypassPaywall {
            settings?.pendingPaywallReason = nil
            showPaywall = false
            return
        }

        let hardPaywallRequired = MonetizationPolicy.requiresHardPaywallAfterDismiss(
            settings: settings,
            paywallMode: subscriptionService.paywallMode,
            now: now
        )
        let onboardingPaywallPending =
            settings?.pendingPaywallReason == PaywallTriggerReason.onboardingCompletion.rawValue
            && settings?.paywallDismissedAt == nil
        let dismissOfferPending =
            settings?.pendingPaywallReason == PaywallTriggerReason.paywallDismissOffer.rawValue

        guard profile == nil || hardPaywallRequired || onboardingPaywallPending || dismissOfferPending else {
            showPaywall = false
            return
        }
        showPaywall = dismissOfferPending || onboardingPaywallPending || MonetizationPolicy.requiresPaywall(
            hasPremium: subscriptionService.isPremium,
            settings: settings,
            paywallMode: subscriptionService.paywallMode,
            now: now
        )
    }

    private func paywallConfigForCurrentState(now: Date = .now) -> PaywallRemoteConfig {
        let base = subscriptionService.paywallConfig
        let triggerReason = settings?.pendingPaywallReason

        if triggerReason == PaywallTriggerReason.onboardingCompletion.rawValue {
            return PaywallRemoteConfig.onboardingHardGate(from: base)
        }

        if triggerReason == PaywallTriggerReason.paywallDismissOffer.rawValue {
            return PaywallRemoteConfig(
                headline: L10n.string(
                    "paywall.dismiss_offer.headline",
                    default: "Stay on track with 50% off your first year."
                ),
                subheadline: L10n.string(
                    "paywall.dismiss_offer.subheadline",
                    default: "You just started your journey. Keep momentum with a one-time first-year discount."
                ),
                ctaTitle: L10n.string(
                    "paywall.dismiss_offer.cta",
                    default: "Claim 50% Off First Year"
                ),
                annualBadgeText: L10n.string(
                    "paywall.dismiss_offer.badge",
                    default: "50% Off Year One"
                ),
                footnote: L10n.string(
                    "paywall.dismiss_offer.footnote",
                    default: "After your first year, your plan renews at the full annual price. Cancel anytime in Settings."
                ),
                defaultPackageToken: "annual",
                isDismissable: true
            )
        }

        let hardPaywallRequired = MonetizationPolicy.requiresHardPaywallAfterDismiss(
            settings: settings,
            paywallMode: subscriptionService.paywallMode,
            now: now
        )

        guard hardPaywallRequired else { return base }

        return PaywallRemoteConfig(
            headline: base.headline,
            subheadline: L10n.string(
                "paywall.hard_gate.subheadline",
                default: "Unlock Tend Premium to continue your journey."
            ),
            ctaTitle: L10n.string(
                "paywall.hard_gate.cta",
                default: "Continue with Premium"
            ),
            annualBadgeText: base.annualBadgeText,
            footnote: L10n.string(
                "paywall.hard_gate.footnote",
                default: "Auto-renews unless canceled in Settings."
            ),
            defaultPackageToken: base.defaultPackageToken,
            isDismissable: false
        )
    }

    private func handlePaywallDismissed(now: Date = .now) {
        guard !subscriptionService.isPremium else { return }
        let config = paywallConfigForCurrentState(now: now)
        guard config.isDismissable else {
            DispatchQueue.main.async {
                self.showPaywall = true
            }
            return
        }
        guard let settings else { return }
        let dismissedReason = settings.pendingPaywallReason

        if dismissedReason != PaywallTriggerReason.paywallDismissOffer.rawValue || settings.paywallDismissedAt == nil {
            settings.markPaywallDismissed(now: now)
        }
        if dismissedReason != PaywallTriggerReason.paywallDismissOffer.rawValue {
            analytics.track(
                .freeTrialStarted,
                properties: [
                    "source": "paywall_dismissed",
                    "trigger_reason": dismissedReason ?? "unspecified",
                    "paywall_mode": subscriptionService.paywallMode.rawValue
                ]
            )
        }

        let shouldShowDismissOffer = shouldPresentDismissOffer(after: dismissedReason, config: config)
        settings.pendingPaywallReason = shouldShowDismissOffer ? PaywallTriggerReason.paywallDismissOffer.rawValue : nil
        try? modelContext.save()

        if shouldShowDismissOffer {
            DispatchQueue.main.async {
                self.showPaywall = true
            }
        }
    }

    private func shouldPresentDismissOffer(after dismissedReason: String?, config: PaywallRemoteConfig) -> Bool {
        guard config.isDismissable else { return false }
        guard subscriptionService.paywallConfig.isDismissable else { return false }
        guard dismissedReason == PaywallTriggerReason.onboardingCompletion.rawValue else { return false }
        return true
    }

    private func fetchReminderSchedules() -> [ReminderSchedule] {
        let descriptor = FetchDescriptor<ReminderSchedule>(sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == AppConstants.DeepLink.scheme else { return }

        let host = url.host?.lowercased()
        let normalizedPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        if host == AppConstants.DeepLink.homeHost || normalizedPath == AppConstants.DeepLink.homeHost {
            selectedTab = .home
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        if let journeyValue = queryItems.first(where: { $0.name.lowercased() == AppConstants.DeepLink.journeyQueryKey })?.value {
            pendingJourneyIDRaw = journeyValue
        }
        if let actionValue = queryItems.first(where: { $0.name.lowercased() == AppConstants.DeepLink.actionQueryKey })?.value {
            pendingHomeActionRaw = actionValue.lowercased()
        } else if host == AppConstants.DeepLink.homeHost || normalizedPath == AppConstants.DeepLink.homeHost {
            pendingHomeActionRaw = ""
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
