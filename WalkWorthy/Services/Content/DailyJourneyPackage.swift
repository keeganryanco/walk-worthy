import Foundation

struct CompletionSuggestion: Codable, Equatable {
    let shouldPrompt: Bool
    let reason: String
    let confidence: Double
}

struct DailyJourneyPackage: Codable, Equatable {
    let reflectionThought: String
    let scriptureReference: String
    let scriptureParaphrase: String
    let prayer: String
    let smallStepQuestion: String
    let suggestedSteps: [String]
    let completionSuggestion: CompletionSuggestion
    let generatedAt: Date
}

enum DailyJourneyPackageValidation {
    static let defaultSmallStepQuestion = "What small step could you take today?"

    static func validated(_ package: DailyJourneyPackage) -> DailyJourneyPackage {
        let normalizedReference = ScriptureReferenceValidator.isApproved(package.scriptureReference)
            ? package.scriptureReference
            : "Philippians 4:6-7"

        let normalizedParaphrase = ScriptureReferenceValidator.sanitizedSnippet(package.scriptureParaphrase)

        let normalizedQuestion: String
        if package.smallStepQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalizedQuestion = defaultSmallStepQuestion
        } else {
            normalizedQuestion = package.smallStepQuestion
        }

        let normalizedSuggestedSteps = package.suggestedSteps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(4)

        let normalizedConfidence = min(1.0, max(0.0, package.completionSuggestion.confidence))
        let normalizedCompletionSuggestion = CompletionSuggestion(
            shouldPrompt: package.completionSuggestion.shouldPrompt,
            reason: package.completionSuggestion.reason.trimmingCharacters(in: .whitespacesAndNewlines),
            confidence: normalizedConfidence
        )

        return DailyJourneyPackage(
            reflectionThought: package.reflectionThought.trimmingCharacters(in: .whitespacesAndNewlines),
            scriptureReference: normalizedReference,
            scriptureParaphrase: normalizedParaphrase,
            prayer: package.prayer.trimmingCharacters(in: .whitespacesAndNewlines),
            smallStepQuestion: normalizedQuestion,
            suggestedSteps: normalizedSuggestedSteps.isEmpty ? ["Take one specific faithful step for this journey today."] : Array(normalizedSuggestedSteps),
            completionSuggestion: normalizedCompletionSuggestion,
            generatedAt: package.generatedAt
        )
    }
}

protocol DailyJourneyPackageGenerating {
    func generatePackage(
        profile: OnboardingProfile,
        journey: PrayerJourney,
        recentEntries: [PrayerEntry],
        memory: JourneyMemorySnapshot?
    ) async throws -> DailyJourneyPackage
}

struct TemplateDailyJourneyPackageGenerator: DailyJourneyPackageGenerating {
    func generatePackage(
        profile: OnboardingProfile,
        journey: PrayerJourney,
        recentEntries: [PrayerEntry],
        memory: JourneyMemorySnapshot?
    ) async throws -> DailyJourneyPackage {
        return DailyJourneyPackage(
            reflectionThought: "You are not behind. Faithful action today matters.",
            scriptureReference: "Galatians 6:9",
            scriptureParaphrase: "Do not lose heart in doing good; in time, faithfulness bears fruit.",
            prayer: "Lord, help me stay steady and sincere in this journey today.",
            smallStepQuestion: "What small step could you take today?",
            suggestedSteps: [
                "Take 5 minutes to pray specifically for this journey.",
                "Do one concrete task that moves this journey forward.",
                "Text one trusted person and ask for prayer."
            ],
            completionSuggestion: CompletionSuggestion(
                shouldPrompt: false,
                reason: "",
                confidence: 0
            ),
            generatedAt: .now
        )
    }
}
