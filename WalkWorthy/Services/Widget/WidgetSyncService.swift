import Foundation
import SwiftData
import WidgetKit

@MainActor
enum WidgetSyncService {
    static func publishWidgetSnapshot(_ snapshot: TendWidgetSnapshot) {
        TendWidgetSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func clearWidgetSnapshot() {
        TendWidgetSnapshotStore.clear()
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func publishFromModelContext(_ modelContext: ModelContext, now: Date = .now) {
        let journeyDescriptor = FetchDescriptor<PrayerJourney>(
            predicate: #Predicate<PrayerJourney> { !$0.isArchived },
            sortBy: [SortDescriptor(\PrayerJourney.createdAt, order: .reverse)]
        )

        guard let activeJourney = try? modelContext.fetch(journeyDescriptor).first else {
            clearWidgetSnapshot()
            return
        }

        let allEntriesDescriptor = FetchDescriptor<PrayerEntry>(
            sortBy: [SortDescriptor(\PrayerEntry.createdAt, order: .reverse)]
        )
        let allEntries = (try? modelContext.fetch(allEntriesDescriptor)) ?? []
        let entries = allEntries.filter { $0.journey?.id == activeJourney.id }

        let dayKey = JourneyContentService.dayKey(for: now)
        let journeyID = activeJourney.id
        let packageDescriptor = FetchDescriptor<DailyJourneyPackageRecord>(
            predicate: #Predicate<DailyJourneyPackageRecord> {
                $0.journeyID == journeyID && $0.dayKey == dayKey
            }
        )
        let package = try? modelContext.fetch(packageDescriptor).first

        let scriptureSnippet = compact(
            package?.scriptureParaphrase
            ?? entries.first(where: { Calendar.current.isDateInToday($0.createdAt) })?.scriptureText
            ?? entries.first?.scriptureText
            ?? TendWidgetSnapshot.empty.scriptureSnippet,
            maxLength: 110
        )

        let todayStep = compact(
            entries.first(where: { Calendar.current.isDateInToday($0.createdAt) && !$0.actionStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.actionStep
            ?? package?.suggestedSteps.first
            ?? TendWidgetSnapshot.empty.todayStep,
            maxLength: 60
        )

        let snapshot = TendWidgetSnapshot(
            hasActiveJourney: true,
            activeJourneyTitle: compact(activeJourney.title, maxLength: 42),
            scriptureSnippet: scriptureSnippet,
            todayStep: todayStep,
            streakCount: streakCount(for: entries),
            updatedAt: now
        )

        publishWidgetSnapshot(snapshot)
    }

    private static func compact(_ value: String, maxLength: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        return String(trimmed.prefix(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func streakCount(for entries: [PrayerEntry]) -> Int {
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
