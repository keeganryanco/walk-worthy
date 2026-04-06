import SwiftUI
import SwiftData

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var connectivityService: ConnectivityService
    
    let isPremium: Bool
    let onRequirePaywall: (PaywallTriggerReason) -> Void
    
    @Query(sort: \PrayerJourney.createdAt, order: .reverse)
    private var allJourneys: [PrayerJourney]
    
    @State private var isCreating = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                WWColor.white.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
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

                        let active = allJourneys.filter { !$0.isArchived }
                        let memories = allJourneys.filter { $0.isArchived }

                        if !active.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text(L10n.string("journal.active_journeys", default: "ACTIVE JOURNEYS"))
                                    .font(WWTypography.caption(12).weight(.heavy))
                                    .foregroundStyle(WWColor.muted)
                                    .tracking(2.0)
                                    .padding(.horizontal, 24)
                                ForEach(active) { journey in
                                    NavigationLink(destination: JourneyDetailView(journey: journey)) {
                                        journeyCard(journey)
                                    }
                                }
                            }
                        }

                        if !memories.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text(L10n.string("journal.memories", default: "MEMORIES"))
                                    .font(WWTypography.caption(12).weight(.heavy))
                                    .foregroundStyle(WWColor.muted)
                                    .tracking(2.0)
                                    .padding(.horizontal, 24)

                                ForEach(memories) { journey in
                                    NavigationLink(destination: JourneyDetailView(journey: journey)) {
                                        journeyCard(journey)
                                    }
                                }
                            }
                            .padding(.top, 24)
                        }

                        Spacer().frame(height: 136)
                    }
                }
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 116)
            }
            .sheet(isPresented: $isCreating) {
                CreateJourneyView(isPremium: isPremium, onRequirePaywall: onRequirePaywall)
            }
        }
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
    
    @Query(filter: #Predicate<PrayerJourney> { !$0.isArchived })
    private var activeJourneys: [PrayerJourney]
    
    @Query(sort: \AppSettings.lastSessionDate, order: .reverse)
    private var settingsRows: [AppSettings]

    @Query(sort: \OnboardingProfile.createdAt, order: .reverse)
    private var profiles: [OnboardingProfile]

    @Query(sort: \ReminderSchedule.sortOrder)
    private var reminderRows: [ReminderSchedule]
    
    @State private var prayerIntentText = ""
    @State private var goalIntentText = ""
    @State private var alertMessage: String?
    @State private var isSubmitting = false
    @FocusState private var focusedField: InputField?

    private let bootstrapProvider = BackendJourneyBootstrapProvider()

    private enum InputField {
        case prayer
        case goal
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                WWColor.white.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.string("create_journey.prayer_title", default: "What do you want to pray about right now?"))
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

                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.string("create_journey.goal_title", default: "What goal are you moving toward with God right now?"))
                                .font(WWTypography.heading(18))
                                .foregroundStyle(WWColor.nearBlack)
                            TextField(L10n.string("create_journey.goal_placeholder", default: "Describe your goal..."), text: newlineDismissBinding(for: $goalIntentText), axis: .vertical)
                                .focused($focusedField, equals: .goal)
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
                        .padding(.bottom, 24)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle(L10n.string("create_journey.title", default: "New Journey"))
            .navigationBarTitleDisplayMode(.inline)
            .onTapGesture {
                focusedField = nil
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel", default: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("create_journey.create_button", default: "Create")) {
                        createJourneyFromIntents()
                    }
                    .disabled(
                        isSubmitting ||
                        prayerIntentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        goalIntentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        let goal = goalIntentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = profiles.first?.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? (profiles.first?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Friend")
            : "Friend"
        let reminderWindow = inferredReminderWindow()

        guard !prayer.isEmpty, !goal.isEmpty else { return }

        isSubmitting = true
        Task {
            do {
                let payload = try await bootstrapProvider.bootstrap(
                    name: displayName,
                    prayerIntentText: prayer,
                    goalIntentText: goal,
                    reminderWindow: reminderWindow
                )

                await MainActor.run {
                    let initialPackage = DailyJourneyPackageValidation.validated(payload.initialPackage)
                    let theme = JourneyThemeKey(rawValue: payload.themeKey.lowercased()) ?? .basic

                    let journey = PrayerJourney(
                        title: payload.journeyTitle,
                        category: payload.journeyCategory,
                        themeKey: theme,
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

                    let dayKey = JourneyContentService.dayKey(for: .now)
                    let record = DailyJourneyPackageRecord(
                        journeyID: journey.id,
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
                        journeyID: journey.id,
                        summary: payload.initialMemory.summary,
                        winsSummary: payload.initialMemory.winsSummary,
                        blockersSummary: payload.initialMemory.blockersSummary,
                        preferredTone: payload.initialMemory.preferredTone
                    )
                    modelContext.insert(snapshot)

                    JourneyProgressService.logEvent(
                        journeyID: journey.id,
                        type: .packageGenerated,
                        notes: "Initial package seeded from create journey flow.",
                        modelContext: modelContext
                    )

                    try? modelContext.save()
                    WidgetSyncService.publishFromModelContext(modelContext)
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
                        Text("Recent Entries")
                            .font(WWTypography.heading(22))
                            .foregroundStyle(WWColor.nearBlack)
                            .padding(.horizontal, 24)

                        if journey.entries.isEmpty {
                            Text("No entries yet.")
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
                                                Text("Step: \(entry.actionStep)")
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
        .alert("Rename Journey", isPresented: $isRenaming) {
            TextField("New title", text: $newTitle)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
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
    @Query private var packages: [DailyJourneyPackageRecord]
    
    init(entry: PrayerEntry) {
        self.entry = entry
        let entryID = entry.id
        self._packages = Query(filter: #Predicate<DailyJourneyPackageRecord> { $0.linkedEntryID == entryID })
    }
    
    var body: some View {
        ZStack {
            (colorScheme == .dark ? WWColor.surface : Color.white).ignoresSafeArea()
            let package = packages.first
            
            ScrollView {
                VStack(spacing: 32) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("REFLECT")
                            .font(WWTypography.caption(14).weight(.heavy))
                            .foregroundStyle(WWColor.muted)
                            .tracking(2.0)

                        Text(package?.reflectionThought ?? "Continue stepping faithfully.")
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
                        Text("PRAY")
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
                        Text("TEND")
                            .font(WWTypography.caption(14).weight(.heavy))
                            .foregroundStyle(WWColor.muted)
                            .tracking(2.0)

                        Text(package?.smallStepQuestion ?? DailyJourneyPackageValidation.defaultSmallStepQuestion)
                            .font(WWTypography.heading(22))
                            .foregroundStyle(WWColor.nearBlack)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(entry.actionStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "(Step skipped)" : entry.actionStep)
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
        .navigationTitle(entry.createdAt.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 116)
        }
    }
}
