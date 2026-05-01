import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var connectivityService: ConnectivityService

    let profile: OnboardingProfile
    let isPremium: Bool
    let onRequirePaywall: (PaywallTriggerReason) -> Void

    @Query(filter: #Predicate<PrayerJourney> { !$0.isArchived }, sort: \PrayerJourney.createdAt, order: .reverse)
    private var activeJourneys: [PrayerJourney]
    
    @Query(sort: \PrayerEntry.createdAt, order: .reverse)
    private var allEntries: [PrayerEntry]
    
    @Query(sort: \JourneyMemorySnapshot.updatedAt, order: .reverse)
    private var memorySnapshots: [JourneyMemorySnapshot]

    private let contentService = JourneyContentService()
    
    @State private var selectedJourneyID: UUID?
    @State private var suppressHomePageIndicator = false
    @State private var reigniteRouteJourneyID: UUID?
    @State private var isJourneySwitcherPresented = false
    @State private var isCreatingJourney = false
    @AppStorage(AppConstants.DeepLink.pendingJourneyStorageKey) private var pendingJourneyIDRaw = ""
    @AppStorage(AppConstants.DeepLink.pendingActionStorageKey) private var pendingActionRaw = ""

    var body: some View {
        NavigationStack {
            ZStack {
                (activeJourneys.isEmpty ? WWColor.white : WWColor.contrastCard)
                    .ignoresSafeArea()
                
                if activeJourneys.isEmpty {
                    emptyState
                } else {
                    TabView(selection: $selectedJourneyID) {
                        ForEach(activeJourneys) { journey in
                            JourneyGrowthPage(
                                journey: journey,
                                entries: entries(for: journey.id),
                                profile: profile,
                                memory: memory(for: journey.id),
                                contentService: contentService,
                                shouldShowReignitePrompt: reigniteRouteJourneyID == journey.id && pendingActionRaw == AppConstants.DeepLink.reigniteActionValue,
                                onConsumeReignitePrompt: {
                                    if reigniteRouteJourneyID == journey.id {
                                        pendingJourneyIDRaw = ""
                                        pendingActionRaw = ""
                                        reigniteRouteJourneyID = nil
                                    }
                                },
                                suppressHomePageIndicator: $suppressHomePageIndicator
                            )
                            .tag(journey.id as UUID?)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .ignoresSafeArea()
                }
            }
            .overlay(alignment: .topTrailing) {
                if !activeJourneys.isEmpty {
                    Button {
                        isJourneySwitcherPresented = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text(L10n.string("home.switcher.button", default: "Garden"))
                                .font(WWTypography.caption(12).weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(WWColor.nearBlack.opacity(0.58))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 20)
                    .padding(.trailing, 20)
                    .accessibilityLabel(L10n.string("home.switcher.button", default: "Garden"))
                    .accessibilityHint(
                        L10n.string(
                            "home.switcher.accessibility_hint",
                            default: "Open your journeys and plant a new one."
                        )
                    )
                }
            }
            .overlay(alignment: .bottom) {
                if !activeJourneys.isEmpty && !suppressHomePageIndicator {
                    homePageIndicator
                        .padding(.bottom, 108)
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                if selectedJourneyID == nil {
                    selectedJourneyID = activeJourneys.first?.id
                }
                applyPendingRouteIfNeeded()
            }
            .onChange(of: activeJourneys.map(\.id)) { _, ids in
                guard !ids.isEmpty else {
                    selectedJourneyID = nil
                    return
                }
                if let selectedJourneyID,
                   ids.contains(selectedJourneyID) {
                    return
                }
                selectedJourneyID = ids.first
                applyPendingRouteIfNeeded()
            }
            .onChange(of: pendingJourneyIDRaw) { _, _ in
                applyPendingRouteIfNeeded()
            }
            .onChange(of: pendingActionRaw) { _, _ in
                applyPendingRouteIfNeeded()
            }
            .navigationBarHidden(true)
            .accessibilityIdentifier("HomeView")
            .sheet(isPresented: $isJourneySwitcherPresented) {
                JourneySwitcherSheet(
                    journeys: activeJourneys,
                    selectedJourneyID: selectedJourneyID,
                    onSelectJourney: { selectedID in
                        selectedJourneyID = selectedID
                    },
                    onPlantJourney: {
                        isCreatingJourney = true
                    }
                )
            }
            .sheet(isPresented: $isCreatingJourney) {
                CreateJourneyView(isPremium: isPremium, onRequirePaywall: onRequirePaywall)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 24) {
            Text(L10n.string("home.empty.title", default: "Your garden is ready."))
                .font(WWTypography.section(28))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)

            Text(L10n.string("home.empty.subtitle", default: "Create your first prayer journey to begin growing."))
                .font(WWTypography.body(18))
                .foregroundStyle(WWColor.muted)
                .multilineTextAlignment(.center)

            Button(L10n.string("home.switcher.plant_new", default: "Plant New Journey")) {
                isCreatingJourney = true
            }
            .buttonStyle(WWPrimaryButtonStyle(background: WWColor.growGreen, foreground: WWColor.nearBlack))
            .padding(.top, 8)
        }
        .padding(32)
    }

    private func memory(for journeyID: UUID) -> JourneyMemorySnapshot? {
        memorySnapshots.first(where: { $0.journeyID == journeyID })
    }

    private func entries(for journeyID: UUID) -> [PrayerEntry] {
        allEntries.filter { $0.journey?.id == journeyID }
    }

    private var pageIDs: [UUID] {
        activeJourneys.map(\.id)
    }

    private var selectedPageIndex: Int {
        guard let selectedJourneyID else { return 0 }
        return pageIDs.firstIndex(of: selectedJourneyID) ?? 0
    }

    private var homePageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(Array(pageIDs.enumerated()), id: \.offset) { index, _ in
                Circle()
                    .fill(colorScheme == .dark ? Color.white : WWColor.nearBlack)
                    .frame(width: index == selectedPageIndex ? 8 : 6, height: index == selectedPageIndex ? 8 : 6)
                    .opacity(index == selectedPageIndex ? 0.9 : (colorScheme == .dark ? 0.38 : 0.25))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(WWColor.nearBlack.opacity(colorScheme == .dark ? 0.22 : 0.08))
        )
        .accessibilityHidden(true)
    }

    private func applyPendingRouteIfNeeded() {
        guard !pendingJourneyIDRaw.isEmpty, let journeyID = UUID(uuidString: pendingJourneyIDRaw) else { return }
        guard activeJourneys.contains(where: { $0.id == journeyID }) else { return }

        selectedJourneyID = journeyID
        if pendingActionRaw == AppConstants.DeepLink.reigniteActionValue {
            reigniteRouteJourneyID = journeyID
        } else {
            reigniteRouteJourneyID = nil
            pendingJourneyIDRaw = ""
            pendingActionRaw = ""
        }
    }
}

private struct JourneySwitcherSheet: View {
    @Environment(\.dismiss) private var dismiss
    let journeys: [PrayerJourney]
    let selectedJourneyID: UUID?
    let onSelectJourney: (UUID) -> Void
    let onPlantJourney: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(journeys) { journey in
                        Button {
                            onSelectJourney(journey.id)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(WWColor.contrastCard)
                                        .frame(width: 44, height: 44)

                                    if let image = plantImage(for: journey) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 34, height: 34)
                                            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                                    } else {
                                        Text(stageEmoji(for: effectiveCompletedTends(for: journey)))
                                            .font(.system(size: 20))
                                    }
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(journey.title)
                                        .font(WWTypography.body(16).weight(.semibold))
                                        .foregroundStyle(WWColor.nearBlack)
                                        .lineLimit(1)
                                    Text(journey.category.uppercased())
                                        .font(WWTypography.caption(10).weight(.heavy))
                                        .tracking(1.0)
                                        .foregroundStyle(WWColor.muted)
                                }
                                Spacer()
                                if selectedJourneyID == journey.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(WWColor.growGreen)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(L10n.string("home.switcher.section", default: "ACTIVE JOURNEYS"))
                }

                Section {
                    Button {
                        dismiss()
                        DispatchQueue.main.async {
                            onPlantJourney()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(WWColor.growGreen)
                            Text(L10n.string("home.switcher.plant_new", default: "Plant New Journey"))
                                .font(WWTypography.body(16).weight(.semibold))
                                .foregroundStyle(WWColor.nearBlack)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(L10n.string("home.switcher.title", default: "Your Garden"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.close", default: "Close")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func effectiveCompletedTends(for journey: PrayerJourney) -> Int {
        let stored = journey.completedTends
        return max(stored, 0)
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

    private func plantImage(for journey: PrayerJourney) -> UIImage? {
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

        let candidates = [
            desired,
            "Plants/\(desired)",
            fallback,
            "Plants/\(fallback)",
            legacyDesired,
            "Plants/\(legacyDesired)",
            legacyFallback,
            "Plants/\(legacyFallback)"
        ]
        for name in candidates {
            if let image = UIImage(named: name) {
                return image
            }
        }
        return nil
    }
}

struct JourneyGrowthPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var connectivityService: ConnectivityService
    @AppStorage("homeOverlayActive") private var homeOverlayActive = false
    
    let journey: PrayerJourney
    let entries: [PrayerEntry]
    let profile: OnboardingProfile
    let memory: JourneyMemorySnapshot?
    let contentService: JourneyContentService
    let shouldShowReignitePrompt: Bool
    let onConsumeReignitePrompt: () -> Void
    @Binding var suppressHomePageIndicator: Bool
    private let analytics: AnalyticsTracking = AnalyticsServiceFactory.makeDefault()
    
    @State private var isGenerating = false
    @State private var showTendingSheet = false
    @State private var showJournalEntrySheet = false
    @State private var alertMessage: String?
    
    @AppStorage("homeBackgroundTheme") private var backgroundTheme: HomeBackgroundTheme = .morningGarden
    
    // Animation States
    @State private var justWatered = false
    @State private var orbOffset: CGFloat = 150
    @State private var orbOpacity: Double = 0.0
    @State private var orbScale: CGFloat = 1.0
    
    // Evolution States
    @State private var isEvolving = false
    @State private var evolutionStep = 0
    @State private var shouldShowStreakAfterEvolution = false

    // New states for streak overlay
    @State private var showStreakOverlay = false
    @State private var pendingCompletionCelebration: TendCompletionCelebration?
    @State private var showReigniteOverlay = false
    @State private var showReigniteCelebration = false
    @State private var isBottomSheetExpanded = false
    @GestureState private var bottomSheetDragOffset: CGFloat = 0

    private var insetCardBackground: Color { WWColor.contrastCard }
    private var bottomSheetBackground: Color { colorScheme == .dark ? WWColor.contrastCard : .white }
    private var insetCardStroke: Color { WWColor.nearBlack.opacity(colorScheme == .dark ? 0.12 : 0.08) }
    private var streakCardBackground: Color { colorScheme == .dark ? insetCardBackground : .white }
    
    private var todaysEntry: PrayerEntry? {
        let calendar = Calendar.current
        let referenceDate = TendingTestingClock.currentDate
        return entries.first(where: { calendar.isDate($0.createdAt, inSameDayAs: referenceDate) })
    }
    
    private static let tendsPerStage = 3
    private static let stagesPerCycle = 5
    private static let tendsPerCycle = tendsPerStage * stagesPerCycle

    private var completedCount: Int {
        let stored = journey.completedTends
        if stored > 0 {
            return stored
        }
        return entries.filter { $0.completedAt != nil }.count
    }
    
    private func stage(for count: Int) -> Int {
        guard count > 0 else { return 1 }
        let indexInCycle = count % Self.tendsPerCycle
        return min(Self.stagesPerCycle, max(1, (indexInCycle / Self.tendsPerStage) + 1))
    }
    
    private var plantStage: Int {
        stage(for: completedCount)
    }

    private var currentCycleCount: Int {
        max(journey.cycleCount, completedCount / Self.tendsPerCycle)
    }

    private var currentStreakCount: Int {
        JourneyEngagementService.effectiveStreakCount(
            for: journey,
            entries: entries,
            now: TendingTestingClock.currentDate
        )
    }

    private var reigniteEligibility: ReigniteEligibility {
        JourneyEngagementService.reigniteEligibility(
            for: journey,
            entries: entries,
            now: TendingTestingClock.currentDate
        )
    }

    private var shouldOfferInAppReigniteOption: Bool {
        JourneyEngagementService.shouldOfferInAppReigniteOption(
            for: journey,
            entries: entries,
            now: TendingTestingClock.currentDate
        )
    }

    private var hydrationStage: Int {
        journey.hydrationStage
    }

    private var themeSuffix: String {
        if journey.themeKey != .basic {
            return journey.themeKey.rawValue
        }

        let cat = journey.category.lowercased()
        
        switch cat {
        case _ where cat.contains("peace") || cat.contains("anxiet") || cat.contains("worry") || cat.contains("calm") || cat.contains("fear"):
            return "peace"
        case _ where cat.contains("resilien") || cat.contains("strength") || cat.contains("hardship") || cat.contains("trial") || cat.contains("pain"):
            return "resilience"
        case _ where cat.contains("patien") || cat.contains("consisten") || cat.contains("wait") || cat.contains("time"):
            return "patience"
        case _ where cat.contains("faith") || cat.contains("trust") || cat.contains("doubt") || cat.contains("belief"):
            return "faith"
        case _ where cat.contains("joy") || cat.contains("celebrat") || cat.contains("happi") || cat.contains("praise") || cat.contains("gratitude"):
            return "joy"
        case _ where cat.contains("wisdom") || cat.contains("clarity") || cat.contains("decision") || cat.contains("guidance") || cat.contains("direction"):
            return "wisdom"
        case _ where cat.contains("heal") || cat.contains("health") || cat.contains("sick") || cat.contains("recover") || cat.contains("grief"):
            return "healing"
        case _ where cat.contains("disciplin") || cat.contains("focus") || cat.contains("habit") || cat.contains("sin") || cat.contains("tempt"):
            return "discipline"
        case _ where cat.contains("communit") || cat.contains("fellowship") || cat.contains("marriage") || cat.contains("relationship") || cat.contains("family") || cat.contains("friend"):
            return "community"
        default:
            return "base"
        }
    }

    private var todaysPackageRecord: DailyJourneyPackageRecord? {
        let dayKey = JourneyContentService.dayKey(for: TendingTestingClock.currentDate)
        let journeyID = journey.id
        let entryID = todaysEntry?.id
        let descriptor = FetchDescriptor<DailyJourneyPackageRecord>(
            predicate: #Predicate {
                $0.journeyID == journeyID && ($0.dayKey == dayKey || $0.linkedEntryID == entryID)
            }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    private var plantImageName: String {
        "growth_stage_\(plantStage)_\(themeSuffix)"
    }

    private var fallbackPlantImageName: String {
        "growth_stage_\(plantStage)_basic"
    }

    private var availableThemeSuffix: String {
        switch themeSuffix {
        case "basic", "community", "discipline", "faith", "healing", "joy", "patience", "peace", "resilience", "wisdom":
            return themeSuffix
        default:
            // Keep future theme suffixes in logic, but map unresolved themes to current shipped assets.
            return "basic"
        }
    }

    private var normalizedPlantStage: Int {
        min(max(plantStage, 1), 5)
    }

    @available(iOS 17.0, *)
    private var resolvedPlantImageResource: ImageResource {
        switch (normalizedPlantStage, availableThemeSuffix) {
        case (1, "basic"): return .growthStage1SeedBasic
        case (1, "community"): return .growthStage1SeedCommunity
        case (1, "discipline"): return .growthStage1SeedDiscipline
        case (1, "faith"): return .growthStage1SeedFaith
        case (1, "healing"): return .growthStage1SeedHealing
        case (1, "joy"): return .growthStage1SeedJoy
        case (1, "patience"): return .growthStage1SeedPatience
        case (1, "peace"): return .growthStage1SeedPeace
        case (1, "resilience"): return .growthStage1SeedResilience
        case (1, "wisdom"): return .growthStage1SeedWisdom

        case (2, "basic"): return .growthStage2SproutBasic
        case (2, "community"): return .growthStage2SproutCommunity
        case (2, "discipline"): return .growthStage2SproutDiscipline
        case (2, "faith"): return .growthStage2SproutFaith
        case (2, "healing"): return .growthStage2SproutHealing
        case (2, "joy"): return .growthStage2SproutJoy
        case (2, "patience"): return .growthStage2SproutPatience
        case (2, "peace"): return .growthStage2SproutPeace
        case (2, "resilience"): return .growthStage2SproutResilience
        case (2, "wisdom"): return .growthStage2SproutWisdom

        case (3, "basic"): return .growthStage3YoungBasic
        case (3, "community"): return .growthStage3YoungCommunity
        case (3, "discipline"): return .growthStage3YoungDiscipline
        case (3, "faith"): return .growthStage3YoungFaith
        case (3, "healing"): return .growthStage3YoungHealing
        case (3, "joy"): return .growthStage3YoungJoy
        case (3, "patience"): return .growthStage3YoungPatience
        case (3, "peace"): return .growthStage3YoungPeace
        case (3, "resilience"): return .growthStage3YoungResilience
        case (3, "wisdom"): return .growthStage3YoungWisdom

        case (4, "basic"): return .growthStage4MatureBasic
        case (4, "community"): return .growthStage4MatureCommunity
        case (4, "discipline"): return .growthStage4MatureDiscipline
        case (4, "faith"): return .growthStage4MatureFaith
        case (4, "healing"): return .growthStage4MatureHealing
        case (4, "joy"): return .growthStage4MatureJoy
        case (4, "patience"): return .growthStage4MaturePatience
        case (4, "peace"): return .growthStage4MaturePeace
        case (4, "resilience"): return .growthStage4MatureResilience
        case (4, "wisdom"): return .growthStage4MatureWisdom

        case (5, "basic"): return .growthStage5FullBloomBasic
        case (5, "community"): return .growthStage5FullBloomCommunity
        case (5, "discipline"): return .growthStage5FullBloomDiscipline
        case (5, "faith"): return .growthStage5FullBloomFaith
        case (5, "healing"): return .growthStage5FullBloomHealing
        case (5, "joy"): return .growthStage5FullBloomJoy
        case (5, "patience"): return .growthStage5FullBloomPatience
        case (5, "peace"): return .growthStage5FullBloomPeace
        case (5, "resilience"): return .growthStage5FullBloomResilience
        case (5, "wisdom"): return .growthStage5FullBloomWisdom

        default:
            // Defensive default: always show a valid shipped asset.
            return .growthStage1SeedBasic
        }
    }

    private var resolvedPlantImageName: String? {
        let candidates = plantImageCandidates

        for candidate in candidates {
            if resolveUIImage(named: candidate) != nil {
                return candidate
            }
        }

        return nil
    }

    private var plantImageCandidates: [String] {
        [
            plantImageName,
            "Plants/\(plantImageName)",
            fallbackPlantImageName,
            "Plants/\(fallbackPlantImageName)"
        ]
    }

    private func resolveUIImage(named name: String) -> UIImage? {
        if let image = UIImage(named: name) {
            return image
        }

        if let image = UIImage(named: name, in: .main, compatibleWith: nil) {
            return image
        }

        if let image = UIImage(named: name, in: Bundle(for: PlantAssetBundleLocator.self), compatibleWith: nil) {
            return image
        }

        return nil
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                let effectiveTopInset = max(proxy.safeAreaInsets.top, 64)
                let collapsedTop = proxy.size.height * 0.50
                let expandedTop = max(effectiveTopInset + 16, proxy.size.height * 0.14)
                let currentSheetTop = isBottomSheetExpanded ? expandedTop : collapsedTop
                let interactiveDragOffset = isBottomSheetExpanded ? max(0, bottomSheetDragOffset) : min(0, bottomSheetDragOffset)
                let topVisualHeight = proxy.size.height * 0.58 + effectiveTopInset
                let topVisualBleed = effectiveTopInset + 32
                let homePlantMaxHeight = proxy.size.height * 0.33
                // Keep plant fully above the card on all devices with a strict safety gap,
                // then add extra visual lift so it sits higher in the available space.
                let cardAnchorTop = max(currentSheetTop, collapsedTop)
                let cardSafetyGap: CGFloat = 72
                let preferredVisualLift = min(max(proxy.size.height * 0.055, 48), 88)
                let minimumLiftForCardSafety = topVisualHeight - (cardAnchorTop - cardSafetyGap)
                let rawHomePlantLift = minimumLiftForCardSafety + preferredVisualLift
                let maxLiftBeforeIsland = topVisualHeight - (effectiveTopInset + 96 + homePlantMaxHeight)
                let homePlantLift = max(
                    minimumLiftForCardSafety,
                    max(18, min(rawHomePlantLift, maxLiftBeforeIsland))
                )

                bottomSheetBackground
                    .ignoresSafeArea()

                // Top Plant Visual
                ZStack {
                    // The Nature Background Theme
                    if let assetName = backgroundTheme.assetName {
                        Image(assetName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: topVisualHeight + 44 + topVisualBleed)
                            .clipped()
                            // A subtle gradient dim on the bottom edge helps the plant pop
                            .overlay(
                                LinearGradient(
                                    colors: [.clear, WWColor.nearBlack.opacity(colorScheme == .dark ? 0.4 : 0.12)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(colorScheme == .dark ? WWColor.darkBackground : WWColor.white)
                            .frame(width: proxy.size.width, height: topVisualHeight + 44 + topVisualBleed)
                            .overlay(
                                LinearGradient(
                                    colors: [.clear, WWColor.nearBlack.opacity(colorScheme == .dark ? 0.4 : 0.12)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    
                    // Plant Visual Area
                    VStack {
                        Spacer()
                        plantImageView(
                            proxy: proxy,
                            maxHeightRatio: 0.33,
                            bottomPadding: 0
                        )
                            .saturation(0.86 + (Double(hydrationStage) * 0.05))
                            .brightness(-0.02 + (Double(hydrationStage) * 0.01))
                            .scaleEffect(justWatered ? 1.05 : 1.0)
                            .shadow(color: .black.opacity(0.4), radius: 20, y: 15)
                            .padding(.bottom, homePlantLift)
                    }
                    
                    // Native Glow Orb Animation
                    if orbOpacity > 0 {
                        Circle()
                            .fill(WWColor.morningGold)
                            .frame(width: 30, height: 30)
                            .shadow(color: WWColor.morningGold.opacity(0.8), radius: 15, x: 0, y: 0)
                            .blur(radius: 2)
                            .scaleEffect(orbScale)
                            .offset(y: orbOffset)
                            .opacity(orbOpacity)
                            .accessibilityHidden(true)
                    }
                }
                .frame(height: topVisualHeight + topVisualBleed)
                .offset(y: -topVisualBleed)
                .ignoresSafeArea(edges: .top)
                .onChange(of: completedCount) { oldCount, newCount in
                    guard !showTendingSheet, pendingCompletionCelebration == nil else { return }
                    if newCount > oldCount {
                        let oldStage = stage(for: oldCount)
                        let newStage = stage(for: newCount)
                        presentCompletionCelebration(didIncreasePlantStage: newStage > oldStage)
                    }
                }
                
                // Bottom sheet: content & actions
                bottomHalf
                    .frame(height: isBottomSheetExpanded ? proxy.size.height * 0.82 : proxy.size.height * 0.50)
                    .offset(y: currentSheetTop + interactiveDragOffset)
                    .contentShape(Rectangle())
                    .simultaneousGesture(bottomSheetDragGesture, including: .all)
                    .animation(.interactiveSpring(response: 0.38, dampingFraction: 0.86, blendDuration: 0.15), value: isBottomSheetExpanded)
                // Pokémon Style Evolution Overlay
                if isEvolving {
                    ZStack {
                        // Dark Vignette
                        LinearGradient(
                            colors: [
                                WWColor.nearBlack.opacity(colorScheme == .dark ? 0.45 : 0.18),
                                WWColor.nearBlack.opacity(colorScheme == .dark ? 0.28 : 0.10)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                            .frame(width: proxy.size.width, height: proxy.size.height + effectiveTopInset + 24)
                            .offset(y: -(effectiveTopInset + 24))
                            .ignoresSafeArea()

                        VStack(spacing: 0) {
                            // Mimic Top Half height for perfect alignment
                            ZStack {
                                VStack {
                                    Spacer()

                                    ZStack {
                                        // Glowing Expanding Halo
                                        if evolutionStep >= 1 {
                                            Circle()
                                                .fill(WWColor.morningGold.opacity(0.4))
                                                .frame(width: proxy.size.width * 0.9, height: proxy.size.width * 0.9)
                                                .blur(radius: 40)
                                                .scaleEffect(evolutionStep == 2 ? 1.2 : 0.8)
                                                .animation(reduceMotion ? nil : .easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: evolutionStep)
                                                .accessibilityHidden(true)
                                        }

                                        // The Silhouette & Reveal
                                        // NOTE: this requires transparent PNG backgrounds to create a true silhouette!
                                        plantImageView(proxy: proxy)
                                            .colorMultiply(evolutionStep >= 3 ? .white : .black)
                                            .brightness(evolutionStep >= 3 ? 0 : -1)
                                            .scaleEffect(evolutionStep >= 3 ? 1.04 : 0.86)
                                            .offset(y: 34)
                                            .overlay {
                                                if evolutionStep == 2 {
                                                    // White flash frame
                                                    plantImageView(proxy: proxy)
                                                        .colorMultiply(.white)
                                                        .brightness(1)
                                                        .transition(.opacity)
                                                }
                                            }
                                            .animation(.spring(response: 0.6, dampingFraction: 0.6), value: evolutionStep)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: proxy.size.height * 0.45)
                                    .padding(.bottom, 32)
                                }
                            }
                            .frame(height: proxy.size.height * 0.5)

                            // Push up the rest
                            Spacer().frame(height: proxy.size.height * 0.5)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(100)
                    .onAppear {
                        runEvolutionSequence()
                    }
                }

                if showStreakOverlay {
                    StreakOverlayView(
                        streakCount: currentStreakCount,
                        onDismiss: { showStreakOverlay = false }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .zIndex(200)
                }

                if showReigniteOverlay {
                    ReigniteOverlayView(
                        streakCount: max(reigniteEligibility.recoverableStreak, currentStreakCount),
                        onReignite: {
                            triggerReignite()
                        },
                        onDismiss: {
                            dismissReigniteOverlay()
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .zIndex(220)
                }

                if showReigniteCelebration {
                    ReigniteCelebrationView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                        .zIndex(210)
                        .transition(.opacity.combined(with: .scale(scale: 1.04)))
                }
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(pageVerticalRevealGesture, including: .all)
        .onChange(of: showStreakOverlay) { _, isVisible in
            suppressHomePageIndicator = isVisible || showReigniteOverlay
            homeOverlayActive = isVisible || isEvolving || showReigniteOverlay || showReigniteCelebration
        }
        .onChange(of: showReigniteOverlay) { _, isVisible in
            suppressHomePageIndicator = isVisible || showStreakOverlay
            homeOverlayActive = isVisible || isEvolving || showStreakOverlay || showReigniteCelebration
        }
        .onChange(of: showReigniteCelebration) { _, isVisible in
            homeOverlayActive = isVisible || isEvolving || showStreakOverlay || showReigniteOverlay
        }
        .onChange(of: isEvolving) { _, isVisible in
            homeOverlayActive = isVisible || showStreakOverlay || showReigniteOverlay || showReigniteCelebration
        }
        .onAppear {
            refreshEngagementState()
            handleNotificationReignitePromptIfNeeded()
        }
        .onChange(of: entries.map(\.id)) { _, _ in
            refreshEngagementState()
            if showReigniteOverlay, !reigniteEligibility.isEligible {
                showReigniteOverlay = false
            }
        }
        .onChange(of: shouldShowReignitePrompt) { _, _ in
            handleNotificationReignitePromptIfNeeded()
        }
        .onDisappear {
            if suppressHomePageIndicator {
                suppressHomePageIndicator = false
            }
            if homeOverlayActive {
                homeOverlayActive = false
            }
        }
        .fullScreenCover(
            isPresented: $showTendingSheet,
            onDismiss: {
                presentPendingCompletionCelebrationIfNeeded()
            }
        ) {
            if let entry = todaysEntry {
                TendingFlowView(
                    journey: journey,
                    entry: entry,
                    entries: entries,
                    profile: profile,
                    package: todaysPackageRecord?.asPackage,
                    onCompleted: { celebration in
                        pendingCompletionCelebration = celebration
                    }
                )
            }
        }
        .sheet(isPresented: $showJournalEntrySheet) {
            if let entry = todaysEntry {
                NavigationStack {
                    HistoricalTendDetailView(entry: entry)
                }
            }
        }
        .alert(L10n.string("home.tend.unavailable_title", default: "Tend Not Ready"), isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button(L10n.string("common.ok", default: "OK"), role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .ignoresSafeArea()
    }
    
    @ViewBuilder
    private var bottomHalf: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Capsule()
                    .fill(WWColor.muted.opacity(0.5))
                    .frame(width: 44, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        setBottomSheetExpanded(!isBottomSheetExpanded)
                    }
                    .accessibilityLabel(
                        isBottomSheetExpanded
                            ? L10n.string("home.sheet.collapse", default: "Collapse journey details")
                            : L10n.string("home.sheet.expand", default: "Expand journey details")
                    )
                    .accessibilityHint(
                        isBottomSheetExpanded
                            ? L10n.string("home.sheet.collapse_hint", default: "Double-tap to collapse the bottom sheet.")
                            : L10n.string("home.sheet.expand_hint", default: "Double-tap to expand the bottom sheet.")
                    )
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction {
                        setBottomSheetExpanded(!isBottomSheetExpanded)
                    }

                // Header
                VStack(spacing: 8) {
                    Text(journey.title)
                        .font(WWTypography.heading(32))
                        .foregroundStyle(WWColor.nearBlack)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    Text(journey.category.uppercased())
                        .font(WWTypography.caption(12).weight(.heavy))
                        .foregroundStyle(WWColor.growGreen)
                        .tracking(2.0)
                }
                .padding(.top, 8)
                
                // Action or Completed State
                if let entry = todaysEntry {
                    if entry.completedAt != nil {
                        Button {
                            showJournalEntrySheet = true
                        } label: {
                            VStack(spacing: 16) {
                                HStack(spacing: 8) {
                                    if let img = resolveUIImage(named: "dew_drop_icon") {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 24, height: 24)
                                    } else {
                                        Image(systemName: "drop.fill")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(WWColor.growGreen)
                                    }
                                    Text(L10n.string("Today's Tend", default: "Today's Tend"))
                                        .font(WWTypography.caption(14).weight(.bold))
                                        .foregroundStyle(WWColor.muted)
                                        .tracking(1.0)
                                }

                                Text(entry.actionStep)
                                    .font(WWTypography.body(16))
                                    .foregroundStyle(WWColor.nearBlack)
                                    .multilineTextAlignment(.center)
                                    .padding(20)
                                    .frame(maxWidth: .infinity)
                                    .background(insetCardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(insetCardStroke, lineWidth: 1)
                                    )

                                scriptureSummaryCard(for: entry)

                                Text(L10n.string("View today's journal entry", default: "View today's journal entry"))
                                    .font(WWTypography.caption(13).weight(.medium))
                                    .foregroundStyle(WWColor.growGreen)
                            }
                            .padding(.horizontal, 32)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(
                            L10n.string(
                                "home.journal.open_entry_hint",
                                default: "Opens today's completed journal entry."
                            )
                        )
                    } else {
                        VStack(spacing: 16) {
                            HStack(spacing: 8) {
                                if let img = resolveUIImage(named: "dew_drop_icon") {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                        .opacity(0.35)
                                } else {
                                    Image(systemName: "drop.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(WWColor.growGreen)
                                        .opacity(0.35)
                                }
                                Text(L10n.string("Today's Tend", default: "Today's Tend"))
                                    .font(WWTypography.caption(14).weight(.bold))
                                    .foregroundStyle(WWColor.muted)
                                    .tracking(1.0)
                            }
                            
                            Button {
                                if todaysPackageRecord == nil {
                                    alertMessage = L10n.string(
                                        "home.tend.package_missing",
                                        default: "Today's Tend is still being prepared. Please try again in a moment."
                                    )
                                } else {
                                    showTendingSheet = true
                                }
                            } label: {
                                Text(
                                    entry.actionStep.isEmpty
                                        ? L10n.string("Tap to open today's step", default: "Tap to open today's step")
                                        : entry.actionStep
                                )
                                    .font(WWTypography.body(16))
                                    .foregroundStyle(WWColor.nearBlack)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                            }
                            .background(insetCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(insetCardStroke, lineWidth: 1)
                            )
                            .padding(.horizontal, 32)
                            .accessibilityLabel(
                                entry.actionStep.isEmpty
                                    ? L10n.string("Open today's step", default: "Open today's step")
                                    : "\(L10n.string("Open today's step", default: "Open today's step")). \(entry.actionStep)"
                            )
                            .accessibilityHint(L10n.string("Open today's tend flow.", default: "Opens today's tend flow."))
                        }
                    }
                } else {
                    Button {
                        Task { await generateEntry() }
                    } label: {
                        if isGenerating {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .tint(WWColor.nearBlack)
                                Text(L10n.string("home.generating.revealing", default: "Revealing..."))
                                    .font(WWTypography.heading(20))
                                    .foregroundStyle(WWColor.nearBlack)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 22)
                        } else {
                            HStack(spacing: 10) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 18, weight: .semibold))
                                Text(L10n.string("Reveal Today's Step", default: "Reveal Today's Step"))
                                    .font(WWTypography.heading(20))
                            }
                            .foregroundStyle(WWColor.nearBlack)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 22)
                        }
                    }
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        WWColor.growGreen.opacity(colorScheme == .dark ? 0.24 : 0.20),
                                        WWColor.morningGold.opacity(colorScheme == .dark ? 0.18 : 0.14)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .overlay(
                        Capsule()
                            .stroke(WWColor.growGreen.opacity(0.45), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 32)
                    .disabled(isGenerating)
                    .opacity(isGenerating ? 0.88 : 1.0)
                    .accessibilityLabel(
                        isGenerating
                            ? L10n.string("home.generating.revealing_accessibility", default: "Revealing today's step")
                            : L10n.string("home.generating.reveal_accessibility", default: "Reveal today's step")
                    )
                    .accessibilityHint(
                        L10n.string(
                            "home.generating.reveal_hint",
                            default: "Generates today's reflection, prayer, and next step."
                        )
                    )
                }

                streakSection
                hydrationSection

                Spacer(minLength: 10)
            }
            .padding(.bottom, 118)
        }
        .contentShape(Rectangle())
        .scrollDisabled(!isBottomSheetExpanded)
        .scrollBounceBehavior(.basedOnSize)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(bottomSheetBackground)
                .shadow(color: .black.opacity(0.2), radius: 40, y: -10)
        )
    }

    private var hydrationStatusLabel: String {
        switch hydrationStage {
        case 3:
            return L10n.string("home.hydration.status.full", default: "Hydrated")
        case 2:
            return L10n.string("home.hydration.status.steady", default: "Steady")
        case 1:
            return L10n.string("home.hydration.status.low", default: "Needs Water")
        default:
            return L10n.string("home.hydration.status.dry", default: "Dry Spell")
        }
    }

    private var orderedWeekDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: TendingTestingClock.currentDate)
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today

        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: monday)
        }
    }

    private var completedDaysInJourney: Set<Date> {
        let calendar = Calendar.current
        return Set(entries.compactMap { entry in
            guard let completedAt = entry.completedAt else { return nil }
            return calendar.startOfDay(for: completedAt)
        })
    }

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.string("Streak", default: "Streak"))
                    .font(WWTypography.caption(13).weight(.heavy))
                    .foregroundStyle(WWColor.muted)
                    .tracking(1.4)

                Spacer()
                if !shouldOfferInAppReigniteOption {
                    Text(
                        String(
                            format: L10n.string(
                                currentStreakCount == 1 ? "home.streak.day_count.single" : "home.streak.day_count.multi",
                                default: currentStreakCount == 1 ? "%d day" : "%d days"
                            ),
                            currentStreakCount
                        )
                    )
                        .font(WWTypography.caption(12).weight(.bold))
                        .foregroundStyle(WWColor.growGreen)
                }
            }

            HStack(spacing: 10) {
                ForEach(Array(orderedWeekDays.enumerated()), id: \.offset) { index, day in
                    let isCompleted = completedDaysInJourney.contains(day)
                    let dayLabel = weekdayLabel(for: index)

                    VStack(spacing: 6) {
                        if let img = resolveUIImage(named: "sun_streak_icon") {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .opacity(isCompleted ? 1.0 : 0.22)
                                .grayscale(isCompleted ? 0.0 : 1.0)
                        } else {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(WWColor.growGreen)
                                .opacity(isCompleted ? 1.0 : 0.22)
                        }

                        Text(dayLabel)
                            .font(WWTypography.caption(10).weight(.semibold))
                            .foregroundStyle(isCompleted ? WWColor.nearBlack : WWColor.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(streakCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(insetCardStroke, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if shouldOfferInAppReigniteOption {
                reigniteCalendarChip
                    .padding(.top, 10)
                    .padding(.trailing, 10)
            }
        }
        .padding(.horizontal, 32)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.string("Streak", default: "Streak"))
        .accessibilityValue(
            String(
                format: L10n.string(
                    currentStreakCount == 1 ? "home.streak.day_count.single" : "home.streak.day_count.multi",
                    default: currentStreakCount == 1 ? "%d day" : "%d days"
                ),
                currentStreakCount
            )
        )
    }

    private var reigniteCalendarChip: some View {
        Button {
            presentReigniteOverlay()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11, weight: .bold))
                Text(L10n.string("home.reignite.cta", default: "Restore"))
                    .font(WWTypography.caption(11).weight(.bold))
            }
            .foregroundStyle(WWColor.growGreen)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(WWColor.growGreen.opacity(colorScheme == .dark ? 0.20 : 0.14))
            )
            .overlay(
                Capsule()
                    .stroke(WWColor.growGreen.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.string("home.reignite.cta", default: "Restore"))
        .accessibilityHint(
            L10n.string("home.reignite.calendar_hint", default: "Restore your previous streak for this journey.")
        )
    }

    private var hydrationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.string("home.hydration.title", default: "Water"))
                    .font(WWTypography.caption(13).weight(.heavy))
                    .foregroundStyle(WWColor.muted)
                    .tracking(1.4)

                Spacer()

                Text(hydrationStatusLabel)
                    .font(WWTypography.caption(12).weight(.bold))
                    .foregroundStyle(WWColor.growGreen)
            }

            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "drop.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(WWColor.growGreen)
                        .opacity(index < hydrationStage ? 1.0 : 0.26)
                        .scaleEffect(index < hydrationStage ? 1.0 : 0.9)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(streakCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(insetCardStroke, lineWidth: 1)
        )
        .padding(.horizontal, 32)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.string("home.hydration.title", default: "Water"))
        .accessibilityValue(hydrationStatusLabel)
    }

    private func weekdayLabel(for index: Int) -> String {
        switch index {
        case 0: return "M"
        case 1: return "T"
        case 2: return "W"
        case 3: return "Th"
        case 4: return "F"
        case 5: return "Sa"
        case 6: return "Su"
        default: return ""
        }
    }

    @ViewBuilder
    private func scriptureSummaryCard(for entry: PrayerEntry) -> some View {
        let scriptureText = entry.scriptureText.trimmingCharacters(in: .whitespacesAndNewlines)
        let scriptureReference = entry.scriptureReference.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasScripture = !scriptureText.isEmpty || !scriptureReference.isEmpty

        if hasScripture {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("TODAY'S SCRIPTURE", default: "TODAY'S SCRIPTURE"))
                    .font(WWTypography.caption(11).weight(.heavy))
                    .foregroundStyle(WWColor.growGreen)
                    .tracking(1.2)

                Text(scriptureText.isEmpty ? scriptureReference : scriptureText)
                    .font(WWTypography.body(14))
                    .foregroundStyle(WWColor.nearBlack)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !scriptureReference.isEmpty {
                    Text("— \(scriptureReference)")
                        .font(WWTypography.caption(12).weight(.semibold))
                        .foregroundStyle(WWColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(WWColor.growGreen.opacity(colorScheme == .dark ? 0.18 : 0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(WWColor.growGreen.opacity(colorScheme == .dark ? 0.34 : 0.24), lineWidth: 1)
            )
        }
    }

    private func dampedSheetTranslation(_ translation: CGFloat) -> CGFloat {
        let constrained = isBottomSheetExpanded ? max(0, translation) : min(0, translation)
        let absolute = abs(constrained)
        let softLimit: CGFloat = 120

        guard absolute > softLimit else { return constrained }

        let overflow = absolute - softLimit
        let resisted = softLimit + (overflow * 0.24)
        return constrained.sign == .minus ? -resisted : resisted
    }

    private var bottomSheetDragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($bottomSheetDragOffset) { value, state, _ in
                // Ignore mostly-horizontal drags so journey page swipes stay smooth.
                guard abs(value.translation.height) > abs(value.translation.width) + 20 else {
                    state = 0
                    return
                }
                state = dampedSheetTranslation(value.translation.height)
            }
            .onEnded { value in
                let translation = value.translation.height
                let predicted = value.predictedEndTranslation.height
                guard abs(translation) > abs(value.translation.width) + 20 else { return }

                let shouldExpand: Bool
                if isBottomSheetExpanded {
                    shouldExpand = !(translation > 56 || predicted > 110)
                } else {
                    shouldExpand = translation < -56 || predicted < -110
                }

                if shouldExpand != isBottomSheetExpanded {
                    withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.86, blendDuration: 0.12)) {
                        isBottomSheetExpanded = shouldExpand
                    }
                }
            }
    }

    private var pageVerticalRevealGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                // Require strongly vertical intent so horizontal journey swipes don't trigger reveal.
                guard abs(vertical) > abs(horizontal) + 42 else { return }

                if vertical < -100 && !isBottomSheetExpanded {
                    setBottomSheetExpanded(true)
                } else if vertical > 120 && isBottomSheetExpanded {
                    setBottomSheetExpanded(false)
                }
            }
    }
    
    private func stageEmoji(for stage: Int) -> String {
        switch stage {
        case 1: return "🌰"
        case 2: return "🌱"
        case 3: return "🌿"
        case 4: return "🪴"
        default: return "🌳"
        }
    }
    
    @ViewBuilder
    private func plantImageView(
        proxy: GeometryProxy,
        maxHeightRatio: CGFloat = 0.40,
        bottomPadding: CGFloat = 48
    ) -> some View {
        if #available(iOS 17.0, *) {
            Image(resolvedPlantImageResource)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: proxy.size.height * maxHeightRatio)
                .padding(.bottom, bottomPadding)
                .accessibilityHidden(true)
        } else if let resolvedPlantImageName, let resolvedUIImage = resolveUIImage(named: resolvedPlantImageName) {
            Image(uiImage: resolvedUIImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: proxy.size.height * maxHeightRatio)
                .padding(.bottom, bottomPadding)
                .accessibilityHidden(true)
        } else {
            // Fallback if asset is missing
            VStack(spacing: 10) {
                Text(stageEmoji(for: plantStage))
                    .font(.system(size: 100))

#if DEBUG
                Text("Plant asset missing")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("themeSuffix=\(themeSuffix), mapped=\(availableThemeSuffix)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(plantImageCandidates.joined(separator: " | "))
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
#endif
            }
            .padding(.bottom, max(bottomPadding, 12))
        }
    }

    private func runEvolutionSequence() {
        if reduceMotion {
            isEvolving = true
            evolutionStep = 3
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isEvolving = false
                evolutionStep = 0
                if shouldShowStreakAfterEvolution {
                    shouldShowStreakAfterEvolution = false
                    withAnimation { showStreakOverlay = true }
                }
            }
            return
        }

        // Step 1: Silhouette pulse starts on appear (evolutionStep = 1)
        // TODO: Play native AudioServicesPlaySystemSound(...) chime here!
        
        // Step 2: Flash white build up
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeIn(duration: 0.15)) {
                evolutionStep = 2 // White flash
            }
            
            // Step 3: Reveal Full Color
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    evolutionStep = 3 // Color reveal & scale bounce
                }
                
                // Step 4: Dismiss Overlay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        isEvolving = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        evolutionStep = 0 // Reset for next time
                        if shouldShowStreakAfterEvolution {
                            shouldShowStreakAfterEvolution = false
                            withAnimation { showStreakOverlay = true }
                        }
                    }
                }
            }
        }
    }

    private func presentPendingCompletionCelebrationIfNeeded() {
        guard let celebration = pendingCompletionCelebration else { return }
        pendingCompletionCelebration = nil
        presentCompletionCelebration(didIncreasePlantStage: celebration.didIncreasePlantStage)
    }

    private func presentCompletionCelebration(didIncreasePlantStage: Bool) {
        showStreakOverlay = false

        if didIncreasePlantStage {
            shouldShowStreakAfterEvolution = true
            withAnimation(reduceMotion ? nil : .easeIn(duration: 0.2)) {
                isEvolving = true
                evolutionStep = 1
            }
            return
        }

        triggerWateringEffect()
        let streakDelay: TimeInterval = reduceMotion ? 0.05 : 0.45
        DispatchQueue.main.asyncAfter(deadline: .now() + streakDelay) {
            withAnimation {
                showStreakOverlay = true
            }
        }
    }

    private func triggerWateringEffect() {
        if reduceMotion {
            orbOpacity = 0.0
            justWatered = false
            return
        }

        orbOffset = 150
        orbOpacity = 1.0
        orbScale = 0.5
        
        // 1. Float up
        withAnimation(.easeOut(duration: 0.8)) {
            orbOffset = -20
        }
        
        // 2. Absorb into the plant and Bump
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.3)) {
                orbScale = 4.0
                orbOpacity = 0.0
            }
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                justWatered = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    justWatered = false
                }
            }
        }
    }

    private func setBottomSheetExpanded(_ expanded: Bool) {
        if reduceMotion {
            isBottomSheetExpanded = expanded
        } else {
            withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.86, blendDuration: 0.12)) {
                isBottomSheetExpanded = expanded
            }
        }
    }

    private func refreshEngagementState() {
        JourneyEngagementService.refreshJourneyState(
            for: journey,
            entries: entries,
            now: TendingTestingClock.currentDate
        )
        try? modelContext.save()
    }

    private func handleNotificationReignitePromptIfNeeded() {
        guard shouldShowReignitePrompt else { return }
        guard reigniteEligibility.isEligible else {
            onConsumeReignitePrompt()
            return
        }
        presentReigniteOverlay()
        onConsumeReignitePrompt()
    }

    private func presentReigniteOverlay() {
        guard reigniteEligibility.isEligible else { return }
        homeOverlayActive = true
        showReigniteOverlay = true
    }

    private func dismissReigniteOverlay() {
        showReigniteOverlay = false
        if reigniteEligibility.isEligible, journey.reigniteOverlayShownAt == nil {
            journey.reigniteOverlayShownAt = TendingTestingClock.currentDate
            try? modelContext.save()
        }
        onConsumeReignitePrompt()
    }

    private func triggerReignite() {
        let activated = JourneyEngagementService.applyReignite(
            to: journey,
            entries: entries,
            at: TendingTestingClock.currentDate
        )
        guard activated else { return }

        try? modelContext.save()
        showReigniteOverlay = false
        onConsumeReignitePrompt()
        triggerReigniteCelebration()
    }

    private func triggerReigniteCelebration() {
        if reduceMotion {
            showReigniteCelebration = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showReigniteCelebration = false
            }
            return
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
            showReigniteCelebration = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            withAnimation(.easeOut(duration: 0.28)) {
                showReigniteCelebration = false
            }
        }
    }

    // Core Generation Logic
    private func generateEntry() async {
        isGenerating = true
        defer { isGenerating = false }

        let generationDate = TendingTestingClock.currentDate
        
        let result = await contentService.packageForDate(
            profile: profile,
            journey: journey,
            recentEntries: entries,
            memory: memory,
            date: generationDate,
            isOnline: connectivityService.isOnline,
            modelContext: modelContext
        )

        if connectivityService.isOnline && result.source == .template {
            alertMessage = L10n.string(
                "home.tend.generation_timeout",
                default: "Today's Tend is taking longer than expected. Please try again in a moment."
            )
            return
        }
        
        let entry = PrayerEntry(
            createdAt: generationDate,
            prompt: result.package.prayer,
            scriptureReference: result.package.scriptureReference,
            scriptureText: result.package.scriptureParaphrase,
            actionStep: "",
            journey: journey
        )
        modelContext.insert(entry)
        JourneyProgressService.logEvent(
            journeyID: journey.id,
            type: .packageGenerated,
            notes: "Daily package source: \(result.source.rawValue)",
            modelContext: modelContext
        )
        analytics.track(
            .dailyPackageGenerated,
            properties: [
                "source": result.source.rawValue,
                "journey_id": journey.id.uuidString,
                "is_online": connectivityService.isOnline ? "true" : "false"
            ]
        )
        JourneyMemoryService.refreshSnapshot(
            for: journey,
            entries: entries + [entry],
            profile: profile,
            modelContext: modelContext
        )
        try? modelContext.save()
        WidgetSyncService.publishFromModelContext(modelContext)
    }
}

