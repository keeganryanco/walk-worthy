import Foundation

struct OnboardingExperimentConfig: Equatable, Codable {
    let variant: String
    let preJourneyOrder: [String]
    let postJourneyOrder: [String]
    let copyOverrides: [String: String]

    static let `default` = OnboardingExperimentConfig(
        variant: "control",
        preJourneyOrder: [],
        postJourneyOrder: [],
        copyOverrides: [:]
    )
}

protocol OnboardingExperimentConfigProviding {
    func fetchConfig() async -> OnboardingExperimentConfig
}

struct NoOpOnboardingExperimentService: OnboardingExperimentConfigProviding {
    func fetchConfig() async -> OnboardingExperimentConfig {
        .default
    }
}

enum OnboardingExperimentServiceFactory {
    static func makeDefault() -> OnboardingExperimentConfigProviding {
        let key = AppConstants.Analytics.posthogProjectKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = AppConstants.Analytics.posthogHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !host.isEmpty else { return NoOpOnboardingExperimentService() }
        return PostHogOnboardingExperimentService(projectKey: key, host: host) ?? NoOpOnboardingExperimentService()
    }
}

private final class PostHogOnboardingExperimentService: OnboardingExperimentConfigProviding {
    private let projectKey: String
    private let decideURL: URL
    private let distinctID: String
    private let defaults: UserDefaults
    private let cacheKey = "onboarding.experiment.config.v1"

    init?(projectKey: String, host: String, defaults: UserDefaults = .standard) {
        guard var baseURL = URL(string: host) else { return nil }
        if baseURL.path.isEmpty || baseURL.path == "/" {
            baseURL.append(path: "decide/")
        } else if !baseURL.path.hasSuffix("/decide/") {
            baseURL.append(path: "decide/")
        }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "v", value: "3")]
        guard let decideURL = components?.url else { return nil }

        self.projectKey = projectKey
        self.decideURL = decideURL
        self.defaults = defaults
        self.distinctID = PostHogOnboardingExperimentService.loadDistinctID(defaults: defaults)
    }

    func fetchConfig() async -> OnboardingExperimentConfig {
        let cached = loadCachedConfig() ?? .default
        var request = URLRequest(url: decideURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "api_key": projectKey,
            "distinct_id": distinctID
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            return cached
        }

        request.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return cached
            }
            guard
                let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                return cached
            }

            let merged = mergeConfig(from: object, fallback: cached)
            saveCachedConfig(merged)
            return merged
        } catch {
            return cached
        }
    }

    private func mergeConfig(from object: [String: Any], fallback: OnboardingExperimentConfig) -> OnboardingExperimentConfig {
        let featureFlags = object["featureFlags"] as? [String: Any] ?? object["feature_flags"] as? [String: Any] ?? [:]
        let payloads = object["featureFlagPayloads"] as? [String: Any] ?? object["feature_flag_payloads"] as? [String: Any] ?? [:]

        var variant = fallback.variant
        if let value = featureFlags["onboarding_flow_variant"] {
            variant = stringValue(value)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? variant
        }

        var pre = fallback.preJourneyOrder
        var post = fallback.postJourneyOrder
        var copy = fallback.copyOverrides

        if let configPayload = parsePayload(payloads["onboarding_flow_config"]) {
            if let value = configPayload["variant"] {
                variant = stringValue(value)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? variant
            }
            if let values = parseStringArray(configPayload["pre_journey_order"]) {
                pre = values
            }
            if let values = parseStringArray(configPayload["post_journey_order"]) {
                post = values
            }
            if let values = parseStringDictionary(configPayload["copy_overrides"] ?? configPayload["copy"]) {
                copy.merge(values) { _, new in new }
            }
        }

        if let values = parseStringArray(payloads["onboarding_pre_journey_order"]) {
            pre = values
        }
        if let values = parseStringArray(payloads["onboarding_post_journey_order"]) {
            post = values
        }
        if let values = parseStringDictionary(payloads["onboarding_copy_overrides"]) {
            copy.merge(values) { _, new in new }
        }

        if let values = parseStringArray(featureFlags["onboarding_pre_journey_order"]) {
            pre = values
        }
        if let values = parseStringArray(featureFlags["onboarding_post_journey_order"]) {
            post = values
        }

        return OnboardingExperimentConfig(
            variant: variant.isEmpty ? "control" : variant,
            preJourneyOrder: normalizeStepTokenList(pre),
            postJourneyOrder: normalizeStepTokenList(post),
            copyOverrides: normalizeCopyOverrides(copy)
        )
    }

    private func loadCachedConfig() -> OnboardingExperimentConfig? {
        guard let data = defaults.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(OnboardingExperimentConfig.self, from: data)
    }

    private func saveCachedConfig(_ config: OnboardingExperimentConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        defaults.set(data, forKey: cacheKey)
    }

    private func parsePayload(_ value: Any?) -> [String: Any]? {
        if let dictionary = value as? [String: Any] {
            return dictionary
        }

        if let string = value as? String,
           let data = string.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return object
        }

        return nil
    }

    private func parseStringArray(_ value: Any?) -> [String]? {
        if let array = value as? [String] {
            return array
        }
        if let array = value as? [Any] {
            let parsed = array.compactMap { stringValue($0)?.trimmingCharacters(in: .whitespacesAndNewlines) }
            return parsed.isEmpty ? nil : parsed
        }
        if let string = value as? String {
            let parsed = string
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return parsed.isEmpty ? nil : parsed
        }
        return nil
    }

    private func parseStringDictionary(_ value: Any?) -> [String: String]? {
        if let dictionary = value as? [String: String] {
            return dictionary
        }
        if let dictionary = value as? [String: Any] {
            var result: [String: String] = [:]
            for (key, value) in dictionary {
                guard let rendered = stringValue(value) else { continue }
                result[key] = rendered
            }
            return result.isEmpty ? nil : result
        }
        if let string = value as? String,
           let data = string.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return parseStringDictionary(object)
        }
        return nil
    }

    private func stringValue(_ value: Any?) -> String? {
        switch value {
        case let value as String:
            return value
        case let value as NSNumber:
            return value.stringValue
        default:
            return nil
        }
    }

    private func normalizeStepTokenList(_ tokens: [String]) -> [String] {
        tokens
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    private func normalizeCopyOverrides(_ overrides: [String: String]) -> [String: String] {
        var normalized: [String: String] = [:]
        for (key, value) in overrides {
            let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedKey.isEmpty, !normalizedValue.isEmpty else { continue }
            normalized[normalizedKey] = normalizedValue
        }
        return normalized
    }

    private static func loadDistinctID(defaults: UserDefaults) -> String {
        let key = "analytics.distinct_id"
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let generated = UUID().uuidString.lowercased()
        defaults.set(generated, forKey: key)
        return generated
    }
}
