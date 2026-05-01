import Foundation
import SwiftData

@MainActor
final class JourneyPackageWarmupService {
    private let contentService: JourneyContentService
    private var inFlight: [String: Task<Void, Never>] = [:]

    init(contentService: JourneyContentService? = nil) {
        self.contentService = contentService ?? JourneyContentService()
    }

    func warmToday(
        profile: OnboardingProfile,
        journey: PrayerJourney,
        entries: [PrayerEntry],
        memory: JourneyMemorySnapshot?,
        isOnline: Bool,
        modelContext: ModelContext,
        date: Date = .now
    ) async {
        guard isOnline else { return }
        let dayKey = JourneyContentService.dayKey(for: date)
        let key = "\(journey.id.uuidString)-\(dayKey)"

        if hasCurrentPackage(journeyID: journey.id, dayKey: dayKey, modelContext: modelContext) {
            return
        }

        if let existing = inFlight[key] {
            await existing.value
            return
        }

        let task = Task { @MainActor [contentService] in
            _ = await contentService.packageForDate(
                profile: profile,
                journey: journey,
                recentEntries: entries,
                memory: memory,
                date: date,
                isOnline: true,
                modelContext: modelContext
            )
        }
        inFlight[key] = task
        await task.value
        inFlight[key] = nil
    }

    func warmActiveJourneys(
        profile: OnboardingProfile,
        journeys: [PrayerJourney],
        entriesByJourneyID: [UUID: [PrayerEntry]],
        memoryByJourneyID: [UUID: JourneyMemorySnapshot],
        isOnline: Bool,
        modelContext: ModelContext,
        date: Date = .now,
        limit: Int? = nil
    ) async {
        guard isOnline else { return }
        let targets = limit.map { Array(journeys.prefix($0)) } ?? journeys
        for journey in targets {
            await warmToday(
                profile: profile,
                journey: journey,
                entries: entriesByJourneyID[journey.id] ?? [],
                memory: memoryByJourneyID[journey.id],
                isOnline: isOnline,
                modelContext: modelContext,
                date: date
            )
        }
    }

    func isWarming(journeyID: UUID, date: Date = .now) -> Bool {
        let dayKey = JourneyContentService.dayKey(for: date)
        return inFlight["\(journeyID.uuidString)-\(dayKey)"] != nil
    }

    private func hasCurrentPackage(journeyID: UUID, dayKey: String, modelContext: ModelContext) -> Bool {
        let minQualityVersion = DailyJourneyPackage.currentQualityVersion
        let descriptor = FetchDescriptor<DailyJourneyPackageRecord>(
            predicate: #Predicate {
                $0.journeyID == journeyID &&
                $0.dayKey == dayKey &&
                $0.qualityVersion >= minQualityVersion
            }
        )
        return ((try? modelContext.fetch(descriptor)) ?? []).isEmpty == false
    }
}
