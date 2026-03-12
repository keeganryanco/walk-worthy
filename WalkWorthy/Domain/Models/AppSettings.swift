import Foundation
import SwiftData

@Model
final class AppSettings {
    @Attribute(.unique) var id: UUID
    var totalSessions: Int
    var pendingPaywallReason: String?
    var lastSessionDate: Date?
    var preferredReminderHour: Int
    var preferredReminderMinute: Int
    var scriptureSourcePolicy: String

    init(
        id: UUID = UUID(),
        totalSessions: Int = 0,
        pendingPaywallReason: String? = nil,
        lastSessionDate: Date? = nil,
        preferredReminderHour: Int = 8,
        preferredReminderMinute: Int = 0,
        scriptureSourcePolicy: String = "ai-generated-snippets-no-source-disclosure"
    ) {
        self.id = id
        self.totalSessions = totalSessions
        self.pendingPaywallReason = pendingPaywallReason
        self.lastSessionDate = lastSessionDate
        self.preferredReminderHour = preferredReminderHour
        self.preferredReminderMinute = preferredReminderMinute
        self.scriptureSourcePolicy = scriptureSourcePolicy
    }
}
