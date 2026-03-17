import Foundation
import SwiftData

protocol RemoteDailyJourneyPackageProviding {
    func generatePackage(
        profile: OnboardingProfile,
        journey: PrayerJourney,
        recentEntries: [PrayerEntry],
        memory: JourneyMemorySnapshot?
    ) async throws -> DailyJourneyPackage
}

struct NoRemoteDailyJourneyPackageProvider: RemoteDailyJourneyPackageProviding {
    func generatePackage(
        profile: OnboardingProfile,
        journey: PrayerJourney,
        recentEntries: [PrayerEntry],
        memory: JourneyMemorySnapshot?
    ) async throws -> DailyJourneyPackage {
        throw NSError(domain: "Tend.AI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Remote AI provider is not configured."])
    }
}

struct JourneyPackageResult {
    let package: DailyJourneyPackage
    let source: DailyJourneyPackageSource
}

@MainActor
final class JourneyContentService {
    private let templateGenerator: DailyJourneyPackageGenerating
    private let remoteProvider: RemoteDailyJourneyPackageProviding

    init(
        templateGenerator: DailyJourneyPackageGenerating = TemplateDailyJourneyPackageGenerator(),
        remoteProvider: RemoteDailyJourneyPackageProviding = BackendDailyJourneyPackageProvider()
    ) {
        self.templateGenerator = templateGenerator
        self.remoteProvider = remoteProvider
    }

    func packageForDate(
        profile: OnboardingProfile,
        journey: PrayerJourney,
        recentEntries: [PrayerEntry],
        memory: JourneyMemorySnapshot?,
        date: Date = .now,
        isOnline: Bool,
        modelContext: ModelContext
    ) async -> JourneyPackageResult {
        let dayKey = Self.dayKey(for: date)

        if let cached = cachedRecord(journeyID: journey.id, dayKey: dayKey, in: modelContext) {
            return JourneyPackageResult(package: cached.asPackage, source: .cache)
        }

        if isOnline {
            do {
                let remote = try await remoteProvider.generatePackage(
                    profile: profile,
                    journey: journey,
                    recentEntries: recentEntries,
                    memory: memory
                )
                let validated = DailyJourneyPackageValidation.validated(remote)
                persist(
                    validated,
                    journeyID: journey.id,
                    dayKey: dayKey,
                    source: .remote,
                    modelContext: modelContext
                )
                return JourneyPackageResult(package: validated, source: .remote)
            } catch {
                // Fall back to deterministic local generation below.
            }
        }

        let fallback = (try? await templateGenerator.generatePackage(
            profile: profile,
            journey: journey,
            recentEntries: recentEntries,
            memory: memory
        )) ?? DailyJourneyPackage(
            reflectionThought: "Faithful consistency is built one day at a time.",
            scriptureReference: "Philippians 4:6-7",
            scriptureParaphrase: "Bring your worries to God in prayer and receive His peace as you take your next step.",
            prayer: "Lord, ground me in trust and guide one concrete action today.",
            smallStepQuestion: DailyJourneyPackageValidation.defaultSmallStepQuestion,
            suggestedSteps: ["Choose one specific action that moves this journey forward."],
            generatedAt: date
        )

        let validatedFallback = DailyJourneyPackageValidation.validated(fallback)
        persist(
            validatedFallback,
            journeyID: journey.id,
            dayKey: dayKey,
            source: .template,
            modelContext: modelContext
        )

        return JourneyPackageResult(package: validatedFallback, source: .template)
    }

    func prefetchForTodayAndTomorrow(
        profile: OnboardingProfile,
        journeys: [PrayerJourney],
        entriesByJourneyID: [UUID: [PrayerEntry]],
        memoryByJourneyID: [UUID: JourneyMemorySnapshot],
        isOnline: Bool,
        modelContext: ModelContext,
        now: Date = .now
    ) async {
        guard isOnline else { return }

        for journey in journeys {
            let entries = entriesByJourneyID[journey.id] ?? []
            let memory = memoryByJourneyID[journey.id]

            _ = await packageForDate(
                profile: profile,
                journey: journey,
                recentEntries: entries,
                memory: memory,
                date: now,
                isOnline: true,
                modelContext: modelContext
            )

            if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) {
                _ = await packageForDate(
                    profile: profile,
                    journey: journey,
                    recentEntries: entries,
                    memory: memory,
                    date: tomorrow,
                    isOnline: true,
                    modelContext: modelContext
                )
            }
        }
    }

    private func cachedRecord(journeyID: UUID, dayKey: String, in modelContext: ModelContext) -> DailyJourneyPackageRecord? {
        let descriptor = FetchDescriptor<DailyJourneyPackageRecord>(
            predicate: #Predicate {
                $0.journeyID == journeyID && $0.dayKey == dayKey
            }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func persist(
        _ package: DailyJourneyPackage,
        journeyID: UUID,
        dayKey: String,
        source: DailyJourneyPackageSource,
        modelContext: ModelContext
    ) {
        guard cachedRecord(journeyID: journeyID, dayKey: dayKey, in: modelContext) == nil else { return }
        let record = DailyJourneyPackageRecord(
            journeyID: journeyID,
            dayKey: dayKey,
            reflectionThought: package.reflectionThought,
            scriptureReference: package.scriptureReference,
            scriptureParaphrase: package.scriptureParaphrase,
            prayer: package.prayer,
            smallStepQuestion: package.smallStepQuestion,
            suggestedSteps: package.suggestedSteps,
            generatedAt: package.generatedAt,
            source: source
        )
        modelContext.insert(record)
        try? modelContext.save()
    }

    nonisolated static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
