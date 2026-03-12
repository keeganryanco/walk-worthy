import Foundation

struct AIContentDraft: Codable, Equatable {
    let prayerPrompt: String
    let actionStep: String
    let scriptureReference: String
    let scriptureSnippet: String
}

protocol AIContentClient {
    func generateTodayDraft(from profile: OnboardingProfile, recentEntries: [PrayerEntry]) async throws -> AIContentDraft
}

struct DisabledAIContentClient: AIContentClient {
    func generateTodayDraft(from profile: OnboardingProfile, recentEntries: [PrayerEntry]) async throws -> AIContentDraft {
        AIContentDraft(
            prayerPrompt: "Lord, help me walk faithfully today.",
            actionStep: "Take one concrete action in love today.",
            scriptureReference: "Philippians 4:6-7",
            scriptureSnippet: "Bring your anxieties to God in prayer and receive His peace. Take one step in response today."
        )
    }
}
