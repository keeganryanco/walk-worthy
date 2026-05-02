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

enum ReviewPromptMoment: String, Equatable {
    case secondDay
    case plantStage2
}

enum ReviewPromptCoordinator {
    static func nextPrompt(
        settings: AppSettings?,
        completedTendCount: Int,
        didIncreasePlantStage: Bool,
        plantStageAfterCompletion: Int
    ) -> ReviewPromptMoment? {
        guard let settings else { return nil }
        guard settings.reviewPromptSuppressedAt == nil else { return nil }
        guard settings.reviewNativePromptRequestedAt == nil else { return nil }

        if completedTendCount >= 2, settings.reviewSecondDayPromptedAt == nil {
            return .secondDay
        }

        if didIncreasePlantStage,
           plantStageAfterCompletion == 2,
           settings.reviewSecondDayPromptedAt != nil,
           settings.reviewStage2PromptedAt == nil {
            return .plantStage2
        }

        return nil
    }

    static func markPromptShown(_ moment: ReviewPromptMoment, settings: AppSettings?, now: Date = .now) {
        guard let settings else { return }
        switch moment {
        case .secondDay:
            settings.markReviewSecondDayPrompted(now: now)
        case .plantStage2:
            settings.markReviewStage2Prompted(now: now)
        }
    }

    static func markNativePromptRequested(settings: AppSettings?, now: Date = .now) {
        settings?.markReviewNativePromptRequested(now: now)
    }

    static func suppressFuturePrompts(settings: AppSettings?, now: Date = .now) {
        settings?.markReviewPromptSuppressed(now: now)
    }
}
