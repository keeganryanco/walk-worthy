import Foundation

enum MonetizationPolicy {
    static let freeJourneyLimit = 1
    static let sessionPaywallThreshold = 2
    static let noPaywallWindowDays = 3

    static func requiresPaywall(
        hasPremium: Bool,
        settings: AppSettings?,
        now: Date = .now
    ) -> Bool {
        guard !hasPremium else { return false }
        guard let settings else { return false }
        guard !isInNoPaywallWindow(settings: settings, now: now) else { return false }

        if settings.totalSessions >= sessionPaywallThreshold {
            return true
        }

        return settings.pendingPaywallReason != nil
    }

    static func canCreateJourney(hasPremium: Bool, activeJourneyCount: Int) -> Bool {
        hasPremium || activeJourneyCount < freeJourneyLimit
    }

    static func isInNoPaywallWindow(settings: AppSettings, now: Date = .now) -> Bool {
        let cutoff = Calendar.current.date(byAdding: .day, value: noPaywallWindowDays, to: settings.firstLaunchAt) ?? settings.firstLaunchAt
        return now < cutoff
    }
}
