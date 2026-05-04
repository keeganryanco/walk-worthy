import SwiftUI
import SwiftData

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var connectivityService: ConnectivityService
    
    let isPremium: Bool
    let onRequirePaywall: (PaywallTriggerReason) -> Void
    let onJourneyCreated: (UUID) -> Void
    @Binding var suppressHorizontalTabSwipe: Bool
    
    @Query(sort: \PrayerJourney.createdAt, order: .reverse)
    private var allJourneys: [PrayerJourney]
    
    @State private var isCreating = false
    @State private var journeyPendingDeletion: PrayerJourney?
    @State private var journeyPendingNavigation: PrayerJourney?
    @State private var suppressionResetWorkItem: DispatchWorkItem?
    
    var body: some View {
        NavigationStack {
            ZStack {
                WWColor.white.ignoresSafeArea()

                List {
                    Section {
                        HStack {
                            Text(L10n.string("journal.title", default: "Journal"))
                                .font(WWTypography.heading(32))
                                .foregroundStyle(WWColor.nearBlack)
                            Spacer()
                            Button {
                                isCreating = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(WWColor.nearBlack)
                                    .padding(12)
                                    .background(Circle().fill(WWColor.surface))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(WWColor.white)

                    let active = allJourneys.filter { !$0.isArchived }
                    let memories = allJourneys.filter { $0.isArchived }

                    if !active.isEmpty {
                        Section {
                            ForEach(active) { journey in
                                journeyRow(journey)
                            }
                        } header: {
                            sectionHeader(L10n.string("journal.active_journeys", default: "ACTIVE JOURNEYS"))
                        }
                    }

                    if !memories.isEmpty {
                        Section {
                            ForEach(memories) { journey in
                                journeyRow(journey)
                            }
                        } header: {
                            sectionHeader(L10n.string("journal.memories", default: "MEMORIES"))
                        }
                    }

                    Section {
                        Color.clear.frame(height: 136)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(WWColor.white)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 116)
            }
            .sheet(isPresented: $isCreating) {
                CreateJourneyView(
                    isPremium: isPremium,
                    onRequirePaywall: onRequirePaywall,
                    onJourneyCreated: onJourneyCreated
                )
            }
            .onDisappear {
                suppressionResetWorkItem?.cancel()
                suppressHorizontalTabSwipe = false
            }
            .navigationDestination(item: $journeyPendingNavigation) { journey in
                JourneyDetailView(journey: journey)
            }
            .overlay {
                if let journeyPendingDeletion {
                    deleteConfirmationOverlay(for: journeyPendingDeletion)
                }
            }
        }
    }

    @ViewBuilder
    private func journeyRow(_ journey: PrayerJourney) -> some View {
        Button {
            journeyPendingNavigation = journey
        } label: {
            journeyCard(journey)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                journeyPendingDeletion = journey
            } label: {
                Label(L10n.string("common.delete", default: "Delete"), systemImage: "trash")
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowSeparator(.hidden)
        .listRowBackground(WWColor.white)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { isPressing in
            handleJourneyCardPressStateChange(isPressing)
        }, perform: {
            // No-op: use press state changes only.
        })
    }

    private func handleJourneyCardPressStateChange(_ isPressing: Bool) {
        if isPressing {
            engageHorizontalSwipeSuppression()
        } else {
            releaseHorizontalSwipeSuppression()
        }
    }

    private func engageHorizontalSwipeSuppression() {
        suppressionResetWorkItem?.cancel()
        suppressionResetWorkItem = nil
        if !suppressHorizontalTabSwipe {
            suppressHorizontalTabSwipe = true
        }
    }

    private func releaseHorizontalSwipeSuppression(after delay: TimeInterval = 0.18) {
        suppressionResetWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            suppressHorizontalTabSwipe = false
            suppressionResetWorkItem = nil
        }
        suppressionResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func deleteConfirmationOverlay(for journey: PrayerJourney) -> some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture {
                    journeyPendingDeletion = nil
                }

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string("journal.delete_journey_title", default: "Delete this journey?"))
                        .font(WWTypography.heading(22))
                        .foregroundStyle(WWColor.nearBlack)
                    Text(L10n.string("journal.delete_journey_message", default: "This journey and all its entries will be permanently deleted."))
                        .font(WWTypography.body(16))
                        .foregroundStyle(WWColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    Button {
                        journeyPendingDeletion = nil
                    } label: {
                        Text(L10n.string("common.cancel", default: "Cancel"))
                            .font(WWTypography.body(17).weight(.semibold))
                            .foregroundStyle(WWColor.nearBlack)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(WWColor.surface)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        deleteJourney(journey)
                    } label: {
                        Text(L10n.string("common.delete", default: "Delete"))
                            .font(WWTypography.body(17).weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 28, y: 14)
            .padding(.horizontal, 32)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(WWTypography.caption(12).weight(.heavy))
            .foregroundStyle(WWColor.muted)
            .tracking(2.0)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private func journeyCard(_ journey: PrayerJourney) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(WWColor.contrastCard)
                    .frame(width: 56, height: 56)
                
                if let image = getPlantUIImage(for: journey) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .shadow(color: .black.opacity(0.2), radius: 5, y: 5)
                } else {
                    Text(stageEmoji(for: effectiveCompletedTends(for: journey)))
                        .font(.system(size: 24))
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(journey.title)
                    .font(WWTypography.body(18).weight(.bold))
                    .foregroundStyle(WWColor.nearBlack)
                    .lineLimit(1)
                Text(journey.category.uppercased())
                    .font(WWTypography.caption(11).weight(.heavy))
                    .foregroundStyle(WWColor.growGreen)
                    .tracking(1.0)
            }
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(WWColor.muted)
        }
        .padding(16)
        .background(WWColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 24)
    }

    private func deleteJourney(_ journey: PrayerJourney) {
        let journeyID = journey.id
        deletePackageRecords(for: journeyID)
        deleteMemorySnapshots(for: journeyID)
        deleteProgressEvents(for: journeyID)
        clearWidgetSelectionIfNeeded(for: journeyID)
        modelContext.delete(journey)
        try? modelContext.save()
        WidgetSyncService.publishFromModelContext(modelContext)
        journeyPendingDeletion = nil
    }

    private func deletePackageRecords(for journeyID: UUID) {
        let descriptor = FetchDescriptor<DailyJourneyPackageRecord>(
            predicate: #Predicate { $0.journeyID == journeyID }
        )
        for record in (try? modelContext.fetch(descriptor)) ?? [] {
            modelContext.delete(record)
        }
    }

    private func deleteMemorySnapshots(for journeyID: UUID) {
        let descriptor = FetchDescriptor<JourneyMemorySnapshot>(
            predicate: #Predicate { $0.journeyID == journeyID }
        )
        for snapshot in (try? modelContext.fetch(descriptor)) ?? [] {
            modelContext.delete(snapshot)
        }
    }

    private func deleteProgressEvents(for journeyID: UUID) {
        let descriptor = FetchDescriptor<JourneyProgressEvent>(
            predicate: #Predicate { $0.journeyID == journeyID }
        )
        for event in (try? modelContext.fetch(descriptor)) ?? [] {
            modelContext.delete(event)
        }
    }

    private func clearWidgetSelectionIfNeeded(for journeyID: UUID) {
        let descriptor = FetchDescriptor<AppSettings>(
            sortBy: [SortDescriptor(\.lastSessionDate, order: .reverse)]
        )
        for settings in (try? modelContext.fetch(descriptor)) ?? [] where settings.widgetJourneyID == journeyID {
            settings.widgetJourneyID = nil
        }
    }
    
    private func stageEmoji(for count: Int) -> String {
        let stageNum = max(1, min(5, (count % 15) / 3 + 1))
        switch stageNum {
        case 1: return "🌰"
        case 2: return "🌱"
        case 3: return "🌿"
        case 4: return "🪴"
        default: return "🌳"
        }
    }

    private func effectiveCompletedTends(for journey: PrayerJourney) -> Int {
        let stored = journey.completedTends
        if stored > 0 {
            return stored
        }
        return journey.entries.filter { $0.completedAt != nil }.count
    }
    
    private func getPlantUIImage(for journey: PrayerJourney) -> UIImage? {
        let count = effectiveCompletedTends(for: journey)
        let stageNum = max(1, min(5, (count % 15) / 3 + 1))
        let stageToken: String
        switch stageNum {
        case 1: stageToken = "seed"
        case 2: stageToken = "sprout"
        case 3: stageToken = "young"
        case 4: stageToken = "mature"
        default: stageToken = "full_bloom"
        }

        let theme = journey.themeKey.rawValue
        
        let desired = "growth_stage_\(stageNum)_\(stageToken)_\(theme)"
        let fallback = "growth_stage_\(stageNum)_\(stageToken)_basic"
        let legacyDesired = "growth_stage_\(stageNum)_\(theme)"
        let legacyFallback = "growth_stage_\(stageNum)_basic"

        let candidates = [desired, "Plants/\(desired)", fallback, "Plants/\(fallback)", legacyDesired, "Plants/\(legacyDesired)", legacyFallback, "Plants/\(legacyFallback)"]
        for name in candidates {
            if let image = UIImage(named: name) {
                return image
            }
        }
        return nil
    }
}

struct CreateJourneyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var connectivityService: ConnectivityService
    @EnvironmentObject private var subscriptionService: SubscriptionService
    
    let isPremium: Bool
    let onRequirePaywall: (PaywallTriggerReason) -> Void
    let onJourneyCreated: (UUID) -> Void
    
    @Query(filter: #Predicate<PrayerJourney> { !$0.isArchived })
    private var activeJourneys: [PrayerJourney]

    @Query(sort: \PrayerJourney.createdAt, order: .reverse)
    private var allJourneys: [PrayerJourney]

    @Query(sort: \PrayerEntry.createdAt, order: .reverse)
    private var recentEntries: [PrayerEntry]
    
    @Query(sort: \AppSettings.lastSessionDate, order: .reverse)
    private var settingsRows: [AppSettings]

    @Query(sort: \OnboardingProfile.createdAt, order: .reverse)
    private var profiles: [OnboardingProfile]

    @Query(sort: \ReminderSchedule.sortOrder)
    private var reminderRows: [ReminderSchedule]
    
    @State private var prayerIntentText = ""
    @State private var alertMessage: String?
    @State private var isSubmitting = false
    @State private var suggestionSeed = Int.random(in: Int.min...Int.max)
    @FocusState private var focusedField: InputField?

    private let bootstrapProvider = BackendJourneyBootstrapProvider()

    init(
        isPremium: Bool,
        onRequirePaywall: @escaping (PaywallTriggerReason) -> Void,
        onJourneyCreated: @escaping (UUID) -> Void = { _ in }
    ) {
        self.isPremium = isPremium
        self.onRequirePaywall = onRequirePaywall
        self.onJourneyCreated = onJourneyCreated
    }

    private enum InputField {
        case prayer
    }

    private var starterPromptSuggestions: [String] {
        let personalized = personalizedStarterSuggestions()
        let generic = rotatedGenericStarterSuggestions()
        let mixed = interleave(primary: Array(personalized.prefix(2)), secondary: generic)
        return Array(uniqueNonEmpty(mixed).prefix(4))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                WWColor.white.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.string("create_journey.prayer_title", default: "What do you want God to help you tend right now?"))
                                .font(WWTypography.heading(18))
                                .foregroundStyle(WWColor.nearBlack)
                            TextField(L10n.string("create_journey.prayer_placeholder", default: "Share what's on your heart..."), text: newlineDismissBinding(for: $prayerIntentText), axis: .vertical)
                                .focused($focusedField, equals: .prayer)
                                .textInputAutocapitalization(.sentences)
                                .submitLabel(.done)
                                .onSubmit { focusedField = nil }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .frame(minHeight: 120, alignment: .topLeading)
                                .foregroundStyle(WWColor.nearBlack)
                                .background(WWColor.surface.opacity(0.96))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(WWColor.nearBlack.opacity(0.08), lineWidth: 1)
                                )
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.string("create_journey.starter_title", default: "Need a starter?"))
                                .font(WWTypography.caption(13).weight(.heavy))
                                .foregroundStyle(WWColor.muted)
                                .tracking(1.2)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(starterPromptSuggestions, id: \.self) { suggestion in
                                    Button {
                                        prayerIntentText = suggestion
                                    } label: {
                                        Text(suggestion)
                                            .font(WWTypography.caption(13).weight(.semibold))
                                            .foregroundStyle(WWColor.nearBlack)
                                            .multilineTextAlignment(.leading)
                                            .lineLimit(3)
                                            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(WWColor.surface.opacity(0.96))
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .stroke(WWColor.nearBlack.opacity(0.08), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Spacer(minLength: 18)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .onTapGesture {
                focusedField = nil
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel", default: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("create_journey.create_button", default: "Plant Journey")) {
                        createJourneyFromIntents()
                    }
                    .disabled(
                        isSubmitting ||
                        prayerIntentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
            .overlay {
                if isSubmitting {
                    ZStack {
                        Color.black.opacity(0.2).ignoresSafeArea()
                        ProgressView(L10n.string("create_journey.creating", default: "Creating journey..."))
                            .padding(20)
                            .background(WWColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            .alert(L10n.string("journey.error.create_title", default: "Unable to Create Journey"), isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button(L10n.string("common.ok", default: "OK"), role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }
    
    private func createJourneyFromIntents() {
        let activeCount = activeJourneys.count
        let settings = settingsRows.first
        let decision = JourneyCreationPolicy.evaluate(
            isOnline: connectivityService.isOnline,
            hasPremium: isPremium,
            activeJourneyCount: activeCount,
            settings: settings,
            paywallMode: subscriptionService.paywallMode
        )

        switch decision {
        case .allowed:
            break
        case .blocked(let reason):
            switch reason {
            case .noInternet:
                alertMessage = L10n.string(
                    "journey.error.offline_create",
                    default: "You need an internet connection to start a new journey. You can still continue your existing journeys offline."
                )
            case .paywallRequired, .freeTierLimitReached:
                // Journey creation is no longer paywalled in-app.
                alertMessage = L10n.string(
                    "journey.error.unavailable_create",
                    default: "Journey creation is currently unavailable. Please try again."
                )
            }
            return
        }

        let prayer = prayerIntentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = profiles.first?.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? (profiles.first?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Friend")
            : "Friend"
        let reminderWindow = inferredReminderWindow()

        guard !prayer.isEmpty else { return }

        isSubmitting = true
        Task {
            do {
                let seed = try await bootstrapProvider.seed(
                    name: displayName,
                    prayerIntentText: prayer,
                    goalIntentText: nil,
                    reminderWindow: reminderWindow
                )

                await MainActor.run {
                    let theme = JourneyThemeKey(rawValue: seed.themeKey.lowercased()) ?? .basic

                    let journey = PrayerJourney(
                        title: seed.journeyTitle,
                        category: seed.journeyCategory,
                        themeKey: theme,
                        growthFocus: seed.growthFocus ?? seed.journeyCategory,
                        journeyArc: encodeJourneyArc(seed.journeyArc),
                        status: .active
                    )
                    modelContext.insert(journey)

                    let snapshot = JourneyMemorySnapshot(
                        journeyID: journey.id,
                        summary: seed.initialMemory.summary,
                        winsSummary: seed.initialMemory.winsSummary,
                        blockersSummary: seed.initialMemory.blockersSummary,
                        preferredTone: seed.initialMemory.preferredTone
                    )
                    modelContext.insert(snapshot)

                    JourneyProgressService.logEvent(
                        journeyID: journey.id,
                        type: .packageGenerated,
                        notes: "Journey seed created; package warmup requested by root.",
                        modelContext: modelContext
                    )

                    try? modelContext.save()
                    WidgetSyncService.publishFromModelContext(modelContext)
                    onJourneyCreated(journey.id)
                    isSubmitting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    alertMessage = error.localizedDescription
                }
            }
        }
    }

    private func newlineDismissBinding(for source: Binding<String>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue },
            set: { newValue in
                if newValue.contains("\n") {
                    source.wrappedValue = newValue.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
                    focusedField = nil
                } else {
                    source.wrappedValue = newValue
                }
            }
        )
    }

    private func personalizedStarterSuggestions() -> [String] {
        let journeySignals = allJourneys
            .prefix(8)
            .flatMap { journey -> [String] in
                [
                    journey.growthFocus,
                    journey.title,
                    journey.category
                ]
            }

        let entrySignals = recentEntries
            .prefix(10)
            .flatMap { entry -> [String] in
                [
                    entry.actionStep,
                    entry.userReflection
                ]
            }

        let signals = uniqueNonEmpty(journeySignals + entrySignals)
        let candidates = signals.compactMap(personalizedSuggestion(from:))
        return rotated(uniqueNonEmpty(candidates), seed: suggestionSeed)
    }

    private func personalizedSuggestion(from signal: String) -> String? {
        let normalized = signal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 4 else { return nil }
        let lowercased = normalized.lowercased()

        if lowercased.contains("anx") || lowercased.contains("worr") || lowercased.contains("fear") || lowercased.contains("stress") {
            return L10n.string("create_journey.personalized_peace", default: "Trusting God with anxiety")
        }
        if lowercased.contains("pray") || lowercased.contains("consisten") || lowercased.contains("habit") {
            return L10n.string("create_journey.personalized_prayer", default: "Growing steady in prayer")
        }
        if lowercased.contains("wife") || lowercased.contains("husband") || lowercased.contains("spouse") || lowercased.contains("marriage") {
            return L10n.string("create_journey.personalized_marriage", default: "Loving my spouse well")
        }
        if lowercased.contains("friend") || lowercased.contains("family") || lowercased.contains("relationship") || lowercased.contains("forgiv") {
            return L10n.string("create_journey.personalized_relationship", default: "Healing in a relationship")
        }
        if lowercased.contains("work") || lowercased.contains("career") || lowercased.contains("decision") || lowercased.contains("wisdom") {
            return L10n.string("create_journey.personalized_wisdom", default: "Wisdom for a hard decision")
        }
        if lowercased.contains("money") || lowercased.contains("budget") || lowercased.contains("debt") || lowercased.contains("financial") {
            return L10n.string("create_journey.personalized_money", default: "Trusting God with money")
        }
        if lowercased.contains("parent") || lowercased.contains("child") || lowercased.contains("kid") {
            return L10n.string("create_journey.personalized_parenting", default: "Parenting with patience")
        }
        if lowercased.contains("patien") || lowercased.contains("anger") || lowercased.contains("react") {
            return L10n.string("create_journey.personalized_patience", default: "Practicing patience today")
        }
        if lowercased.contains("grief") || lowercased.contains("heal") || lowercased.contains("hurt") || lowercased.contains("pain") {
            return L10n.string("create_journey.personalized_healing", default: "Healing with God’s help")
        }

        return nil
    }

    private func rotatedGenericStarterSuggestions() -> [String] {
        rotated([
            L10n.string("create_journey.starter_1", default: "Trusting God with my anxiety"),
            L10n.string("create_journey.starter_2", default: "Growing consistency in prayer"),
            L10n.string("create_journey.starter_3", default: "Healing in a relationship"),
            L10n.string("create_journey.starter_4", default: "Wisdom for a hard decision"),
            L10n.string("create_journey.starter_5", default: "Becoming more patient"),
            L10n.string("create_journey.starter_6", default: "Finding peace at work"),
            L10n.string("create_journey.starter_7", default: "Forgiving someone who hurt me"),
            L10n.string("create_journey.starter_8", default: "Serving my family with love")
        ], seed: suggestionSeed ^ 0x5f3759df)
    }

    private func interleave(primary: [String], secondary: [String]) -> [String] {
        var result: [String] = []
        let maxCount = max(primary.count, secondary.count)
        for index in 0..<maxCount {
            if index < primary.count {
                result.append(primary[index])
            }
            if index < secondary.count {
                result.append(secondary[index])
            }
        }
        return result
    }

    private func rotated(_ values: [String], seed: Int) -> [String] {
        guard !values.isEmpty else { return [] }
        let positiveSeed = seed == Int.min ? 0 : abs(seed)
        let offset = positiveSeed % values.count
        return Array(values[offset...]) + Array(values[..<offset])
    }

    private func uniqueNonEmpty(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for value in values {
            let cleaned = value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            guard !cleaned.isEmpty else { continue }
            let key = cleaned.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(cleaned)
        }
        return result
    }

    private func inferredReminderWindow() -> String {
        guard let firstEnabled = reminderRows.first(where: { $0.isEnabled }) ?? reminderRows.first else {
            return "Morning"
        }
        switch firstEnabled.hour {
        case 0..<12:
            return "Morning"
        case 12..<17:
            return "Afternoon"
        default:
            return "Evening"
        }
    }
}

struct JourneyDetailView: View {
    let journey: PrayerJourney
    @Environment(\.modelContext) private var modelContext
    @State private var isRenaming = false
    @State private var newTitle = ""

    var body: some View {
        ZStack {
            WWColor.white.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(journey.title)
                            .font(WWTypography.heading(32))
                            .foregroundStyle(WWColor.nearBlack)
                            .padding(.top, 24)
                            
                        Text(journey.category.uppercased())
                            .font(WWTypography.caption(12).weight(.heavy))
                            .foregroundStyle(WWColor.growGreen)
                            .tracking(2.0)
                    }
                    .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 24) {
                        Text(L10n.string("journal.recent_entries", default: "Recent Entries"))
                            .font(WWTypography.heading(22))
                            .foregroundStyle(WWColor.nearBlack)
                            .padding(.horizontal, 24)

                        if journey.entries.isEmpty {
                            Text(L10n.string("journal.no_entries", default: "No entries yet."))
                                .foregroundStyle(WWColor.muted)
                                .padding(.horizontal, 24)
                        } else {
                            VStack(spacing: 16) {
                                ForEach(journey.entries.sorted(by: { $0.createdAt > $1.createdAt })) { entry in
                                    NavigationLink(destination: HistoricalTendDetailView(entry: entry)) {
                                        VStack(alignment: .leading, spacing: 16) {
                                            HStack {
                                                Text(entry.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                                                    .font(WWTypography.caption(12).weight(.bold))
                                                    .foregroundStyle(WWColor.growGreen)
                                                Spacer()
                                            }
                                            
                                            Text(entry.prompt)
                                                .font(WWTypography.body(16))
                                                .foregroundStyle(WWColor.nearBlack)
                                                .lineSpacing(4)
                                                .multilineTextAlignment(.leading)
                                                
                                            if !entry.actionStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                                Text(
                                                    String(
                                                        format: L10n.string("journal.step_prefix", default: "Step: %@"),
                                                        entry.actionStep
                                                    )
                                                )
                                                    .font(WWTypography.caption(14).weight(.medium))
                                                    .foregroundStyle(WWColor.muted)
                                                    .padding(12)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .background(WWColor.contrastCard)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                            }
                                        }
                                        .padding(20)
                                        .background(WWColor.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 24)
                                }
                            }
                        }
                    }
                    
                    Spacer().frame(height: 136)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 116)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newTitle = journey.title
                    isRenaming = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(WWColor.muted)
                }
            }
        }
        .alert(L10n.string("journal.rename.title", default: "Rename Journey"), isPresented: $isRenaming) {
            TextField(L10n.string("journal.rename.placeholder", default: "New title"), text: $newTitle)
            Button(L10n.string("common.cancel", default: "Cancel"), role: .cancel) {}
            Button(L10n.string("journal.rename.save", default: "Save")) {
                let formatted = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !formatted.isEmpty {
                    journey.title = formatted
                    try? modelContext.save()
                }
            }
        }
    }
}

struct HistoricalTendDetailView: View {
    let entry: PrayerEntry
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue: String = AppLanguage.system.rawValue
    @Query private var packages: [DailyJourneyPackageRecord]
    
    init(entry: PrayerEntry) {
        self.entry = entry
        let entryID = entry.id
        self._packages = Query(filter: #Predicate<DailyJourneyPackageRecord> { $0.linkedEntryID == entryID })
    }

    private var selectedLocale: Locale {
        let selectedLanguage = AppLanguage.parseStoredLanguage(appLanguageRawValue)
        return AppLanguage.resolvedLocale(for: selectedLanguage)
    }

    private var entryDateTitle: String {
        entry.createdAt.formatted(
            Date.FormatStyle.dateTime
                .month(.wide)
                .day()
                .year()
                .locale(selectedLocale)
        )
    }
    
    var body: some View {
        ZStack {
            (colorScheme == .dark ? WWColor.surface : Color.white).ignoresSafeArea()
            let package = packages.first
            
            ScrollView {
                VStack(spacing: 32) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(L10n.string("REFLECT", default: "REFLECT"))
                            .font(WWTypography.caption(14).weight(.heavy))
                            .foregroundStyle(WWColor.muted)
                            .tracking(2.0)

                        Text(
                            package?.reflectionThought
                                ?? L10n.string(
                                    "journal.detail.reflection_fallback",
                                    default: "Continue stepping faithfully."
                                )
                        )
                            .font(WWTypography.heading(22))
                            .foregroundStyle(WWColor.nearBlack)
                            .lineSpacing(4)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 32)

                    VStack(spacing: 24) {
                        Text(entry.scriptureText)
                            .font(WWTypography.heading(24))
                            .foregroundStyle(WWColor.nearBlack)
                            .lineSpacing(6)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                        
                        Text("— " + entry.scriptureReference)
                            .font(WWTypography.body(16).weight(.bold))
                            .foregroundStyle(WWColor.growGreen)
                    }
                    .padding(.vertical, 32)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(WWColor.contrastCard)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(WWColor.nearBlack.opacity(0.08), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 14) {
                        Text(L10n.string("PRAY", default: "PRAY"))
                            .font(WWTypography.caption(14).weight(.heavy))
                            .foregroundStyle(WWColor.muted)
                            .tracking(2.0)

                        Text(package?.prayer ?? entry.prompt)
                            .font(WWTypography.body(18))
                            .foregroundStyle(WWColor.nearBlack)
                            .lineSpacing(6)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 20) {
                        Text(L10n.string("TEND", default: "TEND"))
                            .font(WWTypography.caption(14).weight(.heavy))
                            .foregroundStyle(WWColor.muted)
                            .tracking(2.0)

                        Text(package?.smallStepQuestion ?? DailyJourneyPackageValidation.defaultSmallStepQuestion)
                            .font(WWTypography.heading(22))
                            .foregroundStyle(WWColor.nearBlack)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(
                            entry.actionStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? L10n.string("journal.detail.step_skipped", default: "(Step skipped)")
                                : entry.actionStep
                        )
                            .font(WWTypography.body(18))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(WWColor.contrastCard)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(WWColor.nearBlack.opacity(0.08), lineWidth: 1))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 124)
                }
            }
        }
        .navigationTitle(entryDateTitle)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 116)
        }
    }
}
