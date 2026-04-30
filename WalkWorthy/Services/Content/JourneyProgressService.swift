import Foundation
import SwiftData

@MainActor
enum JourneyProgressService {
    static func logEvent(
        journeyID: UUID,
        type: JourneyProgressEventType,
        notes: String = "",
        modelContext: ModelContext,
        date: Date = .now
    ) {
        let event = JourneyProgressEvent(
            journeyID: journeyID,
            createdAt: date,
            eventTypeRaw: type.rawValue,
            notes: notes
        )
        modelContext.insert(event)
        try? modelContext.save()
    }

    static func completionCount(
        for journeyID: UUID,
        modelContext: ModelContext
    ) -> Int {
        let completedTypeRaw = JourneyProgressEventType.stepCompleted.rawValue
        let descriptor = FetchDescriptor<JourneyProgressEvent>(
            predicate: #Predicate {
                $0.journeyID == journeyID &&
                $0.eventTypeRaw == completedTypeRaw
            }
        )
        let events = (try? modelContext.fetch(descriptor)) ?? []
        return events.count
    }
}

enum JourneyArcService {
    static func updateAfterTend(
        journey: PrayerJourney,
        committedStep: String,
        followThroughStatus: FollowThroughStatus?
    ) {
        let existing = decodeJourneyArc(from: journey.journeyArc)
        let trimmedStep = committedStep.trimmingCharacters(in: .whitespacesAndNewlines)
        let purpose = existing?.purpose.nonEmpty
            ?? journey.growthFocus.nonEmpty
            ?? journey.title
        let tone = existing?.tone.nonEmpty
            ?? "grounded, sincere, practical, hopeful"

        let currentStage: String
        let nextMovement: String
        let interpretation: String

        switch followThroughStatus {
        case .some(.yes):
            currentStage = "building from completed follow-through"
            interpretation = "The user followed through and can handle a slightly more specific next step."
            nextMovement = trimmedStep.isEmpty
                ? "Continue the same journey with a concrete faithful action."
                : "Build on the completed step: \(trimmedStep)."
        case .some(.partial):
            currentStage = "simplifying the next faithful step"
            interpretation = "The user partially followed through; reduce difficulty without becoming generic."
            nextMovement = trimmedStep.isEmpty
                ? "Make tomorrow's action smaller and easier to complete."
                : "Continue from \(trimmedStep), but make the next action smaller."
        case .some(.no):
            currentStage = "returning gently to one doable action"
            interpretation = "The user did not follow through; restart gently with a very concrete low-friction step."
            nextMovement = trimmedStep.isEmpty
                ? "Offer one small concrete action the user can actually finish."
                : "Reframe \(trimmedStep) into a simpler doable action."
        case .some(.unanswered), .none:
            currentStage = "beginning a new concrete response"
            interpretation = "No prior follow-through answer is available yet."
            nextMovement = trimmedStep.isEmpty
                ? "Move the prayer into one concrete act today."
                : "Use today's commitment as the next thread: \(trimmedStep)."
        }

        let updated = JourneyArcPayload(
            purpose: purpose,
            currentStage: currentStage,
            nextMovement: nextMovement,
            tone: tone,
            practicalActionDirection: "Prefer specific real-world actions when the user's context supports them; lower difficulty after partial or missed follow-through.",
            lastFollowThroughInterpretation: interpretation
        )
        journey.journeyArc = encodeJourneyArc(updated) ?? journey.journeyArc
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
