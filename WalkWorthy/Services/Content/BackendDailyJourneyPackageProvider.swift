import Foundation
import os

private let aiLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "co.keeganryan.tend", category: "AI")
private let aiGatewayRequestTimeout: TimeInterval = 75

struct JourneyArcPayload: Codable, Equatable {
    let purpose: String
    let journeyPurpose: String?
    let currentStage: String
    let todayAim: String?
    let nextMovement: String
    let tone: String
    let practicalActionDirection: String
    let recentDayTitles: [String]?
    let lastFollowThroughInterpretation: String?
    let specificContextSignals: [String]?

    init(
        purpose: String,
        journeyPurpose: String? = nil,
        currentStage: String,
        todayAim: String? = nil,
        nextMovement: String,
        tone: String,
        practicalActionDirection: String,
        recentDayTitles: [String]? = nil,
        lastFollowThroughInterpretation: String? = nil,
        specificContextSignals: [String]? = nil
    ) {
        self.purpose = purpose
        self.journeyPurpose = journeyPurpose
        self.currentStage = currentStage
        self.todayAim = todayAim
        self.nextMovement = nextMovement
        self.tone = tone
        self.practicalActionDirection = practicalActionDirection
        self.recentDayTitles = recentDayTitles
        self.lastFollowThroughInterpretation = lastFollowThroughInterpretation
        self.specificContextSignals = specificContextSignals
    }
}

struct JourneySeedPayload: Codable, Equatable {
    struct InitialMemory: Codable, Equatable {
        let summary: String
        let winsSummary: String
        let blockersSummary: String
        let preferredTone: String
    }

    let journeyTitle: String
    let journeyCategory: String
    let themeKey: String
    let growthFocus: String?
    let journeyArc: JourneyArcPayload?
    let initialMemory: InitialMemory
}

struct DevotionalCorePayload: Codable, Equatable {
    let centralConcern: String?
    let biblicalTheme: String?
    let devotionalPoint: String?
    let scriptureFitReason: String?
    let dailyTitle: String
    let scriptureReference: String
    let scriptureParaphrase: String
    let reflectionThought: String
    let prayer: String
    let todayAim: String
    let updatedJourneyArc: JourneyArcPayload?
}

struct ActionLayerPayload: Codable, Equatable {
    let smallStepQuestion: String
    let suggestedSteps: [String]
    let completionSuggestion: CompletionSuggestion
}

struct BackendDailyJourneyPackageProvider: RemoteDailyJourneyPackageProviding {
    private struct RequestBody: Encodable {
        struct Telemetry: Encodable {
            let distinctID: String
            let appVersion: String
            let buildNumber: String
            let platform: String
        }

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
            let scriptureReference: String
            let completedAt: String?
            let followThroughStatus: String?
        }

        struct FollowThroughContext: Encodable {
            let previousCommitmentText: String
            let previousFollowThroughStatus: String
            let daysSinceCommitment: Int?
        }

        let profile: Profile
        let journey: Journey
        let memory: Memory?
        let journeyArc: JourneyArcPayload?
        let recentEntries: [RecentEntry]
        let usedScriptureReferences: [String]
        let followThroughContext: FollowThroughContext?
        let cycleCount: Int
        let completionCount: Int
        let recentJourneySignals: [String]
        let dateISO: String
        let languageCode: String
        let localeIdentifier: String
        let telemetry: Telemetry
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

    private struct CoreResponseBody: Decodable {
        let core: DevotionalCorePayload
    }

    private struct ActionRequestBody: Encodable {
        let profile: RequestBody.Profile
        let journey: RequestBody.Journey
        let memory: RequestBody.Memory?
        let journeyArc: JourneyArcPayload?
        let recentEntries: [RequestBody.RecentEntry]
        let usedScriptureReferences: [String]
        let followThroughContext: RequestBody.FollowThroughContext?
        let cycleCount: Int
        let completionCount: Int
        let recentJourneySignals: [String]
        let dateISO: String
        let languageCode: String
        let localeIdentifier: String
        let telemetry: RequestBody.Telemetry
        let core: DevotionalCorePayload
    }

    private struct ActionResponseBody: Decodable {
        let action: ActionLayerPayload
    }

    private enum ProviderError: LocalizedError {
        case missingBaseURL
        case invalidURL
        case failedResponse(statusCode: Int, bodySnippet: String?)
        case decodeFailure(bodySnippet: String)

