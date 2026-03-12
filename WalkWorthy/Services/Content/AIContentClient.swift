import Foundation

protocol AIContentClient {
    func generatePersonalizedContext(from profile: OnboardingProfile, recentEntries: [PrayerEntry]) async throws -> String
}

struct DisabledAIContentClient: AIContentClient {
    func generatePersonalizedContext(from profile: OnboardingProfile, recentEntries: [PrayerEntry]) async throws -> String {
        "AI personalization disabled for local-first MVP."
    }
}
