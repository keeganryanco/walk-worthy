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
        let domain: String
        let targetLocale: String
        let strings: [String: String]
    }

    private struct ResponseBody: Decodable {
        let translated: [String: String]
    }

    static func translate(
        _ strings: [String: String],
        domain: RemoteLocalizationDomain,
        languageCode: String = AppLanguage.aiLanguageCode()
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
            strings: strings
        )
        guard let body = try? JSONEncoder().encode(payload) else {
            return strings
        }

        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return strings
            }

            let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
            var resolved = strings
            for (key, value) in decoded.translated {
                guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                resolved[key] = value
            }
            return resolved
        } catch {
            return strings
        }
    }

    private static func normalizeLanguageCode(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("es") ? "es" : "en"
    }
}
