import Foundation

enum AnalyticsEvent: String {
    case onboardingStarted = "onboarding_started"
    case onboardingCompleted = "onboarding_completed"
    case onboardingExperimentAssigned = "onboarding_experiment_assigned"
    case onboardingWowSeen = "onboarding_wow_seen"
    case reviewPromptShown = "review_prompt_shown"
    case journeyCreated = "journey_created"
    case dailyPackageGenerated = "daily_package_generated"
    case smallStepCompleted = "small_step_completed"
    case journeyCompleted = "journey_completed"
    case paywallShown = "paywall_shown"
    case localizationRequest = "localization_request"
}

protocol AnalyticsTracking {
    func track(_ event: AnalyticsEvent, properties: [String: String])
}

struct NoOpAnalyticsService: AnalyticsTracking {
    func track(_ event: AnalyticsEvent, properties: [String: String] = [:]) {
        // Intentionally empty when analytics is not configured.
    }
}

enum AnalyticsServiceFactory {
    static func makeDefault() -> AnalyticsTracking {
        let key = AppConstants.Analytics.posthogProjectKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = AppConstants.Analytics.posthogHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !host.isEmpty else { return NoOpAnalyticsService() }
        return PostHogAnalyticsService(projectKey: key, host: host) ?? NoOpAnalyticsService()
    }
}

private struct PostHogPayload: Encodable {
    let api_key: String
    let event: String
    let properties: [String: String]
}

private final class PostHogAnalyticsService: AnalyticsTracking {
    private let projectKey: String
    private let captureURL: URL
    private let distinctID: String
    private let appVersion: String
    private let buildNumber: String
    private let queue = DispatchQueue(label: "co.keeganryan.tend.analytics", qos: .utility)

    init?(projectKey: String, host: String) {
        guard let baseURL = URL(string: host) else { return nil }
        self.projectKey = projectKey
        self.captureURL = baseURL.appendingPathComponent("capture/")
        self.distinctID = PostHogAnalyticsService.loadDistinctID()
        self.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        self.buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    func track(_ event: AnalyticsEvent, properties: [String: String] = [:]) {
        let safeProperties = sanitize(properties)
        queue.async { [projectKey, captureURL, distinctID, appVersion, buildNumber] in
            var payloadProperties: [String: String] = [
                "distinct_id": distinctID,
                "platform": "ios",
                "app_version": appVersion,
                "build_number": buildNumber
            ]
            payloadProperties.merge(safeProperties) { _, latest in latest }

            let payload = PostHogPayload(
                api_key: projectKey,
                event: event.rawValue,
                properties: payloadProperties
            )

            guard let body = try? JSONEncoder().encode(payload) else { return }

            var request = URLRequest(url: captureURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body

            URLSession.shared.dataTask(with: request).resume()
        }
    }

    private func sanitize(_ properties: [String: String]) -> [String: String] {
        // Keep analytics metadata-only. Never send prayer text or freeform reflections.
        properties.filter { !$0.key.lowercased().contains("text") && !$0.key.lowercased().contains("reflection") }
    }

    private static func loadDistinctID() -> String {
        let defaults = UserDefaults.standard
        let key = "analytics.distinct_id"
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let generated = UUID().uuidString.lowercased()
        defaults.set(generated, forKey: key)
        return generated
    }
}
