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
    var reflectionThought: String
    var scriptureReference: String
    var scriptureParaphrase: String
    var prayer: String
    var smallStepQuestion: String
    var suggestedStepsJSON: String
    var generatedAt: Date
    var sourceRaw: String
    var linkedEntryID: UUID?

    init(
        id: UUID = UUID(),
        journeyID: UUID,
        dayKey: String,
        reflectionThought: String,
        scriptureReference: String,
        scriptureParaphrase: String,
        prayer: String,
        smallStepQuestion: String,
        suggestedSteps: [String],
        generatedAt: Date = .now,
        source: DailyJourneyPackageSource,
        linkedEntryID: UUID? = nil
    ) {
        self.id = id
        self.journeyID = journeyID
        self.dayKey = dayKey
        self.reflectionThought = reflectionThought
        self.scriptureReference = scriptureReference
        self.scriptureParaphrase = scriptureParaphrase
        self.prayer = prayer
        self.smallStepQuestion = smallStepQuestion
        self.suggestedStepsJSON = (try? String(data: JSONEncoder().encode(suggestedSteps), encoding: .utf8)) ?? "[]"
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
            reflectionThought: reflectionThought,
            scriptureReference: scriptureReference,
            scriptureParaphrase: scriptureParaphrase,
            prayer: prayer,
            smallStepQuestion: smallStepQuestion,
            suggestedSteps: suggestedSteps,
            generatedAt: generatedAt
        )
    }
}
