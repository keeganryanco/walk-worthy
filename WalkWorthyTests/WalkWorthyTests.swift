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
        XCTAssertTrue(
            MonetizationPolicy.requiresPaywall(
                hasPremium: false,
                settings: settings,
                paywallMode: .sessionGate
            )
        )
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
            scriptureReference: "NotAReference",
            scriptureParaphrase: "This is a paraphrase that should still be accepted and trimmed.",
            prayer: "  Lord, guide the user today. ",
            smallStepQuestion: "",
            suggestedSteps: [" ", "Take one concrete step."],
            completionSuggestion: CompletionSuggestion(
                shouldPrompt: true,
                reason: "  Consider marking this complete. ",
                confidence: 2.0
            ),
            generatedAt: .now
        )

        let validated = DailyJourneyPackageValidation.validated(package)

        XCTAssertEqual(validated.scriptureReference, "Philippians 4:6-7")
        XCTAssertEqual(validated.smallStepQuestion, "What small step could you take today?")
        XCTAssertEqual(validated.suggestedSteps.first, "Take one concrete step.")
        XCTAssertEqual(validated.prayer, DailyJourneyPackageValidation.defaultFirstPersonPrayer)
        XCTAssertEqual(validated.completionSuggestion.reason, "Consider marking this complete.")
        XCTAssertEqual(validated.completionSuggestion.confidence, 1.0)
    }

    func testDailyJourneyPackageValidationKeepsFirstPersonPrayer() {
        let package = DailyJourneyPackage(
            reflectionThought: "Stay faithful.",
            scriptureReference: "James 1:5",
            scriptureParaphrase: "God gives wisdom generously.",
            prayer: "Lord, I'm trusting You today. Help me take one faithful step.",
            smallStepQuestion: "What small step could you take today?",
            suggestedSteps: ["Take one faithful action"],
            completionSuggestion: CompletionSuggestion(shouldPrompt: false, reason: "", confidence: 0),
            generatedAt: .now
        )

        let validated = DailyJourneyPackageValidation.validated(package)
        XCTAssertEqual(validated.prayer, "Lord, I'm trusting You today. Help me take one faithful step.")
    }

    func testDailyJourneyPackageValidationAcceptsCanonicalReferenceFormat() {
        let package = DailyJourneyPackage(
            reflectionThought: "Stay faithful.",
            scriptureReference: "1 Corinthians 15:58",
            scriptureParaphrase: "Keep giving yourself fully to faithful work.",
            prayer: "Lord, strengthen me.",
            smallStepQuestion: "What small step could you take today?",
            suggestedSteps: ["Send one message"],
            completionSuggestion: CompletionSuggestion(shouldPrompt: false, reason: "", confidence: 0),
            generatedAt: .now
        )

        let validated = DailyJourneyPackageValidation.validated(package)

        XCTAssertEqual(validated.scriptureReference, "1 Corinthians 15:58")
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

    func testWidgetSnapshotDecodesWithMissingFields() throws {
        let legacyJSON = """
        {
          "hasActiveJourney": true,
          "activeJourneyTitle": "Faith Journey",
          "scriptureSnippet": "Stay faithful."
        }
        """
        let data = Data(legacyJSON.utf8)

        let snapshot = try JSONDecoder().decode(TendWidgetSnapshot.self, from: data)

        XCTAssertTrue(snapshot.hasActiveJourney)
        XCTAssertEqual(snapshot.activeJourneyTitle, "Faith Journey")
        XCTAssertEqual(snapshot.scriptureSnippet, "Stay faithful.")
        XCTAssertEqual(snapshot.todayStep, "Start your first tend")
        XCTAssertEqual(snapshot.streakCount, 0)
    }

    func testFirstTendMilestoneFlagsToggleOnce() {
        let settings = AppSettings()

        XCTAssertFalse(FirstTendMilestoneService.isFirstTendCompleted(settings: settings))
        XCTAssertFalse(FirstTendMilestoneService.isReviewEligibleAfterFirstTend(settings: settings))

        FirstTendMilestoneService.markFirstTendCompleted(settings: settings, now: Date(timeIntervalSince1970: 10))
        XCTAssertTrue(FirstTendMilestoneService.isFirstTendCompleted(settings: settings))
        XCTAssertTrue(FirstTendMilestoneService.isReviewEligibleAfterFirstTend(settings: settings))
        XCTAssertEqual(settings.firstTendCompletedAt, Date(timeIntervalSince1970: 10))

        FirstTendMilestoneService.markFirstTendCompleted(settings: settings, now: Date(timeIntervalSince1970: 20))
        XCTAssertEqual(settings.firstTendCompletedAt, Date(timeIntervalSince1970: 10))

        FirstTendMilestoneService.markReviewPromptShownAfterFirstTend(settings: settings, now: Date(timeIntervalSince1970: 30))
        XCTAssertFalse(FirstTendMilestoneService.isReviewEligibleAfterFirstTend(settings: settings))
    }

    func testFollowThroughGrowthPointsMapping() {
        XCTAssertEqual(
            FollowThroughService.growthPoints(for: nil, hasPriorCommitmentToEvaluate: false),
            1
        )
        XCTAssertEqual(
            FollowThroughService.growthPoints(for: .yes, hasPriorCommitmentToEvaluate: true),
            2
        )
        XCTAssertEqual(
            FollowThroughService.growthPoints(for: .partial, hasPriorCommitmentToEvaluate: true),
            1
        )
        XCTAssertEqual(
            FollowThroughService.growthPoints(for: .no, hasPriorCommitmentToEvaluate: true),
            0
        )
    }

    func testPendingClosureCheckPicksLatestUnansweredCommittedStep() {
        let now = Date(timeIntervalSince1970: 10_000)
        let oldAnswered = PrayerEntry(
            createdAt: now.addingTimeInterval(-86_400 * 3),
            prompt: "p1",
            scriptureReference: "Philippians 4:6-7",
            scriptureText: "t1",
            actionStep: "Send encouragement text",
            completedAt: now.addingTimeInterval(-86_400 * 3),
            followThroughStatus: .yes
        )
        let latestPending = PrayerEntry(
            createdAt: now.addingTimeInterval(-86_400),
            prompt: "p2",
            scriptureReference: "Galatians 6:9",
            scriptureText: "t2",
            actionStep: "Finish one delayed task",
            completedAt: now.addingTimeInterval(-86_400),
            followThroughStatus: .unanswered
        )
        let currentEntry = PrayerEntry(
            createdAt: now,
            prompt: "p3",
            scriptureReference: "James 1:5",
            scriptureText: "t3",
            actionStep: "",
            completedAt: nil,
            followThroughStatus: .unanswered
        )

        let pending = FollowThroughService.pendingClosureCheck(
            in: [oldAnswered, latestPending, currentEntry],
            currentEntryID: currentEntry.id
        )

        XCTAssertEqual(pending?.id, latestPending.id)
    }

    func testValidationPrefersSmallerFallbackChipsAfterNoFollowThrough() {
        let package = DailyJourneyPackage(
            reflectionThought: "Be faithful in small things.",
            scriptureReference: "Philippians 4:6-7",
            scriptureParaphrase: "Bring concerns to God in prayer.",
            prayer: "Lord, help me take one faithful step today.",
            smallStepQuestion: "",
            suggestedSteps: ["to", "and", "for"],
            completionSuggestion: CompletionSuggestion(shouldPrompt: false, reason: "", confidence: 0),
            generatedAt: .now
        )

        let validated = DailyJourneyPackageValidation.validated(
            package,
            followThroughStatus: .no
        )

        XCTAssertEqual(
            Array(validated.suggestedSteps.prefix(3)),
            ["Take one tiny step", "Do a two minute task", "Choose one easier action"]
        )
    }

    func testLatestAnsweredContextIncludesPreviousCommitmentAndStatus() {
        let now = Date(timeIntervalSince1970: 20_000)
        let entry = PrayerEntry(
            createdAt: now.addingTimeInterval(-86_400),
            prompt: "Prompt",
            scriptureReference: "James 1:5",
            scriptureText: "Wisdom snippet",
            actionStep: "Review one key number",
            completedAt: now.addingTimeInterval(-86_400),
            followThroughStatus: .partial,
            followThroughAnsweredAt: now
        )

        let context = FollowThroughService.latestAnsweredContext(from: [entry], now: now)

        XCTAssertEqual(context?.previousCommitmentText, "Review one key number")
        XCTAssertEqual(context?.previousFollowThroughStatus, .partial)
        XCTAssertEqual(context?.daysSinceCommitment, 1)
    }
}
