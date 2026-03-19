import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var connectivityService: ConnectivityService

    let profile: OnboardingProfile

    @Query(filter: #Predicate<PrayerJourney> { !$0.isArchived }, sort: \PrayerJourney.createdAt, order: .reverse)
    private var activeJourneys: [PrayerJourney]
    
    @Query(sort: \PrayerEntry.createdAt, order: .reverse)
    private var allEntries: [PrayerEntry]
    
    @Query(sort: \JourneyMemorySnapshot.updatedAt, order: .reverse)
    private var memorySnapshots: [JourneyMemorySnapshot]

    private let contentService = JourneyContentService()
    
    @State private var selectedJourneyID: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                WWColor.surface.ignoresSafeArea()
                
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
                                contentService: contentService
                            )
                            .tag(journey.id as UUID?)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .ignoresSafeArea(edges: .top)
                }
            }
            .onAppear {
                if selectedJourneyID == nil {
                    selectedJourneyID = activeJourneys.first?.id
                }
            }
            .navigationBarHidden(true)
            .accessibilityIdentifier("HomeView")
        }
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 24) {
            Text("Your garden is ready.")
                .font(WWTypography.section(28))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)

            Text("Create your first prayer journey to begin growing.")
                .font(WWTypography.body(18))
                .foregroundStyle(WWColor.muted)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    private func memory(for journeyID: UUID) -> JourneyMemorySnapshot? {
        memorySnapshots.first(where: { $0.journeyID == journeyID })
    }

    private func entries(for journeyID: UUID) -> [PrayerEntry] {
        allEntries.filter { $0.journey?.id == journeyID }
    }
}

struct JourneyGrowthPage: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var connectivityService: ConnectivityService
    
    let journey: PrayerJourney
    let entries: [PrayerEntry]
    let profile: OnboardingProfile
    let memory: JourneyMemorySnapshot?
    let contentService: JourneyContentService
    
    @State private var isGenerating = false
    @State private var showTendingSheet = false
    
    private var todaysEntry: PrayerEntry? {
        let calendar = Calendar.current
        return entries.first(where: { calendar.isDateInToday($0.createdAt) })
    }
    
    private var completedCount: Int {
        entries.filter { $0.completedAt != nil }.count
    }
    
    private var plantStage: Int {
        let count = completedCount
        if count == 0 { return 1 } // Seed
        if count < 3 { return 2 } // Sprout
        if count < 7 { return 3 } // Young plant
        if count < 14 { return 4 } // Maturing
        return 5 // Full Bloom
    }
    
    private var themeSuffix: String {
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
    
    private var plantImageName: String {
        "growth_stage_\(plantStage)_\(themeSuffix)"
    }

    private var fallbackPlantImageName: String {
        "growth_stage_\(plantStage)_basic"
    }

    private var resolvedPlantImageName: String? {
        let candidates = [
            plantImageName,
            "Plants/\(plantImageName)",
            fallbackPlantImageName,
            "Plants/\(fallbackPlantImageName)"
        ]

        for candidate in candidates {
            if UIImage(named: candidate) != nil {
                return candidate
            }
        }

        return nil
    }
    
    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                // Top Half: Plant Visual
                ZStack {
                    WWColor.morningGold.opacity(0.05)
                        .ignoresSafeArea(edges: .top)
                    
                    VStack {
                        Spacer()
                        if let resolvedPlantImageName {
                            Image(resolvedPlantImageName)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: proxy.size.height * 0.45)
                                .padding(.bottom, 32)
                        } else {
                            // Fallback if asset is missing
                            Text(stageEmoji(for: plantStage))
                                .font(.system(size: 100))
                                .padding(.bottom, 60)
                        }
                    }
                }
                .frame(height: proxy.size.height * 0.5)
                
                // Bottom Half: Content & Actions
                bottomHalf
                    .frame(height: proxy.size.height * 0.5)
            }
        }
        .fullScreenCover(isPresented: $showTendingSheet) {
            if let entry = todaysEntry {
                TendingFlowView(
                    journey: journey,
                    entry: entry,
                    entries: entries,
                    profile: profile
                )
            }
        }
    }
    
    @ViewBuilder
    private var bottomHalf: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text(journey.title)
                    .font(WWTypography.heading(28))
                    .foregroundStyle(WWColor.nearBlack)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                
                Text(journey.category.uppercased())
                    .font(WWTypography.caption(12).weight(.bold))
                    .foregroundStyle(WWColor.growGreen)
                    .tracking(2.0)
            }
            .padding(.top, 40)
            
            Spacer()
            
            // Action or Completed State
            if let entry = todaysEntry {
                if entry.completedAt != nil {
                    // Completed State: Show reflection
                    VStack(spacing: 16) {
                        Text("Today's Tend")
                            .font(WWTypography.caption(14).weight(.bold))
                            .foregroundStyle(WWColor.muted)
                            .tracking(1.0)
                        
                        Text(entry.actionStep)
                            .font(WWTypography.body(16))
                            .foregroundStyle(WWColor.nearBlack)
                            .multilineTextAlignment(.center)
                            .padding(20)
                            .background(WWColor.growGreen.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 32)
                } else {
                    // Needs Tending
                    Button {
                        showTendingSheet = true
                    } label: {
                        Text("Tend to your plant")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(WWPrimaryButtonStyle(background: WWColor.growGreen, foreground: WWColor.white))
                    .padding(.horizontal, 32)
                }
            } else {
                // Needs Generation
                Button {
                    Task { await generateEntry() }
                } label: {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Reveal Today's Step")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(WWPrimaryButtonStyle(background: WWColor.nearBlack, foreground: WWColor.white))
                .padding(.horizontal, 32)
                .disabled(isGenerating)
            }
            
            Spacer()
            Spacer()
        }
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(WWColor.white)
                .shadow(color: WWColor.nearBlack.opacity(0.05), radius: 20, y: -10)
        )
        .ignoresSafeArea(edges: .bottom)
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
    
    // Core Generation Logic
    private func generateEntry() async {
        isGenerating = true
        defer { isGenerating = false }
        
        let result = await contentService.packageForDate(
            profile: profile,
            journey: journey,
            recentEntries: entries,
            memory: memory,
            date: .now,
            isOnline: connectivityService.isOnline,
            modelContext: modelContext
        )
        
        let entry = PrayerEntry(
            prompt: result.package.prayer,
            scriptureReference: result.package.scriptureReference,
            scriptureText: result.package.scriptureParaphrase,
            actionStep: result.package.suggestedSteps.first ?? "Take one faithful next step today.",
            journey: journey
        )
        modelContext.insert(entry)
        JourneyProgressService.logEvent(
            journeyID: journey.id,
            type: .packageGenerated,
            notes: "Daily package source: \(result.source.rawValue)",
            modelContext: modelContext
        )
        JourneyMemoryService.refreshSnapshot(
            for: journey,
            entries: entries + [entry],
            profile: profile,
            modelContext: modelContext
        )
        try? modelContext.save()
    }
}

