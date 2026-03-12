import Foundation
import SwiftData

@Model
final class AnsweredPrayer {
    @Attribute(.unique) var id: UUID
    var notes: String
    var date: Date
    var linkedEntryID: UUID?

    var journey: PrayerJourney?

    init(
        id: UUID = UUID(),
        notes: String,
        date: Date = .now,
        linkedEntryID: UUID? = nil,
        journey: PrayerJourney? = nil
    ) {
        self.id = id
        self.notes = notes
        self.date = date
        self.linkedEntryID = linkedEntryID
        self.journey = journey
    }
}
