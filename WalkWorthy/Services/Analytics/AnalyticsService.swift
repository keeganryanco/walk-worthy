import Foundation

enum AnalyticsEvent: String {
    case onboardingStarted = "onboarding_started"
    case onboardingCompleted = "onboarding_completed"
    case onboardingWowSeen = "onboarding_wow_seen"
    case reviewPromptShown = "review_prompt_shown"
    case journeyCreated = "journey_created"
    case dailyPackageGenerated = "daily_package_generated"
    case smallStepCompleted = "small_step_completed"
    case journeyCompleted = "journey_completed"
    case paywallShown = "paywall_shown"
}

protocol AnalyticsTracking {
    func track(_ event: AnalyticsEvent, properties: [String: String])
}

struct NoOpAnalyticsService: AnalyticsTracking {
    func track(_ event: AnalyticsEvent, properties: [String: String] = [:]) {
        // Intentionally empty while PostHog integration is in progress.
    }
}
