import Foundation

enum L10n {
    static func string(
        _ key: String,
        default defaultValue: String,
        languageOverride: AppLanguage? = nil
    ) -> String {
        let language = languageOverride ?? AppLanguage.selected()
        let table = "Localizable"

        if language == .system {
            return Bundle.main.localizedString(forKey: key, value: defaultValue, table: table)
        }

        if let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: defaultValue, table: table)
        }

        return Bundle.main.localizedString(forKey: key, value: defaultValue, table: table)
    }
}

enum RemoteLocalizationDomain: String {
    case posthogOnboarding = "posthog_onboarding"
    case revenueCatPaywall = "revenuecat_paywall"
}

enum RemoteLocalizationClient {
    private struct RequestBody: Encodable {
        struct Telemetry: Encodable {
            let distinctID: String
            let appVersion: String
            let buildNumber: String
            let platform: String
        }

        let domain: String
        let targetLocale: String
        let strings: [String: String]
        let telemetry: Telemetry
    }

    private struct ResponseBody: Decodable {
        struct Meta: Decodable {
            let provider: String?
            let model: String?
            let cached: Bool?
            let fallbackUsed: Bool?
        }

        let translated: [String: String]
        let meta: Meta?
    }

    private static let analytics: AnalyticsTracking = AnalyticsServiceFactory.makeDefault()

    static func translate(
        _ strings: [String: String],
        domain: RemoteLocalizationDomain,
        languageCode: String = AppLanguage.remoteLocalizationLocaleCode()
    ) async -> [String: String] {
        guard !strings.isEmpty else { return strings }

        let normalizedLanguageCode = normalizeLanguageCode(languageCode)
        guard normalizedLanguageCode != "en" else { return strings }

        let baseURLString = AppConstants.AI.gatewayBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseURLString.isEmpty, let baseURL = URL(string: baseURLString) else {
            return strings
        }

        let endpoint = baseURL.appendingPathComponent("/api/v1/localize")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let appKey = AppConstants.AI.gatewayAppKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !appKey.isEmpty {
            request.setValue(appKey, forHTTPHeaderField: "x-tend-app-key")
        }

        let payload = RequestBody(
            domain: domain.rawValue,
            targetLocale: normalizedLanguageCode,
            strings: strings,
            telemetry: RequestBody.Telemetry(
                distinctID: analyticsDistinctID(),
                appVersion: appVersion(),
                buildNumber: buildNumber(),
                platform: "ios"
            )
        )
        guard let body = try? JSONEncoder().encode(payload) else {
            trackResult(
                domain: domain,
                targetLocale: normalizedLanguageCode,
                keyCount: strings.count,
                success: false,
                fallbackToEnglish: true,
                provider: "client_encode_error",
                cached: false
            )
            return strings
        }

        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                trackResult(
                    domain: domain,
                    targetLocale: normalizedLanguageCode,
                    keyCount: strings.count,
                    success: false,
                    fallbackToEnglish: true,
                    provider: "http_error",
                    cached: false
                )
                return strings
            }

            let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
            var resolved = strings
            for (key, value) in decoded.translated {
                guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                resolved[key] = value
            }
            trackResult(
                domain: domain,
                targetLocale: normalizedLanguageCode,
                keyCount: strings.count,
                success: true,
                fallbackToEnglish: decoded.meta?.fallbackUsed ?? false,
                provider: decoded.meta?.provider ?? "unknown",
                cached: decoded.meta?.cached ?? false
            )
            return resolved
        } catch {
            trackResult(
                domain: domain,
                targetLocale: normalizedLanguageCode,
                keyCount: strings.count,
                success: false,
                fallbackToEnglish: true,
                provider: "client_request_error",
                cached: false
            )
            return strings
        }
    }

    private static func normalizeLanguageCode(_ value: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.hasPrefix("es") {
            return "es"
        }
        if normalized.hasPrefix("pt") {
            return "pt-br"
        }
        return "en"
    }

    private static func trackResult(
        domain: RemoteLocalizationDomain,
        targetLocale: String,
        keyCount: Int,
        success: Bool,
        fallbackToEnglish: Bool,
        provider: String,
        cached: Bool
    ) {
        analytics.track(
            .localizationRequest,
            properties: [
                "domain": domain.rawValue,
                "target_locale": targetLocale,
                "key_count": "\(keyCount)",
                "success": success ? "true" : "false",
                "fallback_to_english": fallbackToEnglish ? "true" : "false",
                "provider": provider,
                "cached": cached ? "true" : "false",
                "source": "ios_client"
            ]
        )
    }

    private static func analyticsDistinctID() -> String {
        let defaults = UserDefaults.standard
        let key = "analytics.distinct_id"
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let generated = UUID().uuidString.lowercased()
        defaults.set(generated, forKey: key)
        return generated
    }

    private static func appVersion() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private static func buildNumber() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
}
