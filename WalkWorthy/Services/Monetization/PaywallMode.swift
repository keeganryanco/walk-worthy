import Foundation

enum PaywallMode: String, Codable, CaseIterable {
    case disabled
    case firstTendReviewThenPaywall
    case sessionGate

    static func fromRevenueCatMetadata(_ rawValue: String?) -> PaywallMode? {
        let normalized = rawValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        guard !normalized.isEmpty else { return nil }

        switch normalized {
        case "disabled", "off", "free_forever", "freeforever", "none":
            return .disabled
        case "first_tend_review_then_paywall", "firsttendreviewthenpaywall", "first_tend", "post_tend":
            return .firstTendReviewThenPaywall
        case "session_gate", "sessiongate":
            return .sessionGate
        default:
            return nil
        }
    }

    static func fromRevenueCatOfferingIdentifier(_ identifier: String?) -> PaywallMode {
        let normalized = identifier?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        guard !normalized.isEmpty else {
            // Safe default when RevenueCat configuration is unavailable.
            return .disabled
        }

        if normalized.contains("off") || normalized.contains("disabled") || normalized.contains("free_forever") {
            return .disabled
        }

        if normalized.contains("session") {
            return .sessionGate
        }

        if normalized.contains("first_tend") || normalized.contains("post_tend") || normalized.contains("review_then_paywall") {
            return .firstTendReviewThenPaywall
        }

        // Default mode for active monetization offerings.
        return .firstTendReviewThenPaywall
    }
}