        var errorDescription: String? {
            switch self {
            case .missingBaseURL:
                return "AI gateway URL is not configured."
            case .invalidURL:
                return "AI gateway URL is invalid."
            case .failedResponse(let statusCode, let bodySnippet):
                if let bodySnippet, !bodySnippet.isEmpty {
                    return "AI gateway returned status \(statusCode): \(bodySnippet)"
                }
                return "AI gateway returned status \(statusCode)."
            case .decodeFailure(let bodySnippet):
                return "AI gateway response could not be decoded: \(bodySnippet)"
            }
        }
    }

    func generatePackage(
        profile: OnboardingProfile,
        journey: PrayerJourney,
        recentEntries: [PrayerEntry],
        memory: JourneyMemorySnapshot?
    ) async throws -> DailyJourneyPackage {
        let core = try await generateCore(
            profile: profile,
            journey: journey,
            recentEntries: recentEntries,
            memory: memory
        )
        let action = try await generateAction(
            profile: profile,
            journey: journey,
            recentEntries: recentEntries,
            memory: memory,
            core: core
        )
        return DailyJourneyPackageValidation.validated(
            DailyJourneyPackage(
                dailyTitle: core.dailyTitle,
                reflectionThought: core.reflectionThought,
                scriptureReference: core.scriptureReference,
                scriptureParaphrase: core.scriptureParaphrase,
                prayer: core.prayer,
                todayAim: core.todayAim,
                smallStepQuestion: action.smallStepQuestion,
                suggestedSteps: action.suggestedSteps,
                completionSuggestion: action.completionSuggestion,
                updatedJourneyArc: core.updatedJourneyArc,
                qualityVersion: DailyJourneyPackage.currentQualityVersion,
                generatedAt: .now
            ),
            followThroughStatus: FollowThroughService
                .latestAnsweredContext(from: recentEntries)?
                .previousFollowThroughStatus
        )
    }

    func generateCore(
        profile: OnboardingProfile,
        journey: PrayerJourney,
        recentEntries: [PrayerEntry],
        memory: JourneyMemorySnapshot?
    ) async throws -> DevotionalCorePayload {
        let body = buildBody(profile: profile, journey: journey, recentEntries: recentEntries, memory: memory)
        let endpoint = try endpoint(path: "/api/v1/journey-core", logLabel: "journey-core")
        let data = try await postJSON(body, to: endpoint, logLabel: "journey-core")
        let decoded: CoreResponseBody
        do {
            decoded = try JSONDecoder().decode(CoreResponseBody.self, from: data)
        } catch {
            let snippet = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(400) ?? "<non-utf8>"
            aiLogger.error("journey-core decode failed error=\(error.localizedDescription, privacy: .public) body=\(String(snippet), privacy: .public)")
            throw ProviderError.decodeFailure(bodySnippet: String(snippet))
        }
        return decoded.core
    }

    func generateAction(
        profile: OnboardingProfile,
        journey: PrayerJourney,
        recentEntries: [PrayerEntry],
        memory: JourneyMemorySnapshot?,
        core: DevotionalCorePayload
    ) async throws -> ActionLayerPayload {
        let baseBody = buildBody(profile: profile, journey: journey, recentEntries: recentEntries, memory: memory)
        let body = ActionRequestBody(
            profile: baseBody.profile,
            journey: baseBody.journey,
            memory: baseBody.memory,
            journeyArc: baseBody.journeyArc,
            recentEntries: baseBody.recentEntries,
            usedScriptureReferences: baseBody.usedScriptureReferences,
            followThroughContext: baseBody.followThroughContext,
            cycleCount: baseBody.cycleCount,
            completionCount: baseBody.completionCount,
            recentJourneySignals: baseBody.recentJourneySignals,
            dateISO: baseBody.dateISO,
            languageCode: baseBody.languageCode,
            localeIdentifier: baseBody.localeIdentifier,
            telemetry: baseBody.telemetry,
            core: core
        )
        let endpoint = try endpoint(path: "/api/v1/journey-action", logLabel: "journey-action")
        let data = try await postJSON(body, to: endpoint, logLabel: "journey-action")
        let decoded: ActionResponseBody
        do {
            decoded = try JSONDecoder().decode(ActionResponseBody.self, from: data)
        } catch {
            let snippet = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(400) ?? "<non-utf8>"
            aiLogger.error("journey-action decode failed error=\(error.localizedDescription, privacy: .public) body=\(String(snippet), privacy: .public)")
            throw ProviderError.decodeFailure(bodySnippet: String(snippet))
        }
        return decoded.action
    }

