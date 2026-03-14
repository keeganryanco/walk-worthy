import Foundation
import SwiftData

@Model
final class OnboardingProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var ageRange: String
    var prayerFocus: String
    var growthGoal: String
    var reminderWindow: String
    var blocker: String
    var supportCadence: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        ageRange: String = "",
        prayerFocus: String,
        growthGoal: String,
        reminderWindow: String,
        blocker: String,
        supportCadence: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.ageRange = ageRange
        self.prayerFocus = prayerFocus
        self.growthGoal = growthGoal
        self.reminderWindow = reminderWindow
        self.blocker = blocker
        self.supportCadence = supportCadence
        self.createdAt = createdAt
    }
}
