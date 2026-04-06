import Foundation
import SwiftData

@Model
final class ReminderSchedule {
    @Attribute(.unique) var id: UUID
    var hour: Int
    var minute: Int
    var isEnabled: Bool
    var sortOrder: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        hour: Int,
        minute: Int,
        isEnabled: Bool = true,
        sortOrder: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }

    var normalizedHour: Int {
        min(max(hour, 0), 23)
    }

    var normalizedMinute: Int {
        min(max(minute, 0), 59)
    }
}
