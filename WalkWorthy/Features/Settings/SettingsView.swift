import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue: String = AppLanguage.system.rawValue
    @AppStorage("homeBackgroundTheme") private var backgroundTheme: HomeBackgroundTheme = .none
#if DEBUG
    @AppStorage(AppConstants.Debug.bypassPaywallOverrideStorageKey) private var debugBypassPaywallOverride = false
    @AppStorage(AppConstants.Debug.fastDayTestingOverrideStorageKey) private var debugFastDayTestingOverride = false
#endif
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @EnvironmentObject private var notificationService: NotificationService
    @Environment(\.modelContext) private var modelContext
    @State private var showDownsellPaywall = false
    @State private var showResubscribePaywall = false
    @State private var showStandardPaywall = false
#if DEBUG
    @State private var showOnboardingSimulator = false
#endif

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

#if DEBUG
                Section(L10n.string("settings.debug.section", default: "Debug Testing")) {
                    if AppConstants.Debug.debugTestingEnabled {
                        Toggle(L10n.string("settings.debug.bypass_paywall", default: "Bypass Paywall (Debug)"), isOn: $debugBypassPaywallOverride)
                        Toggle(L10n.string("settings.debug.fast_day_tending", default: "Fast-Day Tending (Debug)"), isOn: $debugFastDayTestingOverride)

                        Button(L10n.string("settings.debug.launch_onboarding_simulator", default: "Launch Onboarding Simulator")) {
                            showOnboardingSimulator = true
                        }
                        .foregroundStyle(WWColor.growGreen)

                        Button(L10n.string("settings.debug.reset_fast_day_offset", default: "Reset Fast-Day Offset")) {
                            AppConstants.Debug.resetFastDayOffset()
                        }
                        .foregroundStyle(WWColor.growGreen)
                    } else {
                        Text(L10n.string("settings.debug.enable_instructions", default: "Enable with `-TEND_DEBUG_TESTING 1` in your Run scheme arguments/environment."))
                            .font(WWTypography.caption(14))
                            .foregroundStyle(WWColor.muted)
                    }
                }
                .listRowBackground(WWColor.surface)
