import Foundation
import SwiftData

@MainActor
enum JourneyMemoryService {
    static func snapshot(
        for journeyID: UUID,
        modelContext: ModelContext
    ) -> JourneyMemorySnapshot? {
        let descriptor = FetchDescriptor<JourneyMemorySnapshot>(
            predicate: #Predicate { $0.journeyID == journeyID },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try? modelContext.fetch(descriptor).first
    }

    static func refreshSnapshot(
        for journey: PrayerJourney,
        entries: [PrayerEntry],
        profile: OnboardingProfile?,
        modelContext: ModelContext,
        now: Date = .now
    ) {
        let completedCount = entries.filter { $0.completedAt != nil }.count
        let recentReflections = entries
            .sorted(by: { $0.createdAt > $1.createdAt })
            .prefix(5)
            .map(\.userReflection)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let summary = "\(journey.title): \(journey.category). Recent momentum: \(completedCount) completed steps."

        let winsSummary: String
        if completedCount == 0 {
            winsSummary = "No completed steps logged yet."
        } else {
            winsSummary = "\(completedCount) faithful steps completed recently."
        }

        let blockerKeywords = ["stuck", "busy", "anxious", "delay", "avoid"]
        let blockerSignals = recentReflections.filter { reflection in
            blockerKeywords.contains(where: { reflection.localizedCaseInsensitiveContains($0) })
        }
        let blockersSummary = blockerSignals.isEmpty
            ? "No consistent blocker language detected."
            : "Potential blockers showing up: \(blockerSignals.prefix(2).joined(separator: " | "))"

        let preferredTone = inferredTone(from: profile?.growthGoal ?? "")

        if let existing = snapshot(for: journey.id, modelContext: modelContext) {
            existing.updatedAt = now
            existing.summary = summary
            existing.winsSummary = winsSummary
            existing.blockersSummary = blockersSummary
            existing.preferredTone = preferredTone
        } else {
            let row = JourneyMemorySnapshot(
                journeyID: journey.id,
                updatedAt: now,
                summary: summary,
                winsSummary: winsSummary,
                blockersSummary: blockersSummary,
                preferredTone: preferredTone
            )
            modelContext.insert(row)
        }

        if let global = globalMemory(modelContext: modelContext) {
            global.updatedAt = now
            global.preferredTone = preferredTone
        } else {
            let global = GlobalLightMemory(updatedAt: now, preferredTone: preferredTone)
            modelContext.insert(global)
        }

        try? modelContext.save()
    }

    static func globalMemory(modelContext: ModelContext) -> GlobalLightMemory? {
        let descriptor = FetchDescriptor<GlobalLightMemory>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try? modelContext.fetch(descriptor).first
    }

    private static func inferredTone(from growthGoal: String) -> String {
        let normalized = growthGoal.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch normalized {
        case "peace":
            return "calm-grounded"
        case "courage", "confidence":
            return "bold-encouraging"
        case "discipline", "consistency":
            return "steady-practical"
        default:
            return "grounded-encouraging"
        }
    }
}
