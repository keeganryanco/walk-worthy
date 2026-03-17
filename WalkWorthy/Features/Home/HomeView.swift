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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if activeJourneys.isEmpty {
                        emptyState
                    } else {
                        ForEach(activeJourneys) { journey in
                            JourneyGrowthCard(
                                journey: journey,
                                entries: entries(for: journey.id),
                                profile: profile,
                                memory: memory(for: journey.id),
                                contentService: contentService
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Home")
            .scrollContentBackground(.hidden)
            .background(WWColor.surface.ignoresSafeArea())
        }
    }

    private var emptyState: some View {
        WWCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Your garden is ready.")
                    .font(WWTypography.section(24))
                    .foregroundStyle(WWColor.nearBlack)

                Text("Create your first prayer journey to begin growing.")
                    .font(WWTypography.body())
                    .foregroundStyle(WWColor.muted)
            }
        }
    }

    private func memory(for journeyID: UUID) -> JourneyMemorySnapshot? {
        memorySnapshots.first(where: { $0.journeyID == journeyID })
    }

    private func entries(for journeyID: UUID) -> [PrayerEntry] {
        allEntries.filter { $0.journey?.id == journeyID }
    }
}

struct JourneyGrowthCard: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var connectivityService: ConnectivityService
    
    let journey: PrayerJourney
    let entries: [PrayerEntry]
    let profile: OnboardingProfile
    let memory: JourneyMemorySnapshot?
    let contentService: JourneyContentService
    
    @State private var isGenerating = false
    @State private var justWatered = false
    
    private var todaysEntry: PrayerEntry? {
        let calendar = Calendar.current
        return entries.first(where: { calendar.isDateInToday($0.createdAt) })
    }
    
    private var completedCount: Int {
        entries.filter { $0.completedAt != nil }.count
    }
    
    // Plant state logic based on completed count
    private var plantIcon: String {
        if completedCount == 0 { return "🌱" } // Seed/Sprout
        if completedCount < 3 { return "🌿" } // Young plant
        return "🪴" // Mature plant
    }
    
    var body: some View {
        WWCard {
            VStack(alignment: .leading, spacing: 16) {
                // Header: Title + Plant
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(journey.title)
                            .font(WWTypography.heading(24))
                            .foregroundStyle(WWColor.nearBlack)
                        Text(journey.category)
                            .font(WWTypography.caption())
                            .foregroundStyle(WWColor.growGreen)
                    }
                    Spacer()
                    Text(plantIcon)
                        .font(.system(size: 40))
                        .scaleEffect(justWatered ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0), value: justWatered)
                }
                
                // Indicators: week progress
                dailyIndicators
                
                Divider()
                
                // Today's Action Section
                if let entry = todaysEntry {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today's Step")
                            .font(WWTypography.caption(16).weight(.bold))
                            .foregroundStyle(WWColor.growGreen)
                        
                        Text(entry.prompt)
                            .font(WWTypography.body(16))
                            .foregroundStyle(WWColor.nearBlack)
                        
                        if !entry.scriptureReference.isEmpty {
                            Text("\(entry.scriptureText) — \(entry.scriptureReference)")
                                .font(WWTypography.body(14).italic())
                                .foregroundStyle(WWColor.muted)
                        }
                        
                        HStack {
                            Text(entry.actionStep)
                                .font(WWTypography.body(16).weight(.medium))
                                .foregroundStyle(WWColor.nearBlack)
                            Spacer()
                        }
                        .padding()
                        .background(WWColor.growGreen.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Button {
                            complete(entry: entry)
                        } label: {
                            Text(entry.completedAt == nil ? "Water & Complete" : "Completed")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(WWPrimaryButtonStyle(
                            background: entry.completedAt == nil ? WWColor.growGreen : WWColor.surface,
                            foreground: entry.completedAt == nil ? WWColor.white : WWColor.muted
                        ))
                        .disabled(entry.completedAt != nil)
                    }
                } else {
                    Button {
                        Task { await generateEntry() }
                    } label: {
                        if isGenerating {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Reveal Today's Step")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(WWPrimaryButtonStyle(background: WWColor.surface, foreground: WWColor.nearBlack))
                    .disabled(isGenerating)
                }
            }
        }
    }
    
    private var dailyIndicators: some View {
        HStack(spacing: 8) {
            // Simplified: 7 circles, completed entries fill them
            ForEach(0..<7) { i in
                Circle()
                    .fill(i < completedCount ? WWColor.growGreen : WWColor.surface)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(WWColor.growGreen.opacity(0.3), lineWidth: 1))
            }
        }
    }
    
    private func complete(entry: PrayerEntry) {
        entry.completedAt = .now
        try? modelContext.save()
        
        withAnimation {
            justWatered = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                justWatered = false
            }
        }

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
    }
    
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
