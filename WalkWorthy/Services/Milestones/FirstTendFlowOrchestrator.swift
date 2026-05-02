import Foundation

enum FirstTendFlowNextStep: Equatable {
    case none
    case paywall
}

enum FirstTendFlowOrchestrator {
    static func nextStep(
        settings: AppSettings?,
        isPremium: Bool,
        paywallMode: PaywallMode,
        now: Date = .now
    ) -> FirstTendFlowNextStep {
        guard !isPremium else { return .none }
        guard let settings else { return .none }

        switch paywallMode {
        case .disabled:
            return .none
        case .sessionGate:
            return MonetizationPolicy.requiresPaywall(
                hasPremium: isPremium,
                settings: settings,
                paywallMode: .sessionGate,
                now: now
            ) ? .paywall : .none
        case .firstTendReviewThenPaywall:
            guard settings.isFirstTendCompleted else { return .none }
            _ = now

            if settings.paywallShownAfterFirstTendAt == nil {
                return .paywall
            }

            return .none
        }
    }
}