    private func endpoint(path: String, logLabel: String) throws -> URL {
        let baseURLString = AppConstants.AI.gatewayBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseURLString.isEmpty else {
            aiLogger.error("\(logLabel, privacy: .public) blocked: TENDAI_BASE_URL is empty")
            throw ProviderError.missingBaseURL
        }

        guard let baseURL = URL(string: baseURLString) else {
            aiLogger.error("\(logLabel, privacy: .public) blocked: TENDAI_BASE_URL invalid '\(baseURLString, privacy: .public)'")
            throw ProviderError.invalidURL
        }

        let endpoint = baseURL.appendingPathComponent(path)
        aiLogger.log("\(logLabel, privacy: .public) request start endpoint=\(endpoint.absoluteString, privacy: .public)")
        return endpoint
    }

    private func postJSON<T: Encodable>(_ body: T, to endpoint: URL, logLabel: String) async throws -> Data {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = aiGatewayRequestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let appKey = AppConstants.AI.gatewayAppKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !appKey.isEmpty {
            request.setValue(appKey, forHTTPHeaderField: "x-tend-app-key")
        } else {
            aiLogger.error("\(logLabel, privacy: .public) warning: TENDAI_APP_KEY empty (request will be unauthorized if backend requires shared secret)")
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            aiLogger.error("\(logLabel, privacy: .public) failed: non-HTTP response")
            throw ProviderError.failedResponse(statusCode: -1, bodySnippet: nil)
        }

        aiLogger.log("\(logLabel, privacy: .public) response status=\(httpResponse.statusCode)")
        guard (200...299).contains(httpResponse.statusCode) else {
            let bodySnippet = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(400)
            let snippet = bodySnippet.map(String.init)
            aiLogger.error("\(logLabel, privacy: .public) failed status=\(httpResponse.statusCode) body=\(snippet ?? "<empty>", privacy: .public)")
            throw ProviderError.failedResponse(statusCode: httpResponse.statusCode, bodySnippet: snippet)
        }
        return data
    }

    private func buildBody(
        profile: OnboardingProfile,
        journey: PrayerJourney,
        recentEntries: [PrayerEntry],
        memory: JourneyMemorySnapshot?
    ) -> RequestBody {
        let journeyGrowthFocus = journey.growthFocus.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveGrowthGoal = journeyGrowthFocus.isEmpty
            ? profile.growthGoal
            : journeyGrowthFocus
        let profilePayload = RequestBody.Profile(
            prayerFocus: profile.prayerFocus,
            growthGoal: effectiveGrowthGoal,
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
                    scriptureReference: entry.scriptureReference.trimmingCharacters(in: .whitespacesAndNewlines),
                    completedAt: entry.completedAt.map { dateFormatter.string(from: $0) },
                    followThroughStatus: entry.followThroughStatus == .unanswered ? nil : entry.followThroughStatus.rawValue
                )
            }

        let usedScriptureReferences = Array(
            Set(
                recentEntries
                    .flatMap { ScriptureReferenceValidator.splitReferenceSet($0.scriptureReference) }
                    .filter { !$0.isEmpty }
            )
        ).sorted()

        let completionCount = recentEntries.filter { $0.completedAt != nil }.count
        let followThroughContext = FollowThroughService.latestAnsweredContext(from: recentEntries)
        let followThroughPayload = followThroughContext.map {
            RequestBody.FollowThroughContext(
                previousCommitmentText: $0.previousCommitmentText,
                previousFollowThroughStatus: $0.previousFollowThroughStatus.rawValue,
                daysSinceCommitment: $0.daysSinceCommitment
            )
        }
        let recentSignals = recentEntries
            .sorted(by: { $0.createdAt > $1.createdAt })
            .prefix(6)
            .compactMap { entry -> String? in
                let reflection = entry.userReflection.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !reflection.isEmpty else { return nil }
                return reflection
            }
        let seededSignals = journey.growthFocus.trimmingCharacters(in: .whitespacesAndNewlines)

