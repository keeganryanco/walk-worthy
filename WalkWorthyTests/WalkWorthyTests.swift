import XCTest
import SwiftData
@testable import WalkWorthy

final class WalkWorthyTests: XCTestCase {
    @MainActor
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([
            PrayerJourney.self,
            PrayerEntry.self,
            AnsweredPrayer.self,
            OnboardingProfile.self,
            AppSettings.self,
            ReminderSchedule.self,
            JourneyMemorySnapshot.self,
            GlobalLightMemory.self,
            JourneyProgressEvent.self,
            DailyJourneyPackageRecord.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private final class CountingRemoteProvider: RemoteDailyJourneyPackageProviding {
        var calls = 0
        let package: DailyJourneyPackage

        init(package: DailyJourneyPackage = WalkWorthyTests.validRemotePackage()) {
            self.package = package
        }

        func generatePackage(
            profile: OnboardingProfile,
            journey: PrayerJourney,
            recentEntries: [PrayerEntry],
            memory: JourneyMemorySnapshot?
        ) async throws -> DailyJourneyPackage {
            calls += 1
            try? await Task.sleep(nanoseconds: 120_000_000)
            return package
        }
    }

    private struct FailingRemoteProvider: RemoteDailyJourneyPackageProviding {
        func generatePackage(
            profile: OnboardingProfile,
            journey: PrayerJourney,
            recentEntries: [PrayerEntry],
            memory: JourneyMemorySnapshot?
        ) async throws -> DailyJourneyPackage {
            throw NSError(domain: "test", code: -1)
        }
    }

    private static func validRemotePackage() -> DailyJourneyPackage {
        DailyJourneyPackage(
            dailyTitle: "Bringing Worry to God",
            reflectionThought: "Paul teaches that anxious thoughts can be brought honestly before God. Prayer is not a way to deny fear, but a way to place fear before the One who gives peace. An exam can feel heavy when the result seems to carry too much weight. God's peace guards the heart by reminding it that a test is real, but it is not ultimate.",
            scriptureReference: "Philippians 4:6-7",
            scriptureParaphrase: "Do not be anxious about anything, but bring every concern to God in prayer with thanksgiving. The peace of God will guard your heart and mind in Christ Jesus.",
            prayer: "Lord, I bring my anxiety about this test to You. Help me study with focus and rest without fear. Remind me that my future is held by You, not by one score.",
            todayAim: "bring test anxiety to God with honesty",
            smallStepQuestion: "What is one focused way to prepare today?",
            suggestedSteps: ["Review one section", "Pray over one fear", "Take a short break", "Pack test supplies"],
            completionSuggestion: CompletionSuggestion(shouldPrompt: false, reason: "", confidence: 0),
            qualityVersion: DailyJourneyPackage.currentQualityVersion,
            generatedAt: Date(timeIntervalSince1970: 100)
        )
    }

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

    func testJourneyCreationAllowedWhenOnline() {
        let decision = JourneyCreationPolicy.evaluate(
            isOnline: true,
            hasPremium: false,
            activeJourneyCount: 1,
            settings: AppSettings()
        )
        XCTAssertEqual(decision, .allowed)
    }

    func testSessionGatePaywallModeIsDisabled() {
        let fourDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: .now) ?? .now
        let settings = AppSettings(firstLaunchAt: fourDaysAgo, totalSessions: 2)
        XCTAssertFalse(
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

    @MainActor
    func testWarmupDedupesRepeatedRequestsForSameJourneyAndDay() async throws {
        let context = try makeInMemoryContext()
        let profile = OnboardingProfile(name: "Friend", prayerFocus: "ACT anxiety", growthGoal: "peace", reminderWindow: "Morning", blocker: "")
        let journey = PrayerJourney(title: "ACT Peace", category: "School", growthFocus: "ACT anxiety")
        context.insert(profile)
        context.insert(journey)
        try context.save()

        let remote = CountingRemoteProvider()
        let content = JourneyContentService(remoteProvider: remote)
        let warmup = JourneyPackageWarmupService(contentService: content)
        let date = Date(timeIntervalSince1970: 1_800_000_000)

        async let first: Void = warmup.warmToday(
            profile: profile,
            journey: journey,
            entries: [],
            memory: nil,
            isOnline: true,
            modelContext: context,
            date: date
        )
        async let second: Void = warmup.warmToday(
            profile: profile,
            journey: journey,
            entries: [],
            memory: nil,
            isOnline: true,
            modelContext: context,
            date: date
        )
        _ = await (first, second)

        XCTAssertEqual(remote.calls, 1)
    }

    @MainActor
    func testPackageForDateUsesCurrentCacheBeforeRemote() async throws {
        let context = try makeInMemoryContext()
        let profile = OnboardingProfile(name: "Friend", prayerFocus: "ACT anxiety", growthGoal: "peace", reminderWindow: "Morning", blocker: "")
        let journey = PrayerJourney(title: "ACT Peace", category: "School", growthFocus: "ACT anxiety")
        let dayKey = JourneyContentService.dayKey(for: Date(timeIntervalSince1970: 1_800_000_000))
        context.insert(profile)
        context.insert(journey)
        context.insert(DailyJourneyPackageRecord(
            journeyID: journey.id,
            dayKey: dayKey,
            dailyTitle: "Cached Title",
            reflectionThought: "Cached reflection.",
            scriptureReference: "Philippians 4:6-7",
            scriptureParaphrase: "Cached scripture.",
            prayer: "Lord, help me.",
            todayAim: "cached aim",
            smallStepQuestion: "What can you prepare?",
            suggestedSteps: ["Review one section"],
            completionSuggestion: CompletionSuggestion(shouldPrompt: false, reason: "", confidence: 0),
            qualityVersion: DailyJourneyPackage.currentQualityVersion,
            generatedAt: .now,
            source: .remote
        ))
        try context.save()

        let remote = CountingRemoteProvider()
        let result = await JourneyContentService(remoteProvider: remote).packageForDate(
            profile: profile,
            journey: journey,
            recentEntries: [],
            memory: nil,
            date: Date(timeIntervalSince1970: 1_800_000_000),
            isOnline: true,
            modelContext: context
        )

        XCTAssertEqual(result.source, .cache)
        XCTAssertEqual(result.package.dailyTitle, "Cached Title")
        XCTAssertEqual(remote.calls, 0)
    }

    @MainActor
    func testOnlineRemoteFailureDoesNotPersistTemplatePackage() async throws {
        let context = try makeInMemoryContext()
        let profile = OnboardingProfile(name: "Friend", prayerFocus: "ACT anxiety", growthGoal: "peace", reminderWindow: "Morning", blocker: "")
        let journey = PrayerJourney(title: "ACT Peace", category: "School", growthFocus: "ACT anxiety")
        context.insert(profile)
        context.insert(journey)
        try context.save()

        let result = await JourneyContentService(remoteProvider: FailingRemoteProvider()).packageForDate(
            profile: profile,
            journey: journey,
            recentEntries: [],
            memory: nil,
            date: Date(timeIntervalSince1970: 1_800_000_000),
            isOnline: true,
            modelContext: context
        )

        let records = try context.fetch(FetchDescriptor<DailyJourneyPackageRecord>())
        XCTAssertEqual(result.source, .template)
        XCTAssertTrue(records.isEmpty)
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

    func testDailyJourneyPackageValidationRemovesNearDuplicateSuggestedSteps() {
        let package = DailyJourneyPackage(
            reflectionThought: "Scripture names fear honestly and points toward a steadier mind. A test can feel large without becoming ultimate. God cares about the pressure carried into that moment. Calm grows when fear is brought into the light.",
            scriptureReference: "2 Timothy 1:7",
            scriptureParaphrase: "God has not given us a spirit of fear, but of power, love, and self-control.",
            prayer: "Father, I bring You the fear I feel about this test. Give me a clear mind and a steady heart. Help me trust Your presence more than this pressure.",
            smallStepQuestion: "How will you pause for calm before your test?",
            suggestedSteps: [
                "Pray through this worry",
                "Take five calm breaths",
                "Pray through one worry",
                "Pray through this specific worry"
            ],
            completionSuggestion: CompletionSuggestion(shouldPrompt: false, reason: "", confidence: 0),
            generatedAt: .now
        )

        let validated = DailyJourneyPackageValidation.validated(package)

        XCTAssertTrue(validated.suggestedSteps.contains("Pray through this worry"))
        XCTAssertTrue(validated.suggestedSteps.contains("Take five calm breaths"))
        XCTAssertFalse(validated.suggestedSteps.contains("Pray through one worry"))
        XCTAssertFalse(validated.suggestedSteps.contains("Pray through this specific worry"))
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

    func testAdaptiveSendTimeUsesAllowedWindowAndAvoidsReminderProximity() {
        let settings = AppSettings()
        var histogram = Array(repeating: 0, count: 24)
        histogram[10] = 9
        histogram[18] = 7
        settings.appOpenHourHistogram = histogram

        let selector = AdaptiveSendTimeSelector(
            calendar: Calendar(identifier: .gregorian),
            allowedHours: 9...20
        )
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 22
        components.hour = 8
        components.minute = 30
        let now = Calendar(identifier: .gregorian).date(from: components) ?? .now
        let day = Calendar(identifier: .gregorian).startOfDay(for: now)
        let reminders = [
            ReminderSchedule(hour: 10, minute: 15, isEnabled: true, sortOrder: 0)
        ]

        let selected = selector.selectSendDate(
            for: day,
            settings: settings,
            reminders: reminders,
            alreadyScheduled: [],
            now: now
        )

        XCTAssertNotNil(selected)
        let selectedHour = Calendar(identifier: .gregorian).component(.hour, from: selected ?? now)
        XCTAssertTrue((9...20).contains(selectedHour))
        let reminderDate = Calendar(identifier: .gregorian).date(
            bySettingHour: 10,
            minute: 15,
            second: 0,
            of: day
        ) ?? now
        XCTAssertGreaterThanOrEqual(abs((selected ?? now).timeIntervalSince(reminderDate)), 90 * 60)
    }

    func testStreakLossAndReigniteWindow() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_000_000)
        let lastComplete = calendar.date(byAdding: .day, value: -2, to: now) ?? now

        let journey = PrayerJourney(title: "Faith", category: "Growth")
        let entry = PrayerEntry(
            createdAt: lastComplete,
            prompt: "p",
            scriptureReference: "James 1:5",
            scriptureText: "t",
            actionStep: "step",
            completedAt: lastComplete
        )

        JourneyEngagementService.refreshJourneyState(
            for: journey,
            entries: [entry],
            now: now,
            calendar: calendar
        )

        let eligibility = JourneyEngagementService.reigniteEligibility(
            for: journey,
            entries: [entry],
            now: now,
            calendar: calendar
        )
        XCTAssertTrue(eligibility.isEligible)
        XCTAssertEqual(eligibility.recoverableStreak, 1)

        let activated = JourneyEngagementService.applyReignite(
            to: journey,
            entries: [entry],
            at: now,
            calendar: calendar
        )
        XCTAssertTrue(activated)
        XCTAssertEqual(journey.reignitedStreakOffset, 1)
    }

    func testHydrationDecayAndWeightedGrowth() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 2_000_000)
        let completion = calendar.date(byAdding: .day, value: -3, to: now) ?? now

        let journey = PrayerJourney(title: "Patience", category: "Trust")
        let entry = PrayerEntry(
            createdAt: completion,
            prompt: "p",
            scriptureReference: "James 1:5",
            scriptureText: "t",
            actionStep: "step",
            completedAt: completion
        )

        JourneyEngagementService.refreshJourneyState(
            for: journey,
            entries: [entry],
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(journey.hydrationStage, 0)

        let result = JourneyEngagementService.applyCompletionGrowth(
            to: journey,
            inferredLegacyCount: 1,
            baseGrowthPoints: 1,
            at: now
        )
        XCTAssertEqual(result.hydrationStageBeforeTend, 0)
        XCTAssertGreaterThan(result.appliedGrowth, 0)
        XCTAssertEqual(journey.hydrationStage, JourneyEngagementService.hydrationMaxStage)
        XCTAssertGreaterThanOrEqual(journey.growthProgress, 1.0)
    }

    func testInAppReigniteOptionHonorsEligibilityAndDismissState() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 3_000_000)
        let lastComplete = calendar.date(byAdding: .day, value: -2, to: now) ?? now

        let journey = PrayerJourney(title: "Faith", category: "Growth")
        let entry = PrayerEntry(
            createdAt: lastComplete,
            prompt: "p",
            scriptureReference: "James 1:5",
            scriptureText: "t",
            actionStep: "step",
            completedAt: lastComplete
        )

        JourneyEngagementService.refreshJourneyState(
            for: journey,
            entries: [entry],
            now: now,
            calendar: calendar
        )

        XCTAssertTrue(
            JourneyEngagementService.shouldOfferInAppReigniteOption(
                for: journey,
                entries: [entry],
                now: now,
                calendar: calendar,
                chancePercent: 100,
                maxDelayHours: 0
            )
        )

        journey.reigniteOverlayShownAt = now
        XCTAssertFalse(
            JourneyEngagementService.shouldOfferInAppReigniteOption(
                for: journey,
                entries: [entry],
                now: now,
                calendar: calendar,
                chancePercent: 100,
                maxDelayHours: 0
            )
        )
    }

    func testInAppReigniteOptionRespectsRandomGateOverride() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 4_000_000)
        let lastComplete = calendar.date(byAdding: .day, value: -2, to: now) ?? now

        let journey = PrayerJourney(title: "Patience", category: "Trust")
        let entry = PrayerEntry(
            createdAt: lastComplete,
            prompt: "p",
            scriptureReference: "James 1:5",
            scriptureText: "t",
            actionStep: "step",
            completedAt: lastComplete
        )

        JourneyEngagementService.refreshJourneyState(
            for: journey,
            entries: [entry],
            now: now,
            calendar: calendar
        )

        XCTAssertFalse(
            JourneyEngagementService.shouldOfferInAppReigniteOption(
                for: journey,
                entries: [entry],
                now: now,
                calendar: calendar,
                chancePercent: 0,
                maxDelayHours: 0
            )
        )
    }
}