struct TendingFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let journey: PrayerJourney
    let entry: PrayerEntry
    let entries: [PrayerEntry]
    let profile: OnboardingProfile
    
    @State private var isCompleting = false
    
    var body: some View {
        ZStack {
            WWColor.surface.ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(WWColor.muted)
                            .padding(12)
                            .background(Circle().fill(WWColor.white))
                            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Spacer()
                
                VStack(spacing: 24) {
                    Text(entry.scriptureText)
                        .font(WWTypography.heading(32))
                        .foregroundStyle(WWColor.nearBlack)
                        .lineSpacing(6)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Text("— " + entry.scriptureReference)
                        .font(WWTypography.body(18).weight(.bold))
                        .foregroundStyle(WWColor.growGreen)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Text("TODAY's TEND")
                        .font(WWTypography.caption(14).weight(.bold))
                        .foregroundStyle(WWColor.muted)
                        .tracking(1.5)
                    
                    Text(entry.actionStep)
                        .font(WWTypography.body(20))
                        .foregroundStyle(WWColor.nearBlack)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(32)
                        .background(WWColor.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: WWColor.growGreen.opacity(0.08), radius: 15, y: 8)
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                Button {
                    completeTending()
                } label: {
                    if isCompleting {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Tend to Plant")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(WWPrimaryButtonStyle(background: WWColor.growGreen, foreground: WWColor.white))
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .disabled(isCompleting)
            }
        }
    }
    
    private func completeTending() {
        isCompleting = true
        
        // Artificial delay so the user feels the weight of the action
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            entry.completedAt = .now
            try? modelContext.save()
            
            JourneyProgressService.logEvent(
                journeyID: journey.id,
                type: .stepCompleted,
                notes: "Completed step: \(entry.actionStep)",
                modelContext: modelContext
            )
            JourneyMemoryService.refreshSnapshot(
                for: journey,
                entries: entries,
                profile: profile,
                modelContext: modelContext
            )
            
            isCompleting = false
            dismiss()
        }
    }
}
