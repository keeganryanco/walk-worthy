import Foundation
import SwiftData

@Model
final class PrayerEntry {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var prompt: String
    var scriptureReference: String
    var scriptureText: String
    var actionStep: String
    var userReflection: String
    var completedAt: Date?

    var journey: PrayerJourney?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        prompt: String,
        scriptureReference: String,
        scriptureText: String,
        actionStep: String,
        userReflection: String = "",
        completedAt: Date? = nil,
        journey: PrayerJourney? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.prompt = prompt
        self.scriptureReference = scriptureReference
        self.scriptureText = scriptureText
        self.actionStep = actionStep
        self.userReflection = userReflection
        self.completedAt = completedAt
        self.journey = journey
    }
}
