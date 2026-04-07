import Foundation

enum FirstTendMilestoneService {
    static func isFirstTendCompleted(settings: AppSettings?) -> Bool {
        settings?.isFirstTendCompleted ?? false
    }

    static func isReviewEligibleAfterFirstTend(settings: AppSettings?) -> Bool {
        settings?.isReviewEligibleAfterFirstTend ?? false
    }

    static func isPaywallEligibleAfterFirstTend(settings: AppSettings?) -> Bool {
        settings?.isPaywallEligibleAfterFirstTend ?? false
    }

    static func markFirstTendCompleted(settings: AppSettings?, now: Date = .now) {
        guard let settings else { return }
        guard !settings.isFirstTendCompleted else { return }
        settings.markFirstTendCompleted(now: now)
    }

    static func markReviewPromptShownAfterFirstTend(settings: AppSettings?, now: Date = .now) {
        guard let settings else { return }
        settings.markReviewPromptShownAfterFirstTend(now: now)
    }

    static func markPaywallShownAfterFirstTend(settings: AppSettings?, now: Date = .now) {
        guard let settings else { return }
        settings.markPaywallShownAfterFirstTend(now: now)
    }
}