        return RequestBody(
            profile: profilePayload,
            journey: journeyPayload,
            memory: memoryPayload,
            journeyArc: decodeJourneyArc(from: journey.journeyArc),
            recentEntries: recent,
            usedScriptureReferences: usedScriptureReferences,
            followThroughContext: followThroughPayload,
            cycleCount: journey.cycleCount,
            completionCount: completionCount,
            recentJourneySignals: seededSignals.isEmpty ? Array(recentSignals) : [seededSignals] + Array(recentSignals),
            dateISO: dateFormatter.string(from: .now),
            languageCode: AppLanguage.aiLanguageCode(),
            localeIdentifier: AppLanguage.aiLocaleIdentifier(),
            telemetry: RequestBody.Telemetry(
                distinctID: analyticsDistinctID(),
                appVersion: appVersion(),
                buildNumber: buildNumber(),
                platform: "ios"
            )
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
    let growthFocus: String?
    let journeyArc: JourneyArcPayload?
    let initialMemory: InitialMemory
    let initialPackage: DailyJourneyPackage
}

struct BackendJourneyBootstrapProvider {
    private struct RequestBody: Encodable {
        struct Telemetry: Encodable {
            let distinctID: String
            let appVersion: String
            let buildNumber: String
            let platform: String
        }

        let name: String
        let prayerIntentText: String
        let goalIntentText: String?
        let reminderWindow: String
        let languageCode: String
        let localeIdentifier: String
        let telemetry: Telemetry
    }

    private struct ResponseBody: Decodable {
        let bootstrap: JourneyBootstrapPayload
    }

    private struct SeedResponseBody: Decodable {
        let seed: JourneySeedPayload
    }

    private enum ProviderError: LocalizedError {
        case missingBaseURL
        case invalidURL
        case failedResponse(statusCode: Int, bodySnippet: String?)
        case decodeFailure(bodySnippet: String)

        var errorDescription: String? {
            switch self {
            case .missingBaseURL:
                return "AI gateway URL is not configured."
            case .invalidURL:
                return "AI gateway URL is invalid."
            case .failedResponse(let statusCode, let bodySnippet):
                if let bodySnippet, !bodySnippet.isEmpty {
                    return "AI gateway returned status \(statusCode): \(bodySnippet)"
                }
                return "AI gateway returned status \(statusCode)."
            case .decodeFailure(let bodySnippet):
                return "AI gateway response could not be decoded: \(bodySnippet)"
            }
        }
    }

    func bootstrap(
        name: String,
        prayerIntentText: String,
        goalIntentText: String? = nil,
        reminderWindow: String
    ) async throws -> JourneyBootstrapPayload {
        let baseURLString = AppConstants.AI.gatewayBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseURLString.isEmpty else {
            aiLogger.error("journey-bootstrap blocked: TENDAI_BASE_URL is empty")
            throw ProviderError.missingBaseURL
        }

        guard let baseURL = URL(string: baseURLString) else {
            aiLogger.error("journey-bootstrap blocked: TENDAI_BASE_URL invalid '\(baseURLString, privacy: .public)'")
            throw ProviderError.invalidURL
        }

        let endpoint = baseURL.appendingPathComponent("/api/v1/journey-bootstrap")
        aiLogger.log("journey-bootstrap request start endpoint=\(endpoint.absoluteString, privacy: .public)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = aiGatewayRequestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let appKey = AppConstants.AI.gatewayAppKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !appKey.isEmpty {
            request.setValue(appKey, forHTTPHeaderField: "x-tend-app-key")
        } else {
            aiLogger.error("journey-bootstrap warning: TENDAI_APP_KEY empty (request will be unauthorized if backend requires shared secret)")
        }

        let payload = RequestBody(
            name: name,
            prayerIntentText: prayerIntentText,
            goalIntentText: goalIntentText?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            reminderWindow: reminderWindow,
            languageCode: AppLanguage.aiLanguageCode(),
            localeIdentifier: AppLanguage.aiLocaleIdentifier(),
            telemetry: RequestBody.Telemetry(
                distinctID: analyticsDistinctID(),
                appVersion: appVersion(),
                buildNumber: buildNumber(),
                platform: "ios"
            )
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            aiLogger.error("journey-bootstrap failed: non-HTTP response")
            throw ProviderError.failedResponse(statusCode: -1, bodySnippet: nil)
        }

        aiLogger.log("journey-bootstrap response status=\(httpResponse.statusCode)")
        guard (200...299).contains(httpResponse.statusCode) else {
            let bodySnippet = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(400)
            let snippet = bodySnippet.map(String.init)
            aiLogger.error("journey-bootstrap failed status=\(httpResponse.statusCode) body=\(snippet ?? "<empty>", privacy: .public)")
            throw ProviderError.failedResponse(statusCode: httpResponse.statusCode, bodySnippet: snippet)
        }

        let decoded: ResponseBody
        do {
            decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        } catch {
            let snippet = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(400) ?? "<non-utf8>"
            aiLogger.error("journey-bootstrap decode failed error=\(error.localizedDescription, privacy: .public) body=\(String(snippet), privacy: .public)")
            throw ProviderError.decodeFailure(bodySnippet: String(snippet))
        }
        return decoded.bootstrap
    }

