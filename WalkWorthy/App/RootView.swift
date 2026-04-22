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

    @State private var selectedTab: RootTab = .home
    @State private var showPaywall = false
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
                ExperimentalOnboardingFlowView(
                    onGenerate: { name, prayer, goal in
                        return await generateJourneyInline(name: name, prayer: prayer, goal: goal, reminderWindow: "System")
                    },
                    onComplete: { completedProfile in
                        Task { await completeOnboarding(with: completedProfile) }
                    },
                    onRequirePaywall: triggerPaywall,
                    experimentConfig: onboardingExperimentConfig
                )
            }
        }
        .task {
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
            syncWidgetSnapshot()
            if notificationService.authorizationStatus == .authorized {
                let reminders = fetchReminderSchedules()
                await notificationService.scheduleReminderSchedules(
                    reminders.filter(\.isEnabled),
                    modelContext: modelContext
                )
            }
        }
        .onChange(of: subscriptionService.isPremium) { _, isPremium in
            if isPremium {
                settings?.pendingPaywallReason = nil
                settings?.clearPaywallDismissed()
                try? modelContext.save()
                showPaywall = false
            } else {
                syncPaywallPresentationState()
            }
        }
        .onChange(of: subscriptionService.paywallMode) { _, _ in
            syncPaywallPresentationState()
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
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            syncPaywallPresentationState()
            Task {
                await notificationService.refreshAuthorizationStatus()
                notificationService.recordAppOpen(modelContext: modelContext)
                guard notificationService.authorizationStatus == .authorized else { return }
                await notificationService.scheduleReminderSchedules(
                    fetchReminderSchedules().filter(\.isEnabled),
                    modelContext: modelContext
                )
            }
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
            guard isShown else { return }
            let triggerReason = settings?.pendingPaywallReason ?? "unspecified"
            if subscriptionService.paywallMode == .firstTendReviewThenPaywall {
                FirstTendMilestoneService.markPaywallShownAfterFirstTend(settings: settings)
                try? modelContext.save()
            }
            analytics.track(
                .paywallShown,
                properties: [
                    "trigger_reason": triggerReason,
                    "paywall_mode": subscriptionService.paywallMode.rawValue,
                    "has_premium": subscriptionService.isPremium ? "true" : "false",
                    "is_dismiss_offer": triggerReason == PaywallTriggerReason.paywallDismissOffer.rawValue ? "true" : "false"
                ]
            )
        }
        .fullScreenCover(isPresented: $showPaywall, onDismiss: {
            handlePaywallDismissed()
        }) {
            let config = paywallConfigForCurrentState()
            PaywallView(
                triggerReason: settings?.pendingPaywallReason,
                isPremium: subscriptionService.isPremium,
                copyOverride: config
            )
            .interactiveDismissDisabled(!config.isDismissable)
            .environmentObject(subscriptionService)
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

    private func generateJourneyInline(name: String, prayer: String, goal: String, reminderWindow: String) async -> DailyJourneyPackageRecord? {
        guard connectivityService.isOnline else {
            rootLogger.log("inline bootstrap skipped: offline")
            return nil
        }
        guard !isBootstrappingJourney else {
            rootLogger.log("inline bootstrap skipped: already running")
            return nil
        }

        isBootstrappingJourney = true
        defer { isBootstrappingJourney = false }
        rootLogger.log("inline bootstrap started")

        do {
            let payload = try await bootstrapProvider.bootstrap(
                name: name,
                prayerIntentText: prayer,
                goalIntentText: goal,
                reminderWindow: reminderWindow
            )
            let initialPackage = DailyJourneyPackageValidation.validated(payload.initialPackage)

            let theme = JourneyThemeKey(rawValue: payload.themeKey.lowercased()) ?? .basic
            let firstJourney = PrayerJourney(
                title: payload.journeyTitle,
                category: payload.journeyCategory,
                themeKey: theme,
                growthFocus: payload.growthFocus ?? payload.journeyCategory,
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
                reflectionThought: initialPackage.reflectionThought,
                scriptureReference: initialPackage.scriptureReference,
                scriptureParaphrase: initialPackage.scriptureParaphrase,
                prayer: initialPackage.prayer,
                smallStepQuestion: initialPackage.smallStepQuestion,
                suggestedSteps: initialPackage.suggestedSteps,
                completionSuggestion: initialPackage.completionSuggestion,
                generatedAt: initialPackage.generatedAt,
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
                notes: "Initial onboarding package seeded from inline endpoint.",
                modelContext: modelContext
            )

            try? modelContext.save()
            syncWidgetSnapshot()
            rootLogger.log("inline bootstrap succeeded journeyTitle=\(payload.journeyTitle, privacy: .public)")
            analytics.track(.journeyCreated, properties: ["source": "inline_bootstrap"])
            return record
        } catch {
            let details = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            rootLogger.error("inline bootstrap failed error=\(details, privacy: .public)")
            onboardingErrorMessage = details.isEmpty
                ? "We couldn't create your first journey right now. Connect to the internet and try again."
                : "We couldn't create your first journey: \(details)"
            return nil
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
            let initialPackage = DailyJourneyPackageValidation.validated(payload.initialPackage)

            let theme = JourneyThemeKey(rawValue: payload.themeKey.lowercased()) ?? .basic
            let firstJourney = PrayerJourney(
                title: payload.journeyTitle,
                category: payload.journeyCategory,
                themeKey: theme,
                growthFocus: payload.growthFocus ?? payload.journeyCategory,
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
                reflectionThought: initialPackage.reflectionThought,
                scriptureReference: initialPackage.scriptureReference,
                scriptureParaphrase: initialPackage.scriptureParaphrase,
                prayer: initialPackage.prayer,
                smallStepQuestion: initialPackage.smallStepQuestion,
                suggestedSteps: initialPackage.suggestedSteps,
                completionSuggestion: initialPackage.completionSuggestion,
                generatedAt: initialPackage.generatedAt,
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
        guard config.isDismissable else { return }
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
