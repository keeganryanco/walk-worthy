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
        hasPremium: Bool,
        activeJourneyCount: Int,
        settings: AppSettings?,
        now: Date = .now
    ) -> JourneyCreationDecision {
        guard isOnline else {
            return .blocked(.noInternet)
        }

        if MonetizationPolicy.requiresPaywall(hasPremium: hasPremium, settings: settings, now: now) {
            return .blocked(.paywallRequired)
        }

        if !MonetizationPolicy.canCreateJourney(hasPremium: hasPremium, activeJourneyCount: activeJourneyCount) {
            return .blocked(.freeTierLimitReached)
        }

        return .allowed
    }
}
