import Foundation

enum AppConstants {
    static let appName = "Tend"
    static let subtitle = "pray. act. grow."
    static let supportEmail = "keegan.ryan@keeganryan.co"

    enum Subscription {
        static let weeklyProductID = "co.keeganryan.tend.premium.weekly"
        static let annualProductID = "co.keeganryan.tend.premium.annual"
        static let weeklyDisplayFallback = "$5.99 / week"
        static let annualDisplayFallback = "$35.00 / year"
    }
}

enum PaywallTriggerReason: String {
    case sessionCount
    case secondJourney
    case timelineAccess
}
