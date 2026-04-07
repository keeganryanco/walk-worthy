import Foundation

enum JourneyCreationBlockReason: Equatable {
    case noInternet
    case paywallRequired
    case freeTierLimitReached
}

enum JourneyCreationDecision: Equatable {
    case allowed
    case blocked(JourneyCreationBlockReason)
}

enum JourneyCreationPolicy {
    static func evaluate(
        isOnline: Bool,
        hasPremium _: Bool,
        activeJourneyCount _: Int,
        settings _: AppSettings?,
        paywallMode _: PaywallMode = .firstTendReviewThenPaywall,
        now: Date = .now
    ) -> JourneyCreationDecision {
        _ = now
        guard isOnline else {
            return .blocked(.noInternet)
        }

        return .allowed
    }
}
