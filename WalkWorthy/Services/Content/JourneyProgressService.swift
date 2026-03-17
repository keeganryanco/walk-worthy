import Foundation
import SwiftData

@MainActor
enum JourneyProgressService {
    static func logEvent(
        journeyID: UUID,
        type: JourneyProgressEventType,
        notes: String = "",
        modelContext: ModelContext,
        date: Date = .now
    ) {
        let event = JourneyProgressEvent(
            journeyID: journeyID,
            createdAt: date,
            eventTypeRaw: type.rawValue,
            notes: notes
        )
        modelContext.insert(event)
        try? modelContext.save()
    }

    static func completionCount(
        for journeyID: UUID,
        modelContext: ModelContext
    ) -> Int {
        let completedTypeRaw = JourneyProgressEventType.stepCompleted.rawValue
        let descriptor = FetchDescriptor<JourneyProgressEvent>(
            predicate: #Predicate {
                $0.journeyID == journeyID &&
                $0.eventTypeRaw == completedTypeRaw
            }
        )
        let events = (try? modelContext.fetch(descriptor)) ?? []
        return events.count
    }
}