private enum TendingTestingClock {
    private static let dayOffsetKey = AppConstants.Debug.fastDayOffsetStorageKey

    static var isEnabled: Bool {
        AppConstants.Debug.fastDayTesting
    }

    static var currentDate: Date {
        guard isEnabled else { return .now }
        let offset = UserDefaults.standard.integer(forKey: dayOffsetKey)
        return Calendar.current.date(byAdding: .day, value: offset, to: .now) ?? .now
    }

    static func advanceDay() {
        guard isEnabled else { return }
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: dayOffsetKey) + 1, forKey: dayOffsetKey)
    }
}

private final class PlantAssetBundleLocator {}

struct TendCompletionCelebration {
    let didIncreasePlantStage: Bool
}

struct TendingFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var connectivityService: ConnectivityService
    @EnvironmentObject private var notificationService: NotificationService
    @Query(sort: \AppSettings.firstLaunchAt, order: .forward) private var settingsRows: [AppSettings]
    @Query(sort: \ReminderSchedule.sortOrder) private var reminderRows: [ReminderSchedule]
    
    let journey: PrayerJourney
    let entry: PrayerEntry
    let entries: [PrayerEntry]
    let profile: OnboardingProfile
    let package: DailyJourneyPackage?
    let onCompleted: (TendCompletionCelebration) -> Void
    
    @State private var isCompleting = false
    @State private var smallStepInput = ""
    @State private var showCompletionPrompt = false
    @State private var selectedFollowThroughStatus: FollowThroughStatus?
    @State private var revealedStageCount = 0
    private let contentService = JourneyContentService()
    private let analytics: AnalyticsTracking = AnalyticsServiceFactory.makeDefault()

    private static let tendsPerStage = 3
    private static let stagesPerCycle = 5
    private static let tendsPerCycle = tendsPerStage * stagesPerCycle

    private static func stage(for count: Int) -> Int {
        guard count > 0 else { return 1 }
        let indexInCycle = count % tendsPerCycle
        return min(stagesPerCycle, max(1, (indexInCycle / tendsPerStage) + 1))
    }

    private var reflectionThought: String {
        let value = package?.reflectionThought.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "Take one faithful step in response to what God is growing in you." : value
    }

    private var dailyTitle: String {
        let value = package?.dailyTitle.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? DailyJourneyPackageValidation.defaultDailyTitle : value
    }

    private var prayerText: String {
        let value = package?.prayer.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? entry.prompt : value
    }

    private var smallStepQuestion: String {
        let value = package?.smallStepQuestion.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? DailyJourneyPackageValidation.defaultSmallStepQuestion : value
    }

    private var suggestionChips: [String] {
        Array((package?.suggestedSteps ?? []).prefix(4))
    }

    private var pendingClosureEntry: PrayerEntry? {
        FollowThroughService.pendingClosureCheck(
            in: entries,
            currentEntryID: entry.id
        )
    }

    private var requiresClosureAnswer: Bool {
        pendingClosureEntry != nil
    }

    private var canRevealRitual: Bool {
        !requiresClosureAnswer || selectedFollowThroughStatus != nil
    }

    private var completionButtonTitle: String {
        L10n.string("home.tend.commit_button", default: "Tend")
    }

    private var followThroughVisualAccent: Color {
        switch selectedFollowThroughStatus {
        case .yes:
            return WWColor.growGreen.opacity(0.22)
        case .partial:
            return WWColor.morningGold.opacity(0.20)
        case .no:
            return WWColor.muted.opacity(0.18)
        case .unanswered, .none:
            return .clear
        }
    }

    private var hasFollowThroughVisualAccent: Bool {
        if case .yes = selectedFollowThroughStatus { return true }
        if case .partial = selectedFollowThroughStatus { return true }
        if case .no = selectedFollowThroughStatus { return true }
        return false
    }

    private var tendCardBackground: Color { WWColor.contrastCard }
    private var tendCardStroke: Color { WWColor.nearBlack.opacity(colorScheme == .dark ? 0.12 : 0.08) }
    
    var body: some View {
        ZStack {
            WWColor.surface.ignoresSafeArea()
            if hasFollowThroughVisualAccent {
                followThroughVisualAccent
                    .ignoresSafeArea()
            }
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(WWColor.muted)
                                .padding(12)
                                .background(Circle().fill(tendCardBackground))
                        }
                        .accessibilityLabel(
                            L10n.string("home.tend.close_accessibility", default: "Close today's tend")
                        )
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    if let pendingClosureEntry {
                        closureCard(for: pendingClosureEntry)
                            .padding(.horizontal, 24)
                    }

                    if !canRevealRitual {
                        Text(
                            L10n.string(
                                "home.tend.followthrough.unlock",
                                default: "Answer the follow-through checkpoint to continue today's ritual."
                            )
                        )
                        .font(WWTypography.caption(14))
                        .foregroundStyle(WWColor.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    }

                    if revealedStageCount >= 1 {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(dailyTitle)
                                .font(WWTypography.heading(30).weight(.semibold))
                                .foregroundStyle(WWColor.nearBlack)
                                .lineSpacing(3)
                                .multilineTextAlignment(.leading)
                                .offset(x: -1.5)

                            Text(L10n.string("REFLECT", default: "REFLECT"))
                                .font(WWTypography.caption(14).weight(.heavy))
                                .foregroundStyle(WWColor.muted)
                                .tracking(2.0)

                            Text(reflectionThought)
                                .font(WWTypography.heading(22))
                                .foregroundStyle(WWColor.nearBlack)
                                .lineSpacing(4)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if revealedStageCount >= 2 {
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
                        .background(tendCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(tendCardStroke, lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if revealedStageCount >= 3 {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(L10n.string("PRAY", default: "PRAY"))
                                .font(WWTypography.caption(14).weight(.heavy))
                                .foregroundStyle(WWColor.muted)
                                .tracking(2.0)

                            Text(prayerText)
                                .font(WWTypography.body(18))
                                .foregroundStyle(WWColor.nearBlack)
                                .lineSpacing(6)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if revealedStageCount >= 4 {
                        VStack(alignment: .leading, spacing: 20) {
                            Text(L10n.string("TEND", default: "TEND"))
                                .font(WWTypography.caption(14).weight(.heavy))
                                .foregroundStyle(WWColor.muted)
                                .tracking(2.0)

                            Text(smallStepQuestion)
                                .font(WWTypography.heading(22))
                                .foregroundStyle(WWColor.nearBlack)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            TextField(L10n.string("Type your small step...", default: "Type your small step..."), text: $smallStepInput)
                                .textInputAutocapitalization(.sentences)
                                .font(WWTypography.body(18))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 18)
                                .background(tendCardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(tendCardStroke, lineWidth: 1))

                            if !suggestionChips.isEmpty {
                                VStack(spacing: 10) {
                                    ForEach(suggestionChips, id: \.self) { suggestion in
                                        Button {
                                            smallStepInput = suggestion
                                        } label: {
                                            HStack(alignment: .top, spacing: 10) {
                                                Image(systemName: "plus.circle.fill")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundStyle(WWColor.growGreen)
                                                    .padding(.top, 2)
                                                Text(suggestion)
                                                    .font(WWTypography.body(15).weight(.medium))
                                                    .foregroundStyle(WWColor.nearBlack)
                                                    .multilineTextAlignment(.leading)
                                                    .fixedSize(horizontal: false, vertical: true)
                                                Spacer(minLength: 0)
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 13)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(tendCardBackground)
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .stroke(tendCardStroke, lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(
                                            String(
                                                format: L10n.string(
                                                    "home.tend.suggestion_accessibility",
                                                    default: "Use suggested step: %@"
                                                ),
                                                suggestion
                                            )
                                        )
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                        Button {
                            completeTending()
                        } label: {
                            if isCompleting {
                                ProgressView()
                                    .tint(WWColor.nearBlack)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text(completionButtonTitle)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(WWPrimaryButtonStyle(background: WWColor.growGreen, foreground: WWColor.nearBlack))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 48)
                        .padding(.top, 8)
                        .disabled(
                            isCompleting ||
                            smallStepInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            (requiresClosureAnswer && selectedFollowThroughStatus == nil)
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .onAppear {
            if !entry.actionStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                smallStepInput = entry.actionStep
            }
            startRitualReveal()
        }
        .onChange(of: selectedFollowThroughStatus) { _, _ in
            if canRevealRitual {
                startRitualReveal()
            }
        }
        .alert(L10n.string("Journey Milestone", default: "Journey Milestone"), isPresented: $showCompletionPrompt) {
            Button(L10n.string("Keep Tending", default: "Keep Tending")) {
                journey.lastCompletionPromptAt = TendingTestingClock.currentDate
                try? modelContext.save()
                WidgetSyncService.publishFromModelContext(modelContext)
                dismiss()
            }
            Button(L10n.string("Mark Complete", default: "Mark Complete")) {
                journey.status = .completed
                journey.isArchived = true
                journey.lastCompletionPromptAt = TendingTestingClock.currentDate
                JourneyProgressService.logEvent(
                    journeyID: journey.id,
                    type: .journeyCompleted,
                    notes: "User marked journey complete from milestone prompt.",
                    modelContext: modelContext
                )
                analytics.track(
                    .journeyCompleted,
                    properties: [
                        "source": "completion_prompt",
                        "journey_id": journey.id.uuidString,
                        "completed_tends": String(journey.completedTends)
                    ]
                )
                try? modelContext.save()
                WidgetSyncService.publishFromModelContext(modelContext)
                dismiss()
            }
        } message: {
            Text(package?.completionSuggestion.reason.isEmpty == false
                 ? package?.completionSuggestion.reason ?? L10n.string(
                    "Looks like this journey may be complete. You can keep tending or mark it complete.",
                    default: "Looks like this journey may be complete. You can keep tending or mark it complete."
                )
                 : L10n.string(
                    "Looks like this journey may be complete. You can keep tending or mark it complete.",
                    default: "Looks like this journey may be complete. You can keep tending or mark it complete."
                ))
        }
    }
    
    private func completeTending() {
        isCompleting = true

        let completionDate = TendingTestingClock.currentDate
        let schedulingNow = Date()
        let completedCountBeforeTend = max(
            journey.completedTends,
            entries.filter { $0.completedAt != nil }.count
        )
        let trimmedStep = smallStepInput.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.actionStep = trimmedStep
        entry.completedAt = completionDate

        let closureTarget = pendingClosureEntry
        if let closureTarget, let selectedFollowThroughStatus {
            FollowThroughService.recordFollowThrough(
                status: selectedFollowThroughStatus,
                for: closureTarget,
                on: entry,
                at: completionDate
            )
            JourneyProgressService.logEvent(
                journeyID: journey.id,
                type: .followThroughAnswered,
                notes: "Follow-through recorded as \(selectedFollowThroughStatus.rawValue) for priorEntryID=\(closureTarget.id.uuidString)",
                modelContext: modelContext,
                date: completionDate
            )
        }
        JourneyArcService.updateAfterTend(
            journey: journey,
            committedStep: trimmedStep,
            followThroughStatus: closureTarget == nil ? nil : selectedFollowThroughStatus
        )

        let baseGrowthPoints = FollowThroughService.growthPoints(
            for: selectedFollowThroughStatus,
            hasPriorCommitmentToEvaluate: closureTarget != nil
        )

        let inferredLegacyCount = entries.filter { $0.completedAt != nil }.count
        let growthUpdate = JourneyEngagementService.applyCompletionGrowth(
            to: journey,
            inferredLegacyCount: inferredLegacyCount,
            baseGrowthPoints: baseGrowthPoints,
            at: completionDate
        )
        let completionCelebration = TendCompletionCelebration(
            didIncreasePlantStage: Self.stage(for: growthUpdate.completedTendsAfterUpdate) > Self.stage(for: completedCountBeforeTend)
        )
        journey.cycleCount = growthUpdate.completedTendsAfterUpdate / Self.tendsPerCycle
        let nextCompletedSessionCount = inferredLegacyCount + 1
        let projectedEntries = entries.contains(where: { $0.id == entry.id }) ? entries : (entries + [entry])
        JourneyEngagementService.refreshJourneyState(
            for: journey,
            entries: projectedEntries,
            now: completionDate
        )

        let settings = settingsRows.first
        let wasFirstTendCompleted = FirstTendMilestoneService.isFirstTendCompleted(settings: settings)
        FirstTendMilestoneService.markFirstTendCompleted(settings: settings)
        let didCompleteFirstTend = !wasFirstTendCompleted && FirstTendMilestoneService.isFirstTendCompleted(settings: settings)

        try? modelContext.save()
        Task {
            await notificationService.scheduleReminderSchedules(
                reminderRows.filter(\.isEnabled),
                modelContext: modelContext,
                now: schedulingNow
            )
        }

        JourneyProgressService.logEvent(
            journeyID: journey.id,
            type: .stepCompleted,
            notes: "Completed step: \(trimmedStep) | baseGrowthPoints: \(baseGrowthPoints) | appliedGrowth: \(growthUpdate.appliedGrowth)",
            modelContext: modelContext
        )
        analytics.track(
            .smallStepCompleted,
            properties: [
                "source": "home_tending",
                "journey_id": journey.id.uuidString,
                "growth_points": String(baseGrowthPoints),
                "applied_growth": String(format: "%.2f", growthUpdate.appliedGrowth),
                "hydration_stage_before": String(growthUpdate.hydrationStageBeforeTend),
                "had_followthrough_prompt": closureTarget == nil ? "false" : "true",
                "did_complete_first_tend": didCompleteFirstTend ? "true" : "false"
            ]
        )
        if didCompleteFirstTend {
            JourneyProgressService.logEvent(
                journeyID: journey.id,
                type: .firstTendCompleted,
                notes: "First tend milestone reached.",
                modelContext: modelContext
            )
        }
        JourneyMemoryService.refreshSnapshot(
            for: journey,
            entries: entries,
            profile: profile,
            modelContext: modelContext
        )
        WidgetSyncService.publishFromModelContext(modelContext)

        let shouldShowCompletionPrompt = shouldPromptCompletionSuggestion(
            completedCount: nextCompletedSessionCount,
            now: completionDate
        )

        if shouldShowCompletionPrompt {
            isCompleting = false
            showCompletionPrompt = true
            return
        }

        if TendingTestingClock.isEnabled {
            isCompleting = false
            onCompleted(completionCelebration)
            dismiss()
            Task { @MainActor in
                await advanceTestingDayAndSeedNextEntryIfNeeded()
            }
        } else {
            isCompleting = false
            onCompleted(completionCelebration)
            dismiss()
        }
    }

    @MainActor
    private func advanceTestingDayAndSeedNextEntryIfNeeded() async {
        guard TendingTestingClock.isEnabled else { return }

        TendingTestingClock.advanceDay()
        let nextDate = TendingTestingClock.currentDate
        let currentEntries = entriesForJourney()
        let calendar = Calendar.current
        let hasEntryForNextDay = currentEntries.contains { calendar.isDate($0.createdAt, inSameDayAs: nextDate) }
        guard !hasEntryForNextDay else { return }

        let memory = JourneyMemoryService.snapshot(for: journey.id, modelContext: modelContext)
        let result = await contentService.packageForDate(
            profile: profile,
            journey: journey,
            recentEntries: currentEntries,
            memory: memory,
            date: nextDate,
            isOnline: connectivityService.isOnline,
            modelContext: modelContext
        )

        let nextEntry = PrayerEntry(
            createdAt: nextDate,
            prompt: result.package.prayer,
            scriptureReference: result.package.scriptureReference,
            scriptureText: result.package.scriptureParaphrase,
            actionStep: "",
            journey: journey
        )
        modelContext.insert(nextEntry)
        JourneyProgressService.logEvent(
            journeyID: journey.id,
            type: .packageGenerated,
            notes: "Daily package source: \(result.source.rawValue) | fast_day_mode=true",
            modelContext: modelContext
        )
        analytics.track(
            .dailyPackageGenerated,
            properties: [
                "source": result.source.rawValue,
                "journey_id": journey.id.uuidString,
                "is_online": connectivityService.isOnline ? "true" : "false",
                "fast_day_mode": "true"
            ]
        )
        JourneyMemoryService.refreshSnapshot(
            for: journey,
            entries: currentEntries + [nextEntry],
            profile: profile,
            modelContext: modelContext
        )
        try? modelContext.save()
        WidgetSyncService.publishFromModelContext(modelContext)
    }

    private func entriesForJourney() -> [PrayerEntry] {
        let journeyID = journey.id
        let descriptor = FetchDescriptor<PrayerEntry>(
            predicate: #Predicate { $0.journey?.id == journeyID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? entries
    }

    private func startRitualReveal() {
        guard canRevealRitual else {
            revealedStageCount = 0
            return
        }

        if reduceMotion {
            revealedStageCount = 4
            return
        }

        if revealedStageCount >= 4 {
            return
        }

        revealedStageCount = max(1, revealedStageCount)
        let revealDelays: [Double] = [0.12, 0.24, 0.36]
        for (index, delay) in revealDelays.enumerated() {
            let stage = index + 2
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                    revealedStageCount = max(revealedStageCount, stage)
                }
            }
        }
    }

    @ViewBuilder
    private func closureCard(for priorEntry: PrayerEntry) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.string("FOLLOW-THROUGH", default: "FOLLOW-THROUGH"))
                .font(WWTypography.caption(12).weight(.heavy))
                .tracking(2.0)
                .foregroundStyle(WWColor.muted)

            Text(
                L10n.string(
                    "Did you do the step you committed to yesterday?",
                    default: "Did you do the step you committed to yesterday?"
                )
            )
                .font(WWTypography.heading(22))
                .foregroundStyle(WWColor.nearBlack)

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.string("home.tend.followthrough.previous_step", default: "Previous step"))
                    .font(WWTypography.caption(11).weight(.heavy))
                    .tracking(1.0)
                    .foregroundStyle(WWColor.muted)
                Text(priorEntry.actionStep)
                    .font(WWTypography.body(16))
                    .foregroundStyle(WWColor.nearBlack)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(WWColor.surface.opacity(0.94))
            )

            HStack(spacing: 6) {
                followThroughButton(title: L10n.string("Yes", default: "Yes"), status: .yes)
                followThroughButton(title: L10n.string("Partially", default: "Partially"), status: .partial)
                followThroughButton(title: L10n.string("No", default: "No"), status: .no)
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(WWColor.surface.opacity(0.7))
            )
        }
        .padding(20)
        .background(tendCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(tendCardStroke, lineWidth: 1)
        )
    }

    private func followThroughButton(title: String, status: FollowThroughStatus) -> some View {
        let isSelected = selectedFollowThroughStatus == status
        return Button {
            if reduceMotion {
                selectedFollowThroughStatus = status
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedFollowThroughStatus = status
                }
            }
        } label: {
            Text(title)
                .font(WWTypography.body(14).weight(.semibold))
                .foregroundStyle(isSelected ? WWColor.nearBlack : WWColor.muted)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .background(isSelected ? WWColor.growGreen : WWColor.surface.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: isSelected ? WWColor.growGreen.opacity(0.22) : .clear, radius: 5, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? L10n.string("tab.selected", default: "Selected") : "")
    }

    private func shouldPromptCompletionSuggestion(
        completedCount: Int,
        now: Date
    ) -> Bool {
        guard journey.status == .active else { return false }
        guard completedCount >= 7 else { return false }
        guard package?.completionSuggestion.shouldPrompt == true else { return false }

        if let lastPrompt = journey.lastCompletionPromptAt, Calendar.current.isDate(lastPrompt, inSameDayAs: now) {
            return false
        }
        return true
    }

    static func calculateGlobalStreakCount(for entries: [PrayerEntry]) -> Int {
        let calendar = Calendar.current
        let completedDays: [Date] = Array(Set(entries.compactMap { entry in
            guard let completedAt = entry.completedAt else { return nil }
            return calendar.startOfDay(for: completedAt)
        }))
        .sorted(by: >)

        guard let first = completedDays.first else { return 0 }
        var streak = 1
        var previous = first

        for day in completedDays.dropFirst() {
            let diff = calendar.dateComponents([.day], from: day, to: previous).day ?? 0
            if diff == 1 {
                streak += 1
                previous = day
            } else {
                break
            }
        }

        return streak
    }
}

struct StreakOverlayView: View {
    @Environment(\.colorScheme) private var colorScheme
    let streakCount: Int
    let onDismiss: () -> Void
    
    var body: some View {
        GeometryReader { proxy in
            let effectiveTopInset = max(proxy.safeAreaInsets.top, 64)
            let backgroundColor = colorScheme == .dark ? WWColor.darkBackground : WWColor.white
            ZStack {
                backgroundColor
                    .frame(width: proxy.size.width, height: proxy.size.height + effectiveTopInset + 24)
                    .offset(y: -(effectiveTopInset + 24))
                    .ignoresSafeArea()
            
                VStack(spacing: 32) {
                    Spacer()
                
                    ZStack {
                        Circle()
                            .fill(WWColor.morningGold.opacity(0.3))
                            .frame(width: 180, height: 180)
                            .blur(radius: 40)
                            
                        if let img = UIImage(named: "sun_streak_icon") {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 140, height: 140)
                                .shadow(color: WWColor.morningGold.opacity(0.5), radius: 30, y: 10)
                        } else {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 100))
                                .foregroundStyle(WWColor.growGreen)
                                .shadow(color: WWColor.morningGold.opacity(0.5), radius: 30, y: 10)
                        }
                    }
                
                    VStack(spacing: 12) {
                        Text("\(streakCount)")
                            .font(WWTypography.display(64))
                            .foregroundStyle(WWColor.nearBlack)
                            
                        Text(L10n.string("Day Streak!", default: "Day Streak!"))
                            .font(WWTypography.heading(28))
                            .foregroundStyle(WWColor.nearBlack)
                    }
                
                    HStack(spacing: 8) {
                        ForEach(0..<min(streakCount, 7), id: \.self) { _ in
                            Circle()
                                .fill(WWColor.growGreen)
                                .frame(width: 12, height: 12)
                        }
                        if streakCount > 7 {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(WWColor.growGreen)
                        }
                    }
                    .padding(.top, 16)
                
                    Spacer()
                
                    Button(action: onDismiss) {
                        Text(L10n.string("Continue", default: "Continue"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(WWPrimaryButtonStyle(background: WWColor.growGreen, foreground: WWColor.nearBlack))
                    .padding(.horizontal, 32)
                    .padding(.bottom, max(120, proxy.safeAreaInsets.bottom + 52))
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct ReigniteOverlayView: View {
    @Environment(\.colorScheme) private var colorScheme
    let streakCount: Int
    let onReignite: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let effectiveTopInset = max(proxy.safeAreaInsets.top, 64)
            let backgroundColor = colorScheme == .dark ? WWColor.darkBackground : WWColor.white

            ZStack {
                backgroundColor
                    .frame(width: proxy.size.width, height: proxy.size.height + effectiveTopInset + 24)
                    .offset(y: -(effectiveTopInset + 24))
                    .ignoresSafeArea()

                VStack(spacing: 26) {
                    Spacer()

                    Image(systemName: "flame.fill")
                        .font(.system(size: 82, weight: .bold))
                        .foregroundStyle(WWColor.growGreen)
                        .shadow(color: WWColor.growGreen.opacity(0.35), radius: 28, y: 12)

                    Text(
                        String(
                            format: L10n.string("home.reignite.overlay.title", default: "Restore your %d-day streak"),
                            max(streakCount, 1)
                        )
                    )
                        .font(WWTypography.heading(30))
                        .foregroundStyle(WWColor.nearBlack)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)

                    Text(L10n.string("home.reignite.overlay.subtitle", default: "One tap. Keep growing."))
                        .font(WWTypography.body(18))
                        .foregroundStyle(WWColor.muted)

                    Spacer()

                    Button(action: onReignite) {
                        Text(L10n.string("home.reignite.overlay.cta", default: "Reignite"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(WWPrimaryButtonStyle(background: WWColor.growGreen, foreground: WWColor.nearBlack))
                    .padding(.horizontal, 32)

                    Button(action: onDismiss) {
                        Text(L10n.string("home.reignite.overlay.dismiss", default: "Not now"))
                            .font(WWTypography.caption(13).weight(.medium))
                            .foregroundStyle(WWColor.muted)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, max(110, proxy.safeAreaInsets.bottom + 44))
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct ReigniteCelebrationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    WWColor.growGreen.opacity(0.14),
                    WWColor.morningGold.opacity(0.08),
                    .clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .ignoresSafeArea()

            ZStack {
                Circle()
                    .fill(WWColor.growGreen.opacity(0.20))
                    .frame(width: animate ? 260 : 120, height: animate ? 260 : 120)
                    .blur(radius: 22)
                    .opacity(animate ? 0.0 : 1.0)

                Image(systemName: "flame.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(WWColor.growGreen)
                    .scaleEffect(animate ? 1.14 : 0.86)
                    .shadow(color: WWColor.growGreen.opacity(0.35), radius: 20, y: 8)
            }

            HStack(spacing: 20) {
                ForEach(0..<6, id: \.self) { idx in
                    Circle()
                        .fill(idx.isMultiple(of: 2) ? WWColor.growGreen : WWColor.morningGold)
                        .frame(width: 10, height: 10)
                        .offset(x: animate ? CGFloat((idx - 2) * 16) : 0, y: animate ? CGFloat((idx % 2 == 0 ? -56 : 56)) : 0)
                        .opacity(animate ? 0.0 : 1.0)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            if reduceMotion {
                animate = true
                return
            }
            withAnimation(.easeOut(duration: 0.85)) {
                animate = true
            }
        }
    }
}
