import Foundation

struct CompletionSuggestion: Codable, Equatable {
    let shouldPrompt: Bool
    let reason: String
    let confidence: Double

    init(shouldPrompt: Bool, reason: String, confidence: Double) {
        self.shouldPrompt = shouldPrompt
        self.reason = reason
        self.confidence = confidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shouldPrompt = try container.decodeIfPresent(Bool.self, forKey: .shouldPrompt) ?? false
        reason = try container.decodeIfPresent(String.self, forKey: .reason) ?? ""
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0
    }
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

    init(
        reflectionThought: String,
        scriptureReference: String,
        scriptureParaphrase: String,
        prayer: String,
        smallStepQuestion: String,
        suggestedSteps: [String],
        completionSuggestion: CompletionSuggestion,
        generatedAt: Date
    ) {
        self.reflectionThought = reflectionThought
        self.scriptureReference = scriptureReference
        self.scriptureParaphrase = scriptureParaphrase
        self.prayer = prayer
        self.smallStepQuestion = smallStepQuestion
        self.suggestedSteps = suggestedSteps
        self.completionSuggestion = completionSuggestion
        self.generatedAt = generatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reflectionThought = try container.decodeIfPresent(String.self, forKey: .reflectionThought) ?? ""
        scriptureReference = try container.decodeIfPresent(String.self, forKey: .scriptureReference) ?? ""
        scriptureParaphrase = try container.decodeIfPresent(String.self, forKey: .scriptureParaphrase) ?? ""
        prayer = try container.decodeIfPresent(String.self, forKey: .prayer) ?? ""
        smallStepQuestion = try container.decodeIfPresent(String.self, forKey: .smallStepQuestion) ?? ""
        suggestedSteps = try container.decodeIfPresent([String].self, forKey: .suggestedSteps) ?? []
        completionSuggestion = try container.decodeIfPresent(CompletionSuggestion.self, forKey: .completionSuggestion)
            ?? CompletionSuggestion(shouldPrompt: false, reason: "", confidence: 0)

        if let unix = try container.decodeIfPresent(Double.self, forKey: .generatedAt) {
            generatedAt = Date(timeIntervalSince1970: unix)
        } else if let isoString = try container.decodeIfPresent(String.self, forKey: .generatedAt) {
            let iso = ISO8601DateFormatter()
            generatedAt = iso.date(from: isoString) ?? .now
        } else {
            generatedAt = .now
        }
    }
}

enum DailyJourneyPackageValidation {
    static let defaultSmallStepQuestion = "What small step could you take today?"
    private static let danglingEndings: Set<String> = [
        "a", "an", "and", "at", "because", "for", "from", "in", "into", "of", "on", "or",
        "that", "the", "to", "toward", "towards", "with"
    ]

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

        let normalizedSuggestedSteps = normalizedChipSteps(package.suggestedSteps)

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
            suggestedSteps: normalizedSuggestedSteps.isEmpty
                ? [
                    "Take one faithful action today.",
                    "Pray over one next step.",
                    "Finish one delayed task."
                ]
                : Array(normalizedSuggestedSteps),
            completionSuggestion: normalizedCompletionSuggestion,
            generatedAt: package.generatedAt
        )
    }

    private static func normalizedChipSteps(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var chips: [String] = []

        for value in values {
            let compact = value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

            guard !compact.isEmpty else { continue }

            let words = compact.split(separator: " ")
            guard (2...7).contains(words.count) else { continue }

            let first = words.first?.lowercased() ?? ""
            let last = words.last?.lowercased() ?? ""
            guard !["and", "or", "to", "for", "with", "because", "if", "when"].contains(first) else { continue }
            guard !danglingEndings.contains(last) else { continue }

            let key = compact.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            chips.append(compact)

            if chips.count == 4 {
                break
            }
        }

        return chips
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
