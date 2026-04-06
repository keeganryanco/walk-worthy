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
        throw NSError(
            domain: "Tend.AI",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: L10n.string(
                    "content.error.remote_provider_missing",
                    default: "Remote AI provider is not configured."
                )
            ]
        )
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
        let recentFollowThroughStatus = FollowThroughService
            .latestAnsweredContext(from: recentEntries)?
            .previousFollowThroughStatus

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
                let validated = DailyJourneyPackageValidation.validated(
                    remote,
                    followThroughStatus: recentFollowThroughStatus
                )
                let uniqueScripturePackage = enforceUniqueScriptureReference(
                    in: validated,
                    journeyID: journey.id,
                    dayKey: dayKey,
                    recentEntries: recentEntries,
                    modelContext: modelContext
                )
                persist(
                    uniqueScripturePackage,
                    journeyID: journey.id,
                    dayKey: dayKey,
                    source: .remote,
                    modelContext: modelContext
                )
                return JourneyPackageResult(package: uniqueScripturePackage, source: .remote)
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
            reflectionThought: AppLanguage.aiLanguageCode() == "es"
                ? "La constancia fiel se construye un día a la vez."
                : "Faithful consistency is built one day at a time.",
            scriptureReference: "Philippians 4:6-7",
            scriptureParaphrase: AppLanguage.aiLanguageCode() == "es"
                ? "Lleva tus preocupaciones a Dios en oración y recibe Su paz mientras das tu próximo paso."
                : "Bring your worries to God in prayer and receive His peace as you take your next step.",
            prayer: AppLanguage.aiLanguageCode() == "es"
                ? "Señor, afírmame en la confianza y guíame a una acción concreta hoy."
                : "Lord, ground me in trust and guide one concrete action today.",
            smallStepQuestion: DailyJourneyPackageValidation.defaultSmallStepQuestion,
            suggestedSteps: [
                AppLanguage.aiLanguageCode() == "es"
                    ? "Elige una acción específica que haga avanzar este camino."
                    : "Choose one specific action that moves this journey forward."
            ],
            completionSuggestion: CompletionSuggestion(
                shouldPrompt: false,
                reason: "",
                confidence: 0
            ),
            generatedAt: date
        )

        let validatedFallback = DailyJourneyPackageValidation.validated(
            fallback,
            followThroughStatus: recentFollowThroughStatus
        )
        let uniqueFallback = enforceUniqueScriptureReference(
            in: validatedFallback,
            journeyID: journey.id,
            dayKey: dayKey,
            recentEntries: recentEntries,
            modelContext: modelContext
        )
        persist(
            uniqueFallback,
            journeyID: journey.id,
            dayKey: dayKey,
            source: .template,
            modelContext: modelContext
        )

        return JourneyPackageResult(package: uniqueFallback, source: .template)
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
            completionSuggestion: package.completionSuggestion,
            generatedAt: package.generatedAt,
            source: source
        )
        modelContext.insert(record)
        try? modelContext.save()
    }

    private func enforceUniqueScriptureReference(
        in package: DailyJourneyPackage,
        journeyID: UUID,
        dayKey: String,
        recentEntries: [PrayerEntry],
        modelContext: ModelContext
    ) -> DailyJourneyPackage {
        let usedReferences = usedScriptureReferences(
            journeyID: journeyID,
            excludingDayKey: dayKey,
            recentEntries: recentEntries,
            modelContext: modelContext
        )

        let currentReference = package.scriptureReference.trimmingCharacters(in: .whitespacesAndNewlines)
        if !currentReference.isEmpty, !usedReferences.contains(currentReference) {
            return package
        }

        let replacementReference = ScriptureReferenceValidator.deterministicApprovedReference(
            seed: "\(journeyID.uuidString)-\(dayKey)",
            excluding: usedReferences
        )
        let replacementParaphrase = ScriptureReferenceValidator.enforceParaphraseFidelity(
            reference: replacementReference,
            paraphrase: ScriptureReferenceValidator.fallbackParaphrase(for: replacementReference) ?? package.scriptureParaphrase
        )

        return DailyJourneyPackage(
            reflectionThought: package.reflectionThought,
            scriptureReference: replacementReference,
            scriptureParaphrase: replacementParaphrase,
            prayer: package.prayer,
            smallStepQuestion: package.smallStepQuestion,
            suggestedSteps: package.suggestedSteps,
            completionSuggestion: package.completionSuggestion,
            generatedAt: package.generatedAt
        )
    }

    private func usedScriptureReferences(
        journeyID: UUID,
        excludingDayKey: String,
        recentEntries: [PrayerEntry],
        modelContext: ModelContext
    ) -> Set<String> {
        let fromEntries = recentEntries
            .map { $0.scriptureReference.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let descriptor = FetchDescriptor<DailyJourneyPackageRecord>(
            predicate: #Predicate { $0.journeyID == journeyID }
        )
        let fromPackages = (try? modelContext.fetch(descriptor))?
            .filter { $0.dayKey != excludingDayKey }
            .map { $0.scriptureReference.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []

        return Set(fromEntries + fromPackages)
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
