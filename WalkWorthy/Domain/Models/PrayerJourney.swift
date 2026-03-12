import Foundation
import SwiftData

@Model
final class PrayerJourney {
    @Attribute(.unique) var id: UUID
    var title: String
    var category: String
    var createdAt: Date
    var isArchived: Bool
    var colorToken: String

    @Relationship(deleteRule: .cascade, inverse: \PrayerEntry.journey)
    var entries: [PrayerEntry]

    @Relationship(deleteRule: .cascade, inverse: \AnsweredPrayer.journey)
    var answeredPrayers: [AnsweredPrayer]

    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        createdAt: Date = .now,
        isArchived: Bool = false,
        colorToken: String = "sage"
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.colorToken = colorToken
        self.entries = []
        self.answeredPrayers = []
    }
}
