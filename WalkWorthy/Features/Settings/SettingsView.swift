import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue: String = AppLanguage.system.rawValue
    @AppStorage("homeBackgroundTheme") private var backgroundTheme: HomeBackgroundTheme = .none
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @EnvironmentObject private var notificationService: NotificationService
    @Environment(\.modelContext) private var modelContext
    @State private var showDownsellPaywall = false
    @State private var showResubscribePaywall = false
    @State private var showStandardPaywall = false

    @Query(sort: \AppSettings.id) private var settingsRows: [AppSettings]
    @Query(sort: \ReminderSchedule.sortOrder) private var reminderRows: [ReminderSchedule]
    @Query(
        filter: #Predicate<PrayerJourney> { !$0.isArchived },
        sort: \PrayerJourney.createdAt,
        order: .reverse
    ) private var activeJourneys: [PrayerJourney]

    private var settings: AppSettings? {
        settingsRows.first
    }

    private var firstReminder: ReminderSchedule? {
        reminderRows.first
    }

    private var supportsWidgetsOnCurrentDevice: Bool {
        UIDevice.current.userInterfaceIdiom != .pad
    }

    private var selectedAppLanguage: AppLanguage {
        AppLanguage.parseStoredLanguage(appLanguageRawValue)
    }

    var body: some View {
        NavigationStack {
            List {
                 Section(L10n.string("settings.subscription.section", default: "Subscription")) {
                    HStack {
                        Text(L10n.string("settings.subscription.status", default: "Status"))
                            .foregroundStyle(WWColor.nearBlack)
                        Spacer()
                        Text(
                            subscriptionService.isPremium
                                ? L10n.string("settings.subscription.premium", default: "Premium")
                                : L10n.string("settings.subscription.free", default: "Free")
                        )
                            .foregroundStyle(subscriptionService.isPremium ? WWColor.growGreen : WWColor.muted)
                    }

                    Button(L10n.string("settings.subscription.restore", default: "Restore Purchases")) {
                        Task { await subscriptionService.restorePurchases() }
                    }
                    .foregroundStyle(WWColor.nearBlack)

                    if AppConstants.Debug.bypassPaywall {
                        Text(
                            L10n.string(
                                "settings.debug.paywall_bypass_enabled",
                                default: "Paywall bypass is enabled for this debug build."
                            )
                        )
                            .foregroundStyle(WWColor.muted)
                    } else if subscriptionService.hasEligibleDownsellOffer {
                        Button(subscriptionService.downsellSettingsButtonTitle) {
                            showDownsellPaywall = true
                        }
                        .foregroundStyle(WWColor.growGreen)
                    } else if subscriptionService.isLapsedSubscriber {
                        Button(L10n.string("settings.subscription.resubscribe", default: "Resubscribe")) {
                            showResubscribePaywall = true
                        }
                        .foregroundStyle(WWColor.growGreen)
                    } else if !subscriptionService.isPremium {
                        Button(L10n.string("settings.subscription.view_options", default: "View Premium Options")) {
                            showStandardPaywall = true
                        }
                        .foregroundStyle(WWColor.growGreen)
                    }
                }
                .listRowBackground(WWColor.surface)

                Section(L10n.string("settings.reminders.section", default: "Reminders")) {
                    ForEach(reminderRows) { reminder in
                        HStack {
                            DatePicker("", selection: Binding(
                                get: { Calendar.current.date(from: DateComponents(hour: reminder.hour, minute: reminder.minute)) ?? .now },
                                set: { value in
                                    let c = Calendar.current.dateComponents([.hour, .minute], from: value)
                                    reminder.hour = c.hour ?? 8
                                    reminder.minute = c.minute ?? 0
                                    try? modelContext.save()
                                    Task { await notificationService.scheduleReminderSchedules(reminderRows, modelContext: modelContext) }
                                }
                            ), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { reminder.isEnabled },
                                set: { value in
                                    reminder.isEnabled = value
                                    try? modelContext.save()
                                    Task { await notificationService.scheduleReminderSchedules(reminderRows, modelContext: modelContext) }
                                }
                            ))
                            .labelsHidden()
                            .tint(WWColor.growGreen)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            modelContext.delete(reminderRows[index])
                        }
                        try? modelContext.save()
                        Task { await notificationService.scheduleReminderSchedules(reminderRows.filter { !$0.isDeleted }, modelContext: modelContext) }
                    }

                    Button {
                        let newReminder = ReminderSchedule(hour: 8, minute: 0, isEnabled: true, sortOrder: reminderRows.count)
                        modelContext.insert(newReminder)
                        try? modelContext.save()
                    } label: {
                        Label(L10n.string("settings.reminders.add", default: "Add Reminder"), systemImage: "plus.circle.fill")
                            .foregroundStyle(WWColor.growGreen)
                    }
                    
                    if notificationService.authorizationStatus != .authorized {
                        Button(L10n.string("settings.reminders.enable_notifications", default: "Enable System Notifications")) {
                            Task {
                                _ = await notificationService.requestAuthorization()
                                await notificationService.scheduleReminderSchedules(reminderRows, modelContext: modelContext)
                            }
                        }
                        .foregroundStyle(WWColor.growGreen)
                    }
                }
                .listRowBackground(WWColor.surface)

                Section(L10n.string("settings.appearance.section", default: "Appearance")) {
                    Picker(L10n.string("settings.language.title", default: "App Language"), selection: $appLanguageRawValue) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName(localizedIn: selectedAppLanguage)).tag(language.rawValue)
                        }
                    }
                    .foregroundStyle(WWColor.nearBlack)

                    Picker(L10n.string("settings.appearance.home_background", default: "Home Background"), selection: $backgroundTheme) {
                        ForEach(HomeBackgroundTheme.allCases) { theme in
                            Text(theme.localizedDisplayName).tag(theme)
                        }
                    }
                    .foregroundStyle(WWColor.nearBlack)
                    
                    if let assetName = backgroundTheme.assetName {
                        Image(assetName)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.vertical, 8)
                    }
                }
                .listRowBackground(WWColor.surface)

                if supportsWidgetsOnCurrentDevice {
                    Section(L10n.string("settings.widgets.section", default: "Widgets")) {
                        if activeJourneys.isEmpty {
                            Text(L10n.string("settings.widgets.empty", default: "Create a journey to choose widget content."))
                                .foregroundStyle(WWColor.muted)
                        } else {
                            Picker(L10n.string("settings.widgets.picker", default: "Widget Journey"), selection: selectedWidgetJourneyIDBinding) {
                                Text(L10n.string("settings.widgets.recent_active", default: "Most Recent Active")).tag(nil as UUID?)
                                ForEach(activeJourneys) { journey in
                                    Text(journey.title).tag(Optional(journey.id))
                                }
                            }
                            .foregroundStyle(WWColor.nearBlack)
                            .onChange(of: selectedWidgetJourneyIDBinding.wrappedValue) { _, _ in
                                WidgetSyncService.publishFromModelContext(modelContext)
                            }
                        }
                    }
                    .listRowBackground(WWColor.surface)
                }

                Section(L10n.string("settings.support.section", default: "Support & Legal")) {
                    Link(L10n.string("settings.support.contact", default: "Contact Support"), destination: URL(string: "mailto:\(AppConstants.supportEmail)")!)
                        .foregroundStyle(WWColor.nearBlack)
                    Link(L10n.string("settings.support.terms", default: "Terms of Service"), destination: URL(string: AppConstants.termsURL)!)
                        .foregroundStyle(WWColor.nearBlack)
                    Link(L10n.string("settings.support.privacy", default: "Privacy Policy"), destination: URL(string: AppConstants.privacyURL)!)
                        .foregroundStyle(WWColor.nearBlack)
                }
                .listRowBackground(WWColor.surface)

            }
            .navigationTitle(L10n.string("settings.title", default: "Settings"))
            .scrollContentBackground(.hidden)
            .background(WWColor.white.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 116)
            }
            .onAppear {
                bootstrapPrimaryReminderIfNeeded()
                Task {
                    await subscriptionService.refreshEntitlements()
                    await subscriptionService.loadProducts()
                }
            }
            .sheet(isPresented: $showDownsellPaywall) {
                DownsellPaywallView(personalizationContext: nil)
                    .environmentObject(subscriptionService)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showResubscribePaywall) {
                PaywallView(
                    triggerReason: "settings_resubscribe",
                    isPremium: subscriptionService.isPremium,
                    copyOverride: .resubscribe,
                    personalizationContext: nil
                )
                .environmentObject(subscriptionService)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showStandardPaywall) {
                PaywallView(
                    triggerReason: "settings_upgrade",
                    isPremium: subscriptionService.isPremium,
                    copyOverride: nil,
                    personalizationContext: nil
                )
                .environmentObject(subscriptionService)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .onChange(of: subscriptionService.isPremium) { _, isPremium in
                if isPremium {
                    showStandardPaywall = false
                    showResubscribePaywall = false
                    showDownsellPaywall = false
                }
            }
        }
    }

    private func bootstrapPrimaryReminderIfNeeded() {
        guard firstReminder == nil else { return }
        let defaultHour = settings?.preferredReminderHour ?? 8
        let defaultMinute = settings?.preferredReminderMinute ?? 0
        let row = ReminderSchedule(hour: defaultHour, minute: defaultMinute, isEnabled: true, sortOrder: 0)
        modelContext.insert(row)
        try? modelContext.save()
    }

    private func upsertPrimaryReminder(hour: Int, minute: Int) {
        if let existing = firstReminder {
            existing.hour = min(max(hour, 0), 23)
            existing.minute = min(max(minute, 0), 59)
            existing.isEnabled = true
            return
        }

        let row = ReminderSchedule(
            hour: min(max(hour, 0), 23),
            minute: min(max(minute, 0), 59),
            isEnabled: true,
            sortOrder: 0
        )
        modelContext.insert(row)
    }

    private var selectedWidgetJourneyIDBinding: Binding<UUID?> {
        Binding<UUID?>(
            get: {
                guard let selectedID = settings?.widgetJourneyID else { return nil }
                return activeJourneys.contains(where: { $0.id == selectedID }) ? selectedID : nil
            },
            set: { newValue in
                let row = ensureSettingsRow()
                row.widgetJourneyID = newValue
                try? modelContext.save()
            }
        )
    }

    @discardableResult
    private func ensureSettingsRow() -> AppSettings {
        if let row = settings {
            return row
        }
        let row = AppSettings()
        modelContext.insert(row)
        try? modelContext.save()
        return row
    }
}

