import Foundation

enum AppConstants {
    static let appName = "Walk Worthy"
    static let subtitle = "Pray & Do"
    static let supportEmail = "keegan.ryan@keeganryan.co"

    enum Subscription {
        static let weeklyProductID = "co.keeganryan.walkworthy.premium.weekly"
        static let annualProductID = "co.keeganryan.walkworthy.premium.annual"
        static let weeklyDisplayFallback = "$5.99 / week"
        static let annualDisplayFallback = "$35.00 / year"
    }
}

enum PaywallTriggerReason: String {
    case sessionCount
    case secondJourney
    case timelineAccess
}
