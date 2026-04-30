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
                if let updatedArc = uniqueScripturePackage.updatedJourneyArc,
                   let encoded = encodeJourneyArc(updatedArc) {
                    journey.journeyArc = encoded
                }
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

        let languageCode = AppLanguage.aiLanguageCode()

        let fallback = (try? await templateGenerator.generatePackage(
            profile: profile,
            journey: journey,
            recentEntries: recentEntries,
            memory: memory
        )) ?? DailyJourneyPackage(
            dailyTitle: DailyJourneyPackageValidation.defaultDailyTitle,
            reflectionThought: DailyJourneyPackageValidation.defaultReflectionThought,
            scriptureReference: "Philippians 4:6-7",
            scriptureParaphrase: languageCode == "es"
                ? "Lleva tus preocupaciones a Dios en oración y recibe Su paz mientras das tu próximo paso."
                : languageCode == "pt"
                    ? "Leve suas preocupações a Deus em oração e receba Sua paz enquanto dá seu próximo passo."
                    : languageCode == "de"
                        ? "Bring deine Sorgen im Gebet zu Gott und empfange Seinen Frieden, während du deinen nächsten Schritt gehst."
                    : languageCode == "ja"
                        ? "不安を祈りのうちに神にゆだね、次の一歩を踏み出す中で主の平安を受け取りましょう。"
                    : languageCode == "ko"
                        ? "염려를 기도로 하나님께 올려 드리고, 다음 걸음을 내딛을 때 주님의 평안을 누리세요."
                    : "Bring your worries to God in prayer and receive His peace as you take your next step.",
            prayer: DailyJourneyPackageValidation.defaultFirstPersonPrayer,
            todayAim: DailyJourneyPackageValidation.defaultTodayAim,
            smallStepQuestion: DailyJourneyPackageValidation.defaultSmallStepQuestion,
            suggestedSteps: [
                languageCode == "es"
                    ? "Elige una acción específica que haga avanzar este camino."
                    : languageCode == "pt"
                        ? "Escolha uma ação específica que avance esta jornada."
                        : languageCode == "de"
                            ? "Wähle eine konkrete Handlung, die diese Journey voranbringt."
                        : languageCode == "ja"
                            ? "この歩みを前に進める具体的な行動を一つ選びましょう。"
                        : languageCode == "ko"
                            ? "이 여정을 앞으로 나아가게 할 구체적인 행동 하나를 선택하세요."
                        : "Choose one specific action that moves this journey forward."
            ],
            completionSuggestion: CompletionSuggestion(
                shouldPrompt: false,
                reason: "",
                confidence: 0
            ),
            qualityVersion: DailyJourneyPackage.currentQualityVersion,
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
        guard let records = try? modelContext.fetch(descriptor) else { return nil }
        return records
            .filter { $0.qualityVersion >= DailyJourneyPackage.currentQualityVersion }
            .sorted { $0.generatedAt > $1.generatedAt }
            .first
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
            dailyTitle: package.dailyTitle,
            reflectionThought: package.reflectionThought,
            scriptureReference: package.scriptureReference,
            scriptureParaphrase: package.scriptureParaphrase,
            prayer: package.prayer,
            todayAim: package.todayAim,
            smallStepQuestion: package.smallStepQuestion,
            suggestedSteps: package.suggestedSteps,
            completionSuggestion: package.completionSuggestion,
            updatedJourneyArc: package.updatedJourneyArc,
            qualityVersion: package.qualityVersion,
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
            dailyTitle: package.dailyTitle,
            reflectionThought: package.reflectionThought,
            scriptureReference: replacementReference,
            scriptureParaphrase: replacementParaphrase,
            prayer: package.prayer,
            todayAim: package.todayAim,
            smallStepQuestion: package.smallStepQuestion,
            suggestedSteps: package.suggestedSteps,
            completionSuggestion: package.completionSuggestion,
            updatedJourneyArc: package.updatedJourneyArc,
            qualityVersion: package.qualityVersion,
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
