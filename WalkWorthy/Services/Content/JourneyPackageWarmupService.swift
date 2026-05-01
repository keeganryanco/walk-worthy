import Foundation
import SwiftData

struct JourneyPackageWarmupResult: Equatable {
    let didPreparePackage: Bool
    let message: String?

    static let prepared = JourneyPackageWarmupResult(didPreparePackage: true, message: nil)
    static let skipped = JourneyPackageWarmupResult(didPreparePackage: false, message: nil)
}

@MainActor
final class JourneyPackageWarmupService {
    private let contentService: JourneyContentService
    private var inFlight: [String: Task<JourneyPackageWarmupResult, Never>] = [:]

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
    ) async -> JourneyPackageWarmupResult {
        guard isOnline else { return .skipped }
        let dayKey = JourneyContentService.dayKey(for: date)
        let key = "\(journey.id.uuidString)-\(dayKey)"

        if hasCurrentPackage(journeyID: journey.id, dayKey: dayKey, modelContext: modelContext) {
            return .prepared
        }

        if let existing = inFlight[key] {
            return await existing.value
        }

        let task = Task { @MainActor [contentService] in
            let result = await contentService.packageForDate(
                profile: profile,
                journey: journey,
                recentEntries: entries,
                memory: memory,
                date: date,
                isOnline: true,
                modelContext: modelContext
            )
            if hasCurrentPackage(journeyID: journey.id, dayKey: dayKey, modelContext: modelContext) {
                return JourneyPackageWarmupResult.prepared
            }
            return JourneyPackageWarmupResult(
                didPreparePackage: false,
                message: result.preparationFailureMessage
            )
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        return result
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
            _ = await warmToday(
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
