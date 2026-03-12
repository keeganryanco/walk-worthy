import XCTest
@testable import WalkWorthy

final class WalkWorthyTests: XCTestCase {
    func testTemplateGeneratorProducesCard() {
        let generator = TemplateTodayCardGenerator()
        let profile = OnboardingProfile(
            prayerFocus: "Family",
            growthGoal: "Consistency",
            reminderWindow: "Morning",
            blocker: "Distraction"
        )

        let card = generator.generateTodayCard(profile: profile, journeys: [], date: Date(timeIntervalSince1970: 0))

        XCTAssertFalse(card.prayerPrompt.isEmpty)
        XCTAssertFalse(card.actionStep.isEmpty)
        XCTAssertFalse(card.scriptureReference.isEmpty)
        XCTAssertFalse(card.scriptureText.isEmpty)
    }

    func testJourneyLimitPolicyForFreeTier() {
        XCTAssertTrue(MonetizationPolicy.canCreateJourney(hasPremium: false, activeJourneyCount: 0))
        XCTAssertFalse(MonetizationPolicy.canCreateJourney(hasPremium: false, activeJourneyCount: 1))
    }

    func testPaywallRequiredAfterSecondSession() {
        let settings = AppSettings(totalSessions: 2)
        XCTAssertTrue(MonetizationPolicy.requiresPaywall(hasPremium: false, settings: settings))
    }
}
