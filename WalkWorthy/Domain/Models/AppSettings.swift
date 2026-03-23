import Foundation
import SwiftData

@Model
final class AppSettings {
    @Attribute(.unique) var id: UUID
    var firstLaunchAt: Date
    var totalSessions: Int
    var pendingPaywallReason: String?
    var lastSessionDate: Date?
    var preferredReminderHour: Int
    var preferredReminderMinute: Int
    var scriptureSourcePolicy: String
    var firstTendCompletedAt: Date?
    var reviewPromptShownAfterFirstTendAt: Date?

    init(
        id: UUID = UUID(),
        firstLaunchAt: Date = .now,
        totalSessions: Int = 0,
        pendingPaywallReason: String? = nil,
        lastSessionDate: Date? = nil,
        preferredReminderHour: Int = 8,
        preferredReminderMinute: Int = 0,
        scriptureSourcePolicy: String = "ai-generated-snippets-no-source-disclosure",
        firstTendCompletedAt: Date? = nil,
        reviewPromptShownAfterFirstTendAt: Date? = nil
    ) {
        self.id = id
        self.firstLaunchAt = firstLaunchAt
        self.totalSessions = totalSessions
        self.pendingPaywallReason = pendingPaywallReason
        self.lastSessionDate = lastSessionDate
        self.preferredReminderHour = preferredReminderHour
        self.preferredReminderMinute = preferredReminderMinute
        self.scriptureSourcePolicy = scriptureSourcePolicy
        self.firstTendCompletedAt = firstTendCompletedAt
        self.reviewPromptShownAfterFirstTendAt = reviewPromptShownAfterFirstTendAt
    }

    var isFirstTendCompleted: Bool {
        firstTendCompletedAt != nil
    }

    var isReviewEligibleAfterFirstTend: Bool {
        isFirstTendCompleted && reviewPromptShownAfterFirstTendAt == nil
    }

    func markFirstTendCompleted(now: Date = .now) {
        guard firstTendCompletedAt == nil else { return }
        firstTendCompletedAt = now
    }

    func markReviewPromptShownAfterFirstTend(now: Date = .now) {
        reviewPromptShownAfterFirstTendAt = now
    }
}
