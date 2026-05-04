import Foundation

enum AppConstants {
    static let appName = "Tend"
    static let subtitle = "Prayer for what you're facing."
    static let supportEmail = "tend@keeganryan.co"
    static let termsURL = "https://walk-worthy-kohl.vercel.app/terms"
    static let privacyURL = "https://walk-worthy-kohl.vercel.app/privacy"
    static let supportURL = "https://walk-worthy-kohl.vercel.app/support"
    static let appGroupID = "group.co.keeganryan.tend"

    enum DeepLink {
        static let scheme = "tend"
        static let homeHost = "home"
        static let journeyQueryKey = "journey"
        static let actionQueryKey = "action"
        static let reigniteActionValue = "reignite"
        static let pendingJourneyStorageKey = "TEND_PENDING_HOME_JOURNEY_ID"
        static let pendingActionStorageKey = "TEND_PENDING_HOME_ACTION"
    }

    enum Widget {
        static let snapshotKind = "TendSnapshotWidget"
    }

    enum Subscription {
        static let monthlyProductID = "co.keeganryan.tend.premium.monthly"
        static let annualProductID = "co.keeganryan.tend.premium.annual"
        static let monthlyDisplayFallback = "$7.99 / month"
        static let annualDisplayFallback = "$49.99 / year"
        static var revenueCatPublicSDKKey: String {
            Bundle.main.object(forInfoDictionaryKey: "RevenueCatPublicSDKKey") as? String ?? ""
        }

        static var revenueCatEntitlementID: String {
            Bundle.main.object(forInfoDictionaryKey: "RevenueCatEntitlementID") as? String ?? "premium"
        }
    }

    enum AI {
        static var gatewayBaseURLString: String {
            let raw = (Bundle.main.object(forInfoDictionaryKey: "TENDAIBaseURL") as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { return "" }

            if raw.contains("://") {
                return raw
            }

            if raw == "https:" || raw == "http:" {
                // Common xcconfig pitfall when using https:// directly (// treated as comment).
                return ""
            }

            return "https://\(raw)"
        }

        static var gatewayAppKey: String {
            Bundle.main.object(forInfoDictionaryKey: "TENDAIAppKey") as? String ?? ""
        }
    }

    enum Analytics {
        static var posthogProjectKey: String {
            Bundle.main.object(forInfoDictionaryKey: "POSTHOGAPIKey") as? String ?? ""
        }

        static var posthogHost: String {
            let raw = (Bundle.main.object(forInfoDictionaryKey: "POSTHOGHost") as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if raw.isEmpty {
                return "https://us.i.posthog.com"
            }

            if raw == "https:" || raw == "http:" {
                // Common xcconfig pitfall when using https:// directly (// treated as comment).
                return "https://us.i.posthog.com"
            }

            if raw.contains("://") {
                return raw
            }

            return "https://\(raw)"
        }
    }

    enum Debug {
        static let bypassPaywallOverrideStorageKey = "TEND_DEBUG_BYPASS_PAYWALL_OVERRIDE"
        static let fastDayTestingOverrideStorageKey = "TEND_DEBUG_FAST_DAY_OVERRIDE"
        static let fastDayOffsetStorageKey = "TEND_DEBUG_FAST_DAY_OFFSET"
        private static let testEnableFlag = "TEND_DEBUG_TESTING"
        private static let bypassFlag = "TEND_BYPASS_PAYWALL"
        private static let fastDaysFlag = "TEND_FAST_DAYS"

        private static func normalized(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        private static func truthy(_ value: String?) -> Bool {
            guard let value else { return false }
            switch normalized(value) {
            case "1", "true", "yes", "on":
                return true
            default:
                return false
            }
        }

        private static func canonicalFlagName(_ rawValue: String) -> String {
            let normalizedDashes = rawValue
                .replacingOccurrences(of: "—", with: "-")
                .replacingOccurrences(of: "–", with: "-")
                .replacingOccurrences(of: "−", with: "-")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            var trimmed = normalizedDashes
            while let first = trimmed.first, first == "-" || first == "_" {
                trimmed.removeFirst()
            }

            return trimmed
                .replacingOccurrences(of: "-", with: "_")
                .uppercased()
        }

        private static func hasTruthyArgument(_ flagName: String) -> Bool {
            let processInfo = ProcessInfo.processInfo
            let rawArgs = processInfo.arguments
            let expected = canonicalFlagName(flagName)

            for (index, rawArg) in rawArgs.enumerated() {
                let arg = rawArg.trimmingCharacters(in: .whitespacesAndNewlines)
                if let equalsIndex = arg.firstIndex(of: "=") {
                    let key = String(arg[..<equalsIndex])
                    let value = String(arg[arg.index(after: equalsIndex)...])
                    if canonicalFlagName(key) == expected, truthy(value) {
                        return true
                    }
                    continue
                }

                let canonical = canonicalFlagName(arg)
                if canonical == expected {
                    // Support both bare flags (`-FLAG`) and value flags (`-FLAG 1`).
                    if index + 1 < rawArgs.count {
                        let next = rawArgs[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                        let nextIsFlagLike = next.hasPrefix("-")
                        if !nextIsFlagLike {
                            return truthy(next)
                        }
                    }
                    return true
                }
            }

            return false
        }

        private static func hasTruthyEnvironmentValue(_ flagName: String) -> Bool {
            let expected = canonicalFlagName(flagName)
            let env = ProcessInfo.processInfo.environment
            for (key, value) in env {
                if canonicalFlagName(key) == expected, truthy(value) {
                    return true
                }
            }
            return false
        }

        private static func isFlagEnabled(_ flagName: String) -> Bool {
            hasTruthyArgument(flagName) || hasTruthyEnvironmentValue(flagName)
        }

        static var bypassPaywall: Bool {
#if DEBUG
            guard debugTestingEnabled else { return false }
            if UserDefaults.standard.bool(forKey: bypassPaywallOverrideStorageKey) {
                return true
            }
            return isFlagEnabled(bypassFlag)
#else
            return false
#endif
        }

        static var fastDayTesting: Bool {
#if DEBUG
            guard debugTestingEnabled else { return false }
            if UserDefaults.standard.bool(forKey: fastDayTestingOverrideStorageKey) {
                return true
            }
            return isFlagEnabled(fastDaysFlag)
#else
            return false
#endif
        }

        static var debugTestingEnabled: Bool {
#if DEBUG
            // If a debug-only feature flag is explicitly enabled, treat debug testing as enabled.
            return isFlagEnabled(testEnableFlag) || isFlagEnabled(bypassFlag) || isFlagEnabled(fastDaysFlag)
#else
            return false
#endif
        }

        static func resetFastDayOffset() {
#if DEBUG
            UserDefaults.standard.removeObject(forKey: fastDayOffsetStorageKey)
#endif
        }
    }
}

enum PaywallTriggerReason: String {
    case sessionCount
    case secondJourney
    case timelineAccess
    case onboardingCompletion
    case paywallDismissOffer
}
