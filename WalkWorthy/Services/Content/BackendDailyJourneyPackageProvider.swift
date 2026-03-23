import Foundation

struct BackendDailyJourneyPackageProvider: RemoteDailyJourneyPackageProviding {
    private struct RequestBody: Encodable {
        struct Profile: Encodable {
            let prayerFocus: String
            let growthGoal: String
            let reminderWindow: String
            let blocker: String
            let supportCadence: String
        }

        struct Journey: Encodable {
            let id: String
            let title: String
            let category: String
            let themeKey: String
        }

        struct Memory: Encodable {
            let summary: String
            let winsSummary: String
            let blockersSummary: String
            let preferredTone: String
        }

        struct RecentEntry: Encodable {
            let createdAt: String
            let actionStep: String
            let userReflection: String
            let completedAt: String?
        }

        let profile: Profile
        let journey: Journey
        let memory: Memory?
        let recentEntries: [RecentEntry]
        let cycleCount: Int
        let completionCount: Int
        let recentJourneySignals: [String]
        let dateISO: String
    }

    private struct ResponseBody: Decodable {
        struct Meta: Decodable {
            let provider: String
            let model: String
            let escalated: Bool
            let fallbackUsed: Bool
            let generatedAt: String
        }

        let package: DailyJourneyPackage
        let meta: Meta
    }

    private enum ProviderError: LocalizedError {
        case missingBaseURL
        case invalidURL
        case failedResponse(statusCode: Int)

        var errorDescription: String? {
            switch self {
            case .missingBaseURL:
                return "AI gateway URL is not configured."
            case .invalidURL:
                return "AI gateway URL is invalid."
            case .failedResponse(let statusCode):
                return "AI gateway returned status \(statusCode)."
            }
        }
    }

    func generatePackage(
        profile: OnboardingProfile,
        journey: PrayerJourney,
        recentEntries: [PrayerEntry],
        memory: JourneyMemorySnapshot?
    ) async throws -> DailyJourneyPackage {
        let baseURLString = AppConstants.AI.gatewayBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseURLString.isEmpty else {
            throw ProviderError.missingBaseURL
        }

        guard let baseURL = URL(string: baseURLString) else {
            throw ProviderError.invalidURL
        }

        let endpoint = baseURL.appendingPathComponent("/api/v1/journey-package")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let appKey = AppConstants.AI.gatewayAppKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !appKey.isEmpty {
            request.setValue(appKey, forHTTPHeaderField: "x-tend-app-key")
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let body = buildBody(profile: profile, journey: journey, recentEntries: recentEntries, memory: memory)
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.failedResponse(statusCode: -1)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ProviderError.failedResponse(statusCode: httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        return DailyJourneyPackageValidation.validated(decoded.package)
    }

    private func buildBody(
        profile: OnboardingProfile,
        journey: PrayerJourney,
        recentEntries: [PrayerEntry],
        memory: JourneyMemorySnapshot?
    ) -> RequestBody {
        let profilePayload = RequestBody.Profile(
            prayerFocus: profile.prayerFocus,
            growthGoal: profile.growthGoal,
            reminderWindow: profile.reminderWindow,
            blocker: profile.blocker,
            supportCadence: profile.supportCadence
        )

        let journeyPayload = RequestBody.Journey(
            id: journey.id.uuidString,
            title: journey.title,
            category: journey.category,
            themeKey: journey.themeKey.rawValue
        )

        let memoryPayload: RequestBody.Memory?
        if let memory {
            memoryPayload = RequestBody.Memory(
                summary: memory.summary,
                winsSummary: memory.winsSummary,
                blockersSummary: memory.blockersSummary,
                preferredTone: memory.preferredTone
            )
        } else {
            memoryPayload = nil
        }

        let dateFormatter = ISO8601DateFormatter()
        let recent = recentEntries
            .sorted(by: { $0.createdAt > $1.createdAt })
            .prefix(8)
            .map { entry in
                RequestBody.RecentEntry(
                    createdAt: dateFormatter.string(from: entry.createdAt),
                    actionStep: entry.actionStep,
                    userReflection: entry.userReflection,
                    completedAt: entry.completedAt.map { dateFormatter.string(from: $0) }
                )
            }

        let completionCount = journey.completedTends > 0 ? journey.completedTends : recentEntries.filter { $0.completedAt != nil }.count
        let recentSignals = recentEntries
            .sorted(by: { $0.createdAt > $1.createdAt })
            .prefix(6)
            .compactMap { entry -> String? in
                let reflection = entry.userReflection.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !reflection.isEmpty else { return nil }
                return reflection
            }

        return RequestBody(
            profile: profilePayload,
            journey: journeyPayload,
            memory: memoryPayload,
            recentEntries: recent,
            cycleCount: journey.cycleCount,
            completionCount: completionCount,
            recentJourneySignals: Array(recentSignals),
            dateISO: dateFormatter.string(from: .now)
        )
    }
}

struct JourneyBootstrapPayload: Decodable {
    struct InitialMemory: Decodable {
        let summary: String
        let winsSummary: String
        let blockersSummary: String
        let preferredTone: String
    }

    let journeyTitle: String
    let journeyCategory: String
    let themeKey: String
    let initialMemory: InitialMemory
    let initialPackage: DailyJourneyPackage
}

struct BackendJourneyBootstrapProvider {
    private struct RequestBody: Encodable {
        let name: String
        let prayerIntentText: String
        let goalIntentText: String
        let reminderWindow: String
    }

    private struct ResponseBody: Decodable {
        let bootstrap: JourneyBootstrapPayload
    }

    private enum ProviderError: LocalizedError {
        case missingBaseURL
        case invalidURL
        case failedResponse(statusCode: Int)

        var errorDescription: String? {
            switch self {
            case .missingBaseURL:
                return "AI gateway URL is not configured."
            case .invalidURL:
                return "AI gateway URL is invalid."
            case .failedResponse(let statusCode):
                return "AI gateway returned status \(statusCode)."
            }
        }
    }

    func bootstrap(
        name: String,
        prayerIntentText: String,
        goalIntentText: String,
        reminderWindow: String
    ) async throws -> JourneyBootstrapPayload {
        let baseURLString = AppConstants.AI.gatewayBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseURLString.isEmpty else {
            throw ProviderError.missingBaseURL
        }

        guard let baseURL = URL(string: baseURLString) else {
            throw ProviderError.invalidURL
        }

        let endpoint = baseURL.appendingPathComponent("/api/v1/journey-bootstrap")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let appKey = AppConstants.AI.gatewayAppKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !appKey.isEmpty {
            request.setValue(appKey, forHTTPHeaderField: "x-tend-app-key")
        }

        let payload = RequestBody(
            name: name,
            prayerIntentText: prayerIntentText,
            goalIntentText: goalIntentText,
            reminderWindow: reminderWindow
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.failedResponse(statusCode: -1)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ProviderError.failedResponse(statusCode: httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        return decoded.bootstrap
    }
}
