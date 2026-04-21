import Foundation

enum AppConstants {
    static let appName = "Tend"
    static let subtitle = "pray. act. grow."
    static let supportEmail = "tend@keeganryan.co"
    static let termsURL = "https://walk-worthy-kohl.vercel.app/terms"
    static let privacyURL = "https://walk-worthy-kohl.vercel.app/privacy"
    static let supportURL = "https://walk-worthy-kohl.vercel.app/support"
    static let appGroupID = "group.co.keeganryan.tend"

    enum DeepLink {
        static let scheme = "tend"
        static let homeHost = "home"
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

        private static func hasTruthyArgument(_ argument: String) -> Bool {
            let processInfo = ProcessInfo.processInfo
            let rawArgs = processInfo.arguments
            let candidates = [
                argument,
                argument.replacingOccurrences(of: "-", with: ""),
                argument.replacingOccurrences(of: "-", with: "_"),
                argument.replacingOccurrences(of: "-", with: "_").trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            ]
                .map { $0.lowercased() }

            for rawArg in rawArgs {
                let arg = rawArg.trimmingCharacters(in: .whitespacesAndNewlines)
                let lowered = arg.lowercased()
                if candidates.contains(lowered) {
                    return true
                }
                if let equalsIndex = lowered.firstIndex(of: "=") {
                    let key = String(lowered[..<equalsIndex])
                    let value = String(lowered[lowered.index(after: equalsIndex)...])
                    if candidates.contains(key), truthy(value) {
                        return true
                    }
                }
            }

            return false
        }

        private static func hasTruthyEnvironmentValue(_ keys: [String]) -> Bool {
            let env = ProcessInfo.processInfo.environment
            for key in keys {
                if truthy(env[key]) {
                    return true
                }
            }
            return false
        }

        private static func isEnabled(
            argument: String,
            environmentKey: String
        ) -> Bool {
            if hasTruthyArgument(argument) {
                return true
            }

            if hasTruthyEnvironmentValue([
                environmentKey,
                argument,
                environmentKey.replacingOccurrences(of: "_", with: "-"),
                "-\(environmentKey)"
            ]) {
                return true
            }

            return false
        }

        static var bypassPaywall: Bool {
#if DEBUG
            if UserDefaults.standard.bool(forKey: bypassPaywallOverrideStorageKey) {
                return true
            }
            return isEnabled(argument: "-TEND_BYPASS_PAYWALL", environmentKey: "TEND_BYPASS_PAYWALL")
#else
            return false
#endif
        }

        static var fastDayTesting: Bool {
#if DEBUG
            if UserDefaults.standard.bool(forKey: fastDayTestingOverrideStorageKey) {
                return true
            }
            return isEnabled(argument: "-TEND_FAST_DAYS", environmentKey: "TEND_FAST_DAYS")
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
