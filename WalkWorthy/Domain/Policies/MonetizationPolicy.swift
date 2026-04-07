import Foundation

enum MonetizationPolicy {
    private static let dismissGracePeriodDays = 3

    static func requiresPaywall(
        hasPremium: Bool,
        settings: AppSettings?,
        paywallMode: PaywallMode = .firstTendReviewThenPaywall,
        now: Date = .now
    ) -> Bool {
        guard !hasPremium else { return false }
        guard let settings else { return false }
        _ = now

        switch paywallMode {
        case .disabled:
            return false
        case .firstTendReviewThenPaywall:
            return settings.isPaywallEligibleAfterFirstTend
                || requiresHardPaywallAfterDismiss(
                    settings: settings,
                    paywallMode: paywallMode,
                    now: now
                )
        case .sessionGate:
            // Session-gated paywall is disabled; onboarding-first flow is the only supported gate.
            return false
        }
    }

    static func requiresHardPaywallAfterDismiss(
        settings: AppSettings?,
        paywallMode: PaywallMode = .firstTendReviewThenPaywall,
        now: Date = .now
    ) -> Bool {
        guard paywallMode != .disabled else { return false }
        guard let settings, let dismissedAt = settings.paywallDismissedAt else { return false }
        guard let hardGateAt = Calendar.current.date(byAdding: .day, value: dismissGracePeriodDays, to: dismissedAt) else {
            return false
        }
        return now >= hardGateAt
    }
}
