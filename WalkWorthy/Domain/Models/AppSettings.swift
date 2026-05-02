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
    var widgetJourneyIDRaw: String?
    var firstTendCompletedAt: Date?
    var reviewPromptShownAfterFirstTendAt: Date?
    var paywallShownAfterFirstTendAt: Date?
    var paywallDismissedAt: Date?
    var reviewSecondDayPromptedAt: Date?
    var reviewStage2PromptedAt: Date?
    var reviewNativePromptRequestedAt: Date?
    var reviewPromptSuppressedAt: Date?
    var appOpenHourHistogramRaw: String?
    var lastAppOpenAt: Date?

    init(
        id: UUID = UUID(),
        firstLaunchAt: Date = .now,
        totalSessions: Int = 0,
        pendingPaywallReason: String? = nil,
        lastSessionDate: Date? = nil,
        preferredReminderHour: Int = 8,
        preferredReminderMinute: Int = 0,
        scriptureSourcePolicy: String = "ai-generated-snippets-no-source-disclosure",
        widgetJourneyIDRaw: String? = nil,
        firstTendCompletedAt: Date? = nil,
        reviewPromptShownAfterFirstTendAt: Date? = nil,
        paywallShownAfterFirstTendAt: Date? = nil,
        paywallDismissedAt: Date? = nil,
        reviewSecondDayPromptedAt: Date? = nil,
        reviewStage2PromptedAt: Date? = nil,
        reviewNativePromptRequestedAt: Date? = nil,
        reviewPromptSuppressedAt: Date? = nil,
        appOpenHourHistogramRaw: String? = nil,
        lastAppOpenAt: Date? = nil
    ) {
        self.id = id
        self.firstLaunchAt = firstLaunchAt
        self.totalSessions = totalSessions
        self.pendingPaywallReason = pendingPaywallReason
        self.lastSessionDate = lastSessionDate
        self.preferredReminderHour = preferredReminderHour
        self.preferredReminderMinute = preferredReminderMinute
        self.scriptureSourcePolicy = scriptureSourcePolicy
        self.widgetJourneyIDRaw = widgetJourneyIDRaw
        self.firstTendCompletedAt = firstTendCompletedAt
        self.reviewPromptShownAfterFirstTendAt = reviewPromptShownAfterFirstTendAt
        self.paywallShownAfterFirstTendAt = paywallShownAfterFirstTendAt
        self.paywallDismissedAt = paywallDismissedAt
        self.reviewSecondDayPromptedAt = reviewSecondDayPromptedAt
        self.reviewStage2PromptedAt = reviewStage2PromptedAt
        self.reviewNativePromptRequestedAt = reviewNativePromptRequestedAt
        self.reviewPromptSuppressedAt = reviewPromptSuppressedAt
        self.appOpenHourHistogramRaw = appOpenHourHistogramRaw
        self.lastAppOpenAt = lastAppOpenAt
    }

    var widgetJourneyID: UUID? {
        get {
            guard let widgetJourneyIDRaw, !widgetJourneyIDRaw.isEmpty else { return nil }
            return UUID(uuidString: widgetJourneyIDRaw)
        }
        set {
            widgetJourneyIDRaw = newValue?.uuidString
        }
    }

    var isFirstTendCompleted: Bool {
        firstTendCompletedAt != nil
    }

    var isReviewEligibleAfterFirstTend: Bool {
        false
    }

    var isPaywallEligibleAfterFirstTend: Bool {
        isFirstTendCompleted &&
        paywallShownAfterFirstTendAt == nil
    }

    func markFirstTendCompleted(now: Date = .now) {
        guard firstTendCompletedAt == nil else { return }
        firstTendCompletedAt = now
    }

    func markReviewPromptShownAfterFirstTend(now: Date = .now) {
        reviewPromptShownAfterFirstTendAt = now
    }

    func markReviewSecondDayPrompted(now: Date = .now) {
        guard reviewSecondDayPromptedAt == nil else { return }
        reviewSecondDayPromptedAt = now
    }

    func markReviewStage2Prompted(now: Date = .now) {
        guard reviewStage2PromptedAt == nil else { return }
        reviewStage2PromptedAt = now
    }

    func markReviewNativePromptRequested(now: Date = .now) {
        guard reviewNativePromptRequestedAt == nil else { return }
        reviewNativePromptRequestedAt = now
        markReviewPromptSuppressed(now: now)
    }

    func markReviewPromptSuppressed(now: Date = .now) {
        guard reviewPromptSuppressedAt == nil else { return }
        reviewPromptSuppressedAt = now
    }

    func markPaywallShownAfterFirstTend(now: Date = .now) {
        guard paywallShownAfterFirstTendAt == nil else { return }
        paywallShownAfterFirstTendAt = now
    }

    func markPaywallDismissed(now: Date = .now) {
        paywallDismissedAt = now
    }

    func clearPaywallDismissed() {
        paywallDismissedAt = nil
    }

    var appOpenHourHistogram: [Int] {
        get {
            let parsed = (appOpenHourHistogramRaw ?? "")
                .split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            if parsed.count == 24 {
                return parsed.map { max(0, $0) }
            }
            return Array(repeating: 0, count: 24)
        }
        set {
            let normalized = Array(newValue.prefix(24)).map { max(0, $0) }
            let padded = normalized + Array(repeating: 0, count: max(0, 24 - normalized.count))
            appOpenHourHistogramRaw = padded.map(String.init).joined(separator: ",")
        }
    }
}
