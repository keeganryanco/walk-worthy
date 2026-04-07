import Foundation
import SwiftData

enum JourneyProgressEventType: String, Codable, CaseIterable {
    case packageGenerated
    case stepCompleted
    case followThroughAnswered
    case firstTendCompleted
    case journeyCompleted
}

@Model
final class JourneyProgressEvent {
    @Attribute(.unique) var id: UUID
    var journeyID: UUID
    var createdAt: Date
    var eventTypeRaw: String
    var notes: String

    init(
        id: UUID = UUID(),
        journeyID: UUID,
        createdAt: Date = .now,
        eventTypeRaw: String = JourneyProgressEventType.stepCompleted.rawValue,
        notes: String = ""
    ) {
        self.id = id
        self.journeyID = journeyID
        self.createdAt = createdAt
        self.eventTypeRaw = eventTypeRaw
        self.notes = notes
    }

    var eventType: JourneyProgressEventType {
        get { JourneyProgressEventType(rawValue: eventTypeRaw) ?? .stepCompleted }
        set { eventTypeRaw = newValue.rawValue }
    }
}
