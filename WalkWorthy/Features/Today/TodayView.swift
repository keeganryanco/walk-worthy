import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var connectivityService: ConnectivityService

    let profile: OnboardingProfile

    @Query(filter: #Predicate<PrayerJourney> { !$0.isArchived }, sort: \PrayerJourney.createdAt, order: .reverse)
    private var activeJourneys: [PrayerJourney]
    @Query(sort: \PrayerEntry.createdAt, order: .reverse)
    private var allEntries: [PrayerEntry]
    @Query(sort: \JourneyMemorySnapshot.updatedAt, order: .reverse)
    private var memorySnapshots: [JourneyMemorySnapshot]

    @State private var reflectionDraft = ""

    private let contentService = JourneyContentService()

    private var todaysEntry: PrayerEntry? {
        let calendar = Calendar.current
        return allEntries.first(where: { calendar.isDateInToday($0.createdAt) })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if let entry = todaysEntry {
                        card(entry)
                    } else {
                        emptyState
                    }
                }
                .padding(20)
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pray, then take one step.")
                .font(WWTypography.section())
                .foregroundStyle(WWColor.charcoal)

            Text("Built for sincere action in under a minute.")
                .font(WWTypography.body(16))
                .foregroundStyle(WWColor.charcoal.opacity(0.75))
        }
    }

    private func card(_ entry: PrayerEntry) -> some View {
        WWCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Prayer")
                    .font(WWTypography.detail())
                    .foregroundStyle(WWColor.sapphire)

                Text(entry.prompt)
                    .font(WWTypography.body())
                    .foregroundStyle(WWColor.charcoal)

                if !entry.scriptureReference.isEmpty {
                    Divider()

                    Text(entry.scriptureReference)
                        .font(WWTypography.detail())
                        .foregroundStyle(WWColor.sapphire)

                    Text(entry.scriptureText)
                        .font(WWTypography.body(16))
                        .foregroundStyle(WWColor.charcoal)
                }

                Divider()

                Text("Do")
                    .font(WWTypography.detail())
                    .foregroundStyle(WWColor.sapphire)

                Text(entry.actionStep)
                    .font(WWTypography.body())
                    .foregroundStyle(WWColor.charcoal)

                TextField("Optional reflection", text: binding(for: entry))
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 12) {
                    Button(entry.completedAt == nil ? "Complete" : "Completed") {
                        complete(entry: entry)
                    }
                    .buttonStyle(WWPrimaryButtonStyle())
                    .disabled(entry.completedAt != nil)

                    Button("Answered") {
                        let note = entry.userReflection.isEmpty ? "Marked as answered." : entry.userReflection
                        let answered = AnsweredPrayer(notes: note, linkedEntryID: entry.id, journey: entry.journey)
                        modelContext.insert(answered)
                        try? modelContext.save()
                    }
                    .font(WWTypography.detail())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private var emptyState: some View {
        WWCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Your Today card is ready when you are.")
                    .font(WWTypography.section(24))
                    .foregroundStyle(WWColor.charcoal)

                Text("Generate a prayer prompt, one concrete action step, and a short scripture excerpt.")
                    .font(WWTypography.body())
                    .foregroundStyle(WWColor.charcoal.opacity(0.75))

                Button("Generate Today Card") {
                    Task { await generateTodayCard() }
                }
                .buttonStyle(WWPrimaryButtonStyle())
            }
        }
    }

    private func binding(for entry: PrayerEntry) -> Binding<String> {
        Binding {
            if reflectionDraft.isEmpty {
                return entry.userReflection
            }
            return reflectionDraft
        } set: { newValue in
            reflectionDraft = newValue
            entry.userReflection = newValue
            try? modelContext.save()
        }
    }

    private func complete(entry: PrayerEntry) {
        entry.completedAt = entry.completedAt == nil ? .now : entry.completedAt
        try? modelContext.save()

        guard let journey = entry.journey else { return }
        JourneyProgressService.logEvent(
            journeyID: journey.id,
            type: .stepCompleted,
            notes: "Completed step: \(entry.actionStep)",
            modelContext: modelContext
        )
        let journeyEntries = allEntries.filter { $0.journey?.id == journey.id }
        JourneyMemoryService.refreshSnapshot(
            for: journey,
            entries: journeyEntries,
            profile: profile,
            modelContext: modelContext
        )
    }

    private func memory(for journeyID: UUID) -> JourneyMemorySnapshot? {
        memorySnapshots.first(where: { $0.journeyID == journeyID })
    }

    private func entries(for journeyID: UUID) -> [PrayerEntry] {
        allEntries.filter { $0.journey?.id == journeyID }
    }

    private func generateTodayCard() async {
        guard let journey = activeJourneys.first else {
            let seededJourney = PrayerJourney(title: "Prayer Journey", category: profile.prayerFocus)
            modelContext.insert(seededJourney)
            try? modelContext.save()
            await createEntry(in: seededJourney)
            return
        }

        await createEntry(in: journey)
    }

    private func createEntry(in journey: PrayerJourney) async {
        let result = await contentService.packageForDate(
            profile: profile,
            journey: journey,
            recentEntries: entries(for: journey.id),
            memory: memory(for: journey.id),
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
            entries: entries(for: journey.id) + [entry],
            profile: profile,
            modelContext: modelContext
        )
        try? modelContext.save()
    }
}