    func seed(
        name: String,
        prayerIntentText: String,
        goalIntentText: String? = nil,
        reminderWindow: String
    ) async throws -> JourneySeedPayload {
        let endpoint = try endpoint(path: "/api/v1/journey-seed", logLabel: "journey-seed")
        let payload = RequestBody(
            name: name,
            prayerIntentText: prayerIntentText,
            goalIntentText: goalIntentText?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            reminderWindow: reminderWindow,
            languageCode: AppLanguage.aiLanguageCode(),
            localeIdentifier: AppLanguage.aiLocaleIdentifier(),
            telemetry: RequestBody.Telemetry(
                distinctID: analyticsDistinctID(),
                appVersion: appVersion(),
                buildNumber: buildNumber(),
                platform: "ios"
            )
        )
        let data = try await postJSON(payload, to: endpoint, logLabel: "journey-seed")
        do {
            return try JSONDecoder().decode(SeedResponseBody.self, from: data).seed
        } catch {
            let snippet = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(400) ?? "<non-utf8>"
            aiLogger.error("journey-seed decode failed error=\(error.localizedDescription, privacy: .public) body=\(String(snippet), privacy: .public)")
            throw ProviderError.decodeFailure(bodySnippet: String(snippet))
        }
    }

    private func endpoint(path: String, logLabel: String) throws -> URL {
        let baseURLString = AppConstants.AI.gatewayBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseURLString.isEmpty else {
            aiLogger.error("\(logLabel, privacy: .public) blocked: TENDAI_BASE_URL is empty")
            throw ProviderError.missingBaseURL
        }

        guard let baseURL = URL(string: baseURLString) else {
            aiLogger.error("\(logLabel, privacy: .public) blocked: TENDAI_BASE_URL invalid '\(baseURLString, privacy: .public)'")
            throw ProviderError.invalidURL
        }

        let endpoint = baseURL.appendingPathComponent(path)
        aiLogger.log("\(logLabel, privacy: .public) request start endpoint=\(endpoint.absoluteString, privacy: .public)")
        return endpoint
    }

    private func postJSON<T: Encodable>(_ body: T, to endpoint: URL, logLabel: String) async throws -> Data {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = aiGatewayRequestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let appKey = AppConstants.AI.gatewayAppKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !appKey.isEmpty {
            request.setValue(appKey, forHTTPHeaderField: "x-tend-app-key")
        } else {
            aiLogger.error("\(logLabel, privacy: .public) warning: TENDAI_APP_KEY empty (request will be unauthorized if backend requires shared secret)")
        }

        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            aiLogger.error("\(logLabel, privacy: .public) failed: non-HTTP response")
            throw ProviderError.failedResponse(statusCode: -1, bodySnippet: nil)
        }

        aiLogger.log("\(logLabel, privacy: .public) response status=\(httpResponse.statusCode)")
        guard (200...299).contains(httpResponse.statusCode) else {
            let bodySnippet = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(400)
            let snippet = bodySnippet.map(String.init)
            aiLogger.error("\(logLabel, privacy: .public) failed status=\(httpResponse.statusCode) body=\(snippet ?? "<empty>", privacy: .public)")
            throw ProviderError.failedResponse(statusCode: httpResponse.statusCode, bodySnippet: snippet)
        }
        return data
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

func decodeJourneyArc(from rawValue: String) -> JourneyArcPayload? {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(JourneyArcPayload.self, from: data)
}

func encodeJourneyArc(_ arc: JourneyArcPayload?) -> String? {
    guard let arc, let data = try? JSONEncoder().encode(arc) else { return nil }
    return String(data: data, encoding: .utf8)
}

private func analyticsDistinctID() -> String {
    let defaults = UserDefaults.standard
    let key = "analytics.distinct_id"
    if let existing = defaults.string(forKey: key), !existing.isEmpty {
        return existing
    }
    let generated = UUID().uuidString.lowercased()
    defaults.set(generated, forKey: key)
    return generated
}

private func appVersion() -> String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
}

private func buildNumber() -> String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
}
