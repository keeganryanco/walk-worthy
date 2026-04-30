import Foundation
import SwiftData

enum DailyJourneyPackageSource: String, Codable, CaseIterable {
    case cache
    case remote
    case template
}

@Model
final class DailyJourneyPackageRecord {
    @Attribute(.unique) var id: UUID
    var journeyID: UUID
    var dayKey: String
    var dailyTitle: String?
    var reflectionThought: String
    var scriptureReference: String
    var scriptureParaphrase: String
    var prayer: String
    var todayAim: String?
    var smallStepQuestion: String
    var suggestedStepsJSON: String
    var updatedJourneyArcJSON: String?
    var qualityVersion: Int = 0
    // Optional for safe schema migration from pre-completionSuggestion builds.
    var completionShouldPrompt: Bool?
    var completionReason: String?
    var completionConfidence: Double?
    var generatedAt: Date
    var sourceRaw: String
    var linkedEntryID: UUID?

    init(
        id: UUID = UUID(),
        journeyID: UUID,
        dayKey: String,
        dailyTitle: String = DailyJourneyPackageValidation.defaultDailyTitle,
        reflectionThought: String,
        scriptureReference: String,
        scriptureParaphrase: String,
        prayer: String,
        todayAim: String = DailyJourneyPackageValidation.defaultTodayAim,
        smallStepQuestion: String,
        suggestedSteps: [String],
        completionSuggestion: CompletionSuggestion,
        updatedJourneyArc: JourneyArcPayload? = nil,
        qualityVersion: Int = DailyJourneyPackage.currentQualityVersion,
        generatedAt: Date = .now,
        source: DailyJourneyPackageSource,
        linkedEntryID: UUID? = nil
    ) {
        self.id = id
        self.journeyID = journeyID
        self.dayKey = dayKey
        self.dailyTitle = dailyTitle
        self.reflectionThought = reflectionThought
        self.scriptureReference = scriptureReference
        self.scriptureParaphrase = scriptureParaphrase
        self.prayer = prayer
        self.todayAim = todayAim
        self.smallStepQuestion = smallStepQuestion
        self.suggestedStepsJSON = (try? String(data: JSONEncoder().encode(suggestedSteps), encoding: .utf8)) ?? "[]"
        self.updatedJourneyArcJSON = updatedJourneyArc.flatMap {
            try? String(data: JSONEncoder().encode($0), encoding: .utf8)
        }
        self.qualityVersion = qualityVersion
        self.completionShouldPrompt = completionSuggestion.shouldPrompt
        self.completionReason = completionSuggestion.reason
        self.completionConfidence = completionSuggestion.confidence
        self.generatedAt = generatedAt
        self.sourceRaw = source.rawValue
        self.linkedEntryID = linkedEntryID
    }

    var source: DailyJourneyPackageSource {
        get { DailyJourneyPackageSource(rawValue: sourceRaw) ?? .template }
        set { sourceRaw = newValue.rawValue }
    }

    var suggestedSteps: [String] {
        guard let data = suggestedStepsJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded
    }

    var asPackage: DailyJourneyPackage {
        DailyJourneyPackage(
            dailyTitle: dailyTitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? dailyTitle ?? DailyJourneyPackageValidation.defaultDailyTitle
                : DailyJourneyPackageValidation.defaultDailyTitle,
            reflectionThought: reflectionThought,
            scriptureReference: scriptureReference,
            scriptureParaphrase: scriptureParaphrase,
            prayer: prayer,
            todayAim: todayAim?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? todayAim ?? DailyJourneyPackageValidation.defaultTodayAim
                : DailyJourneyPackageValidation.defaultTodayAim,
            smallStepQuestion: smallStepQuestion,
            suggestedSteps: suggestedSteps,
            completionSuggestion: CompletionSuggestion(
                shouldPrompt: completionShouldPrompt ?? false,
                reason: completionReason ?? "",
                confidence: completionConfidence ?? 0
            ),
            updatedJourneyArc: updatedJourneyArc,
            qualityVersion: qualityVersion,
            generatedAt: generatedAt
        )
    }

    var updatedJourneyArc: JourneyArcPayload? {
        guard let updatedJourneyArcJSON,
              let data = updatedJourneyArcJSON.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(JourneyArcPayload.self, from: data)
    }
}
