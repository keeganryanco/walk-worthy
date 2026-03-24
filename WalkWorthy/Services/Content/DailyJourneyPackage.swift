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
    static let defaultFirstPersonPrayer = "Lord, I place this journey in Your hands today. Give me wisdom, courage, and steady faith for my next step. Amen."
    private static let danglingEndings: Set<String> = [
        "a", "an", "and", "at", "because", "for", "from", "in", "into", "of", "on", "or",
        "that", "the", "to", "toward", "towards", "with"
    ]
    private static let firstPersonRegex = try? NSRegularExpression(
        pattern: #"\b(i|i'm|i've|i'd|i'll|me|my|mine|myself|we|we're|we've|we'd|we'll|us|our|ours|ourselves)\b"#,
        options: [.caseInsensitive]
    )
    private static let disallowedThirdPersonPhrases = [
        "the user",
        "this user",
        "for the user",
        "their journey",
        "his journey",
        "her journey"
    ]

    static func validated(
        _ package: DailyJourneyPackage,
        followThroughStatus: FollowThroughStatus? = nil
    ) -> DailyJourneyPackage {
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
        let fallbackChips = contextualFallbackChips(
            reflectionThought: package.reflectionThought,
            smallStepQuestion: normalizedQuestion,
            followThroughStatus: followThroughStatus
        )
        let mergedSuggestedSteps = mergedChips(primary: normalizedSuggestedSteps, fallback: fallbackChips)

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
            prayer: normalizedFirstPersonPrayer(package.prayer),
            smallStepQuestion: normalizedQuestion,
            suggestedSteps: mergedSuggestedSteps,
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

    private static func normalizedFirstPersonPrayer(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultFirstPersonPrayer }

        let normalized = trimmed
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")

        let mentionsThirdPersonTemplate = disallowedThirdPersonPhrases.contains { normalized.contains($0) }
        guard !mentionsThirdPersonTemplate else { return defaultFirstPersonPrayer }

        guard let firstPersonRegex else { return defaultFirstPersonPrayer }
        let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        let hasFirstPerson = firstPersonRegex.firstMatch(in: normalized, options: [], range: range) != nil
        return hasFirstPerson ? trimmed : defaultFirstPersonPrayer
    }

    private static func contextualFallbackChips(
        reflectionThought: String,
        smallStepQuestion: String,
        followThroughStatus: FollowThroughStatus?
    ) -> [String] {
        let signal = "\(reflectionThought) \(smallStepQuestion)".lowercased()
        var chips: [String]
        if followThroughStatus == .partial || followThroughStatus == .no {
            chips = [
                "Take one tiny step",
                "Do a two minute task",
                "Choose one easier action"
            ]
        } else {
            chips = [
                "Pray over one next step",
                "Take one faithful action",
                "Finish one delayed task"
            ]
        }

        if signal.contains("worry") || signal.contains("anx") || signal.contains("peace") || signal.contains("fear") {
            chips.insert(contentsOf: ["Take five calm breaths", "Pray through this specific worry"], at: 0)
        }
        if signal.contains("focus") || signal.contains("discipline") || signal.contains("habit") || signal.contains("consisten") {
            chips.insert(contentsOf: ["Start one focused work block", "Remove one clear distraction"], at: 0)
        }
        if signal.contains("relationship") || signal.contains("family") || signal.contains("friend") || signal.contains("community") {
            chips.insert(contentsOf: ["Send one encouragement text", "Pray for one specific person"], at: 0)
        }
        if signal.contains("work") || signal.contains("career") || signal.contains("money") || signal.contains("business") {
            chips.insert(contentsOf: ["Complete one important work task", "Review one key decision today"], at: 0)
        }

        return normalizedChipSteps(chips)
    }

    private static func mergedChips(primary: [String], fallback: [String]) -> [String] {
        var seen: Set<String> = []
        var merged: [String] = []

        for value in (primary + fallback) {
            let key = value.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            merged.append(value)
            if merged.count == 4 {
                break
            }
        }

        if merged.isEmpty {
            return [
                "Pray over one next step",
                "Take one faithful action",
                "Finish one delayed task"
            ]
        }

        return merged
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
