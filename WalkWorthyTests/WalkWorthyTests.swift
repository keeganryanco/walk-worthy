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
        let fourDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: .now) ?? .now
        let settings = AppSettings(firstLaunchAt: fourDaysAgo, totalSessions: 2)
        XCTAssertTrue(MonetizationPolicy.requiresPaywall(hasPremium: false, settings: settings))
    }

    func testNoPaywallDuringFirstThreeDays() {
        let settings = AppSettings(firstLaunchAt: .now, totalSessions: 99)
        XCTAssertFalse(MonetizationPolicy.requiresPaywall(hasPremium: false, settings: settings, now: .now))
    }

    func testJourneyCreationBlockedWhenOffline() {
        let fourDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: .now) ?? .now
        let settings = AppSettings(firstLaunchAt: fourDaysAgo, totalSessions: 0)
        let decision = JourneyCreationPolicy.evaluate(
            isOnline: false,
            hasPremium: false,
            activeJourneyCount: 0,
            settings: settings
        )

        XCTAssertEqual(decision, .blocked(.noInternet))
    }

    func testDailyJourneyPackageValidationFallsBackToApprovedReference() {
        let package = DailyJourneyPackage(
            reflectionThought: "  Be faithful today. ",
            scriptureReference: "Unknown 1:1",
            scriptureParaphrase: "This is a paraphrase that should still be accepted and trimmed.",
            prayer: "  Lord, guide me. ",
            smallStepQuestion: "",
            suggestedSteps: [" ", "Take one concrete step."],
            generatedAt: .now
        )

        let validated = DailyJourneyPackageValidation.validated(package)

        XCTAssertEqual(validated.scriptureReference, "Philippians 4:6-7")
        XCTAssertEqual(validated.smallStepQuestion, "What small step could you take today?")
        XCTAssertEqual(validated.suggestedSteps, ["Take one concrete step."])
        XCTAssertEqual(validated.prayer, "Lord, guide me.")
    }

    func testDayKeyFormattingIsStable() {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 17
        components.hour = 12
        let date = Calendar.current.date(from: components) ?? .now
        XCTAssertEqual(JourneyContentService.dayKey(for: date), "2026-03-17")
    }
}
