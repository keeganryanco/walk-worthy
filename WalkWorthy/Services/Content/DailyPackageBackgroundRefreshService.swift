import BackgroundTasks
import Foundation
import SwiftData

enum DailyPackageBackgroundRefreshService {
    static let identifier = "co.keeganryan.tend.daily-package-refresh"

    static func register(modelContainer: ModelContainer) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { task in
            guard let task = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(task: task, modelContainer: modelContainer)
        }
    }

    static func schedule(earliestBeginDate: Date? = nil) {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = earliestBeginDate ?? Calendar.current.date(byAdding: .hour, value: 6, to: .now)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Background refresh is best-effort; foreground warmup remains the reliable path.
        }
    }

    private static func handle(task: BGAppRefreshTask, modelContainer: ModelContainer) {
        schedule()
        let work = Task { @MainActor in
            let context = ModelContext(modelContainer)
            let profileDescriptor = FetchDescriptor<OnboardingProfile>(sortBy: [SortDescriptor(\.createdAt)])
            guard let profile = try? context.fetch(profileDescriptor).first else {
                task.setTaskCompleted(success: true)
                return
            }

            let journeyDescriptor = FetchDescriptor<PrayerJourney>(
                predicate: #Predicate { !$0.isArchived },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let journeys = (try? context.fetch(journeyDescriptor)) ?? []
            guard !journeys.isEmpty else {
                task.setTaskCompleted(success: true)
                return
            }

            let entries = (try? context.fetch(FetchDescriptor<PrayerEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []
            var entriesByJourneyID: [UUID: [PrayerEntry]] = [:]
            for entry in entries {
                guard let journeyID = entry.journey?.id else { continue }
                entriesByJourneyID[journeyID, default: []].append(entry)
            }

            let memories = (try? context.fetch(FetchDescriptor<JourneyMemorySnapshot>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))) ?? []
            let memoryByJourneyID = Dictionary(uniqueKeysWithValues: memories.map { ($0.journeyID, $0) })

            await JourneyPackageWarmupService().warmActiveJourneys(
                profile: profile,
                journeys: journeys,
                entriesByJourneyID: entriesByJourneyID,
                memoryByJourneyID: memoryByJourneyID,
                isOnline: true,
                modelContext: context,
                limit: 2
            )
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
