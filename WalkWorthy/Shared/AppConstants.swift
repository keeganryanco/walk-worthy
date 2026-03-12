import Foundation

enum AppConstants {
    static let appName = "Walk Worthy"
    static let subtitle = "Pray & Do"
    static let supportEmail = "keegan.ryan@keeganryan.co"

    enum Subscription {
        static let annualProductID = "co.keeganryan.walkworthy.premium.annual"
    }
}

enum PaywallTriggerReason: String {
    case sessionCount
    case secondJourney
    case timelineAccess
}
