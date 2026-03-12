import Foundation
import SwiftData

@Model
final class OnboardingProfile {
    @Attribute(.unique) var id: UUID
    var prayerFocus: String
    var growthGoal: String
    var reminderWindow: String
    var blocker: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        prayerFocus: String,
        growthGoal: String,
        reminderWindow: String,
        blocker: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.prayerFocus = prayerFocus
        self.growthGoal = growthGoal
        self.reminderWindow = reminderWindow
        self.blocker = blocker
        self.createdAt = createdAt
    }
}