#endif
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
                DownsellPaywallView()
                    .environmentObject(subscriptionService)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showResubscribePaywall) {
                PaywallView(
                    triggerReason: "settings_resubscribe",
                    isPremium: subscriptionService.isPremium,
                    copyOverride: .resubscribe
                )
                .environmentObject(subscriptionService)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showStandardPaywall) {
                PaywallView(
                    triggerReason: "settings_upgrade",
                    isPremium: subscriptionService.isPremium,
                    copyOverride: nil
                )
                .environmentObject(subscriptionService)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
#if DEBUG
            .fullScreenCover(isPresented: $showOnboardingSimulator) {
                DebugOnboardingSimulatorView()
            }
#endif
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
                    onGenerate: { name, prayer in
                        await debugBootstrapResult(name: name, prayer: prayer, container: container)
                    },
                    onComplete: { _ in
                        dismiss()
                    },
                    onRequirePaywall: { _ in
                        // Intentionally no-op for simulator.
                    },
                    experimentConfig: OnboardingExperimentConfig(
                        variant: "debug-sim",
                        preJourneyOrder: ["prayerIntent", "name"],
                        postJourneyOrder: ["backgroundSelection", "review"],
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
}
#endif

private struct DownsellPaywallView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var isPurchasing = false

    private var introPriceText: String? {
        subscriptionService.downsellOfferSummary?.introPriceLabel
    }

    private var basePriceText: String? {
        subscriptionService.downsellOfferSummary?.basePriceLabel
    }

    var body: some View {
        ZStack {
            WWColor.white.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        offerCard

                        Button {
                            Task { await purchase() }
                        } label: {
                            HStack {
                                Spacer()
                                if isPurchasing {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(L10n.string("downsell.cta.keep_going", default: "Keep Going"))
                                        .font(WWTypography.heading(20))
                                }
                                Spacer()
                            }
                            .padding(.vertical, 16)
                            .foregroundStyle(.white)
                            .background(WWColor.growGreen, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(isPurchasing || !subscriptionService.hasEligibleDownsellOffer)
                        .opacity((isPurchasing || !subscriptionService.hasEligibleDownsellOffer) ? 0.65 : 1)
                        .accessibilityHint(L10n.string("downsell.cta.hint", default: "Purchases the limited-time renewal offer."))

                        Text(downsellRenewalLine)
                            .font(WWTypography.caption(12))
                            .foregroundStyle(WWColor.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        footerLinks

                        if let errorMessage = subscriptionService.errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(WWTypography.caption(13))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
        .task {
            await subscriptionService.loadProducts()
            await subscriptionService.refreshEntitlements()
        }
        .onChange(of: subscriptionService.isPremium) { _, isPremium in
            if isPremium {
                dismiss()
            }
        }
        .onChange(of: subscriptionService.hasEligibleDownsellOffer) { _, isAvailable in
            if !isAvailable {
                dismiss()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppConstants.appName)
                    .font(WWTypography.heading(20))
                    .foregroundStyle(WWColor.nearBlack)
                Text(L10n.string("downsell.subtitle", default: "You canceled your trial. Keep your momentum."))
                    .font(WWTypography.body(16))
                    .foregroundStyle(WWColor.muted)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(WWColor.muted)
                    .frame(width: 36, height: 36)
                    .background(WWColor.surface, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string("common.close", default: "Close"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var offerCard: some View {
        VStack(spacing: 10) {
            Text(L10n.string("downsell.headline", default: "Keep the progress you've started"))
                .font(WWTypography.display(34))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.72)

            Text(downsellIntroLine)
                .font(WWTypography.body(17))
                .foregroundStyle(WWColor.muted)
                .multilineTextAlignment(.center)

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                WWColor.growGreen.opacity(0.26),
                                WWColor.growGreen.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 130)

                Image(systemName: "leaf.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(WWColor.growGreen)
                    .frame(width: 74, height: 74)
                    .accessibilityHidden(true)
            }
        }
        .padding(14)
        .background(WWColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var downsellIntroLine: String {
        if let introPriceText {
            let format = L10n.string(
                "downsell.intro_with_price",
                default: "Stay on the journey for %@/month for your first 3 months."
            )
            return String(format: format, introPriceText)
        }
        return L10n.string(
            "downsell.intro_generic",
            default: "Stay on the journey with a limited-time monthly intro offer."
        )
    }

    private var downsellRenewalLine: String {
        if let basePriceText {
            let format = L10n.string(
                "downsell.renewal_with_price",
                default: "Renews at %@ / month after intro period. Cancel anytime in Settings."
            )
            return String(format: format, basePriceText)
        }
        return L10n.string(
            "downsell.renewal_generic",
            default: "Renews at the standard monthly price after intro period. Cancel anytime in Settings."
        )
    }

    private var footerLinks: some View {
        HStack(spacing: 20) {
            Button(L10n.string("settings.subscription.restore", default: "Restore Purchases")) {
                Task { await subscriptionService.restorePurchases() }
            }
            .buttonStyle(.plain)
            .font(WWTypography.caption(14))
            .frame(minHeight: 44)

            Button(L10n.string("paywall.footer.terms", default: "Terms")) {
                openURL(URL(string: AppConstants.termsURL)!)
            }
            .buttonStyle(.plain)
            .font(WWTypography.caption(14))
            .frame(minHeight: 44)

            Button(L10n.string("paywall.footer.privacy", default: "Privacy")) {
                openURL(URL(string: AppConstants.privacyURL)!)
            }
            .buttonStyle(.plain)
            .font(WWTypography.caption(14))
            .frame(minHeight: 44)
        }
        .foregroundStyle(WWColor.muted)
    }

    private func purchase() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        await subscriptionService.purchaseDownsellOffer()
    }
}
