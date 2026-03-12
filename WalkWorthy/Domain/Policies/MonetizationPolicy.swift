import Foundation

enum MonetizationPolicy {
    static let freeJourneyLimit = 1
    static let sessionPaywallThreshold = 2

    static func requiresPaywall(
        hasPremium: Bool,
        settings: AppSettings?
    ) -> Bool {
        guard !hasPremium else { return false }
        guard let settings else { return false }

        if settings.totalSessions >= sessionPaywallThreshold {
            return true
        }

        return settings.pendingPaywallReason != nil
    }

    static func canCreateJourney(hasPremium: Bool, activeJourneyCount: Int) -> Bool {
        hasPremium || activeJourneyCount < freeJourneyLimit
    }
}