#if DEBUG
private struct DebugOnboardingSimulatorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var debugNotificationService = NotificationService()
    @State private var debugContainer = DebugOnboardingSimulatorView.makeInMemoryContainer()
    @State private var generationErrorMessage: String?

    private let bootstrapProvider = BackendJourneyBootstrapProvider()

    var body: some View {
        Group {
            if let container = debugContainer {
                ExperimentalOnboardingFlowView(
                    onPrepare: { _, _ in
                        nil
                    },
                    onGenerate: { name, prayer in
                        await debugBootstrapResult(name: name, prayer: prayer, container: container)
                    },
                    onCommitPrepared: { prepared, _, _ in
                        await debugCommitPrepared(prepared, container: container)
                    },
                    isPremium: true,
                    onComplete: { _ in
                        dismiss()
                    },
                    onRequirePaywall: { _ in
                        // Intentionally no-op for simulator.
                    },
                    experimentConfig: OnboardingExperimentConfig(
                        variant: "debug-sim",
                        preJourneyOrder: ["prayerIntent", "name"],
                        postJourneyOrder: ["backgroundSelection", "reminder"],
                        copyOverrides: ["intro_title": "Onboarding Simulator"]
                    )
                )
                .modelContainer(container)
                .environmentObject(debugNotificationService)
                .onDisappear {
                    AppConstants.Debug.resetFastDayOffset()
                }
                .alert(
                    "Unable to Generate Journey",
                    isPresented: Binding(
                        get: { generationErrorMessage != nil },
                        set: { if !$0 { generationErrorMessage = nil } }
                    )
                ) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(generationErrorMessage ?? "")
                }
            } else {
                VStack(spacing: 18) {
                    Text(L10n.string("settings.debug.onboarding_simulator_unavailable", default: "Unable to load onboarding simulator."))
                        .font(WWTypography.heading(20))
                        .foregroundStyle(WWColor.nearBlack)
                    Button(L10n.string("settings.debug.close", default: "Close")) {
                        dismiss()
                    }
                    .font(WWTypography.heading(18))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 220)
                    .padding(.vertical, 12)
                    .background(WWColor.growGreen)
                    .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(WWColor.white.ignoresSafeArea())
            }
        }
    }

    private static func makeInMemoryContainer() -> ModelContainer? {
        do {
            let schema = Schema([
                PrayerJourney.self,
                PrayerEntry.self,
                AnsweredPrayer.self,
                OnboardingProfile.self,
                AppSettings.self,
                ReminderSchedule.self,
                JourneyMemorySnapshot.self,
                GlobalLightMemory.self,
                JourneyProgressEvent.self,
                DailyJourneyPackageRecord.self
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            return nil
        }
    }

    private func debugBootstrapResult(
        name: String,
        prayer: String,
        container: ModelContainer
    ) async -> OnboardingBootstrapResult? {
        do {
            let payload = try await bootstrapProvider.bootstrap(
                name: name,
                prayerIntentText: prayer,
                goalIntentText: nil,
                reminderWindow: "Debug Simulator"
            )
            let initialPackage = DailyJourneyPackageValidation.validated(payload.initialPackage)
            let inferredGrowthFocus = payload.growthFocus ?? payload.journeyCategory

            return await MainActor.run {
                let modelContext = container.mainContext
                let theme = JourneyThemeKey(rawValue: payload.themeKey.lowercased()) ?? .basic
                let journey = PrayerJourney(
                    title: payload.journeyTitle,
                    category: payload.journeyCategory,
                    themeKey: theme,
                    growthFocus: inferredGrowthFocus,
                    journeyArc: encodeJourneyArc(payload.journeyArc),
                    status: .active
                )
                modelContext.insert(journey)

                let entry = PrayerEntry(
                    prompt: initialPackage.prayer,
                    scriptureReference: initialPackage.scriptureReference,
                    scriptureText: initialPackage.scriptureParaphrase,
                    actionStep: "",
                    journey: journey
                )
                modelContext.insert(entry)

                let record = DailyJourneyPackageRecord(
                    journeyID: journey.id,
                    dayKey: JourneyContentService.dayKey(for: .now),
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
                    journeyID: journey.id,
                    summary: payload.initialMemory.summary,
                    winsSummary: payload.initialMemory.winsSummary,
                    blockersSummary: payload.initialMemory.blockersSummary,
                    preferredTone: payload.initialMemory.preferredTone
                )
                modelContext.insert(snapshot)
                try? modelContext.save()

                generationErrorMessage = nil
                return OnboardingBootstrapResult(
                    package: record,
                    inferredGrowthFocus: inferredGrowthFocus
                )
            }
        } catch {
            await MainActor.run {
                let details = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                generationErrorMessage = details.isEmpty
                    ? "The debug simulator could not reach the journey generator."
                    : details
            }
            return nil
        }
    }

    private func debugCommitPrepared(
        _ prepared: PreparedOnboardingJourney,
        container: ModelContainer
    ) async -> OnboardingBootstrapResult? {
        await MainActor.run {
            let modelContext = container.mainContext
            let seed = prepared.seed
            let initialPackage = DailyJourneyPackageValidation.validated(prepared.package)
            let inferredGrowthFocus = seed.growthFocus ?? seed.journeyCategory
            let theme = JourneyThemeKey(rawValue: seed.themeKey.lowercased()) ?? .basic
            let journey = PrayerJourney(
                title: seed.journeyTitle,
                category: seed.journeyCategory,
                themeKey: theme,
                growthFocus: inferredGrowthFocus,
                journeyArc: encodeJourneyArc(seed.journeyArc),
                status: .active
            )
            modelContext.insert(journey)
            let entry = PrayerEntry(
                prompt: initialPackage.prayer,
                scriptureReference: initialPackage.scriptureReference,
                scriptureText: initialPackage.scriptureParaphrase,
                actionStep: "",
                journey: journey
            )
            modelContext.insert(entry)
            let record = DailyJourneyPackageRecord(
                journeyID: journey.id,
                dayKey: JourneyContentService.dayKey(for: .now),
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
            modelContext.insert(JourneyMemorySnapshot(
                journeyID: journey.id,
                summary: seed.initialMemory.summary,
                winsSummary: seed.initialMemory.winsSummary,
                blockersSummary: seed.initialMemory.blockersSummary,
                preferredTone: seed.initialMemory.preferredTone
            ))
            try? modelContext.save()
            return OnboardingBootstrapResult(package: record, inferredGrowthFocus: inferredGrowthFocus)
        }
    }
}
#endif
