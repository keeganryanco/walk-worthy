import Foundation

enum AppConstants {
    static let appName = "Tend"
    static let subtitle = "pray. act. grow."
    static let supportEmail = "keegan.ryan@keeganryan.co"

    enum Subscription {
        static let weeklyProductID = "co.keeganryan.tend.premium.weekly"
        static let annualProductID = "co.keeganryan.tend.premium.annual"
        static let weeklyDisplayFallback = "$7.99 / week"
        static let annualDisplayFallback = "$34.99 / year"
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
            Bundle.main.object(forInfoDictionaryKey: "POSTHOGHost") as? String ?? ""
        }
    }
}

enum PaywallTriggerReason: String {
    case sessionCount
    case secondJourney
    case timelineAccess
}
