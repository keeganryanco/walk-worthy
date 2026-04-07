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
        static var bypassPaywall: Bool {
#if DEBUG
            let processInfo = ProcessInfo.processInfo
            if processInfo.arguments.contains("-TEND_BYPASS_PAYWALL") {
                return true
            }

            guard let raw = processInfo.environment["TEND_BYPASS_PAYWALL"]?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            else {
                return false
            }

            switch raw {
            case "1", "true", "yes", "on":
                return true
            default:
                return false
            }
#else
            return false
#endif
        }
    }
}

enum PaywallTriggerReason: String {
    case sessionCount
    case secondJourney
    case timelineAccess
    case onboardingCompletion
}
