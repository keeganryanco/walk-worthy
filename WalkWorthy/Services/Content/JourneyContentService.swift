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

        let languageCode = AppLanguage.aiLanguageCode()

        let fallback = (try? await templateGenerator.generatePackage(
            profile: profile,
            journey: journey,
            recentEntries: recentEntries,
            memory: memory
        )) ?? DailyJourneyPackage(
            reflectionThought: languageCode == "es"
                ? "La constancia fiel se construye un día a la vez."
                : languageCode == "pt"
                    ? "A constância fiel é construída dia após dia."
                    : languageCode == "ja"
                        ? "忠実さは、一日一日の積み重ねによって育まれます。"
                    : languageCode == "ko"
                        ? "신실한 꾸준함은 하루하루 쌓여 갑니다."
                    : "Faithful consistency is built one day at a time.",
            scriptureReference: "Philippians 4:6-7",
            scriptureParaphrase: languageCode == "es"
                ? "Lleva tus preocupaciones a Dios en oración y recibe Su paz mientras das tu próximo paso."
                : languageCode == "pt"
                    ? "Leve suas preocupações a Deus em oração e receba Sua paz enquanto dá seu próximo passo."
                    : languageCode == "ja"
                        ? "不安を祈りのうちに神にゆだね、次の一歩を踏み出す中で主の平安を受け取りましょう。"
                    : languageCode == "ko"
                        ? "염려를 기도로 하나님께 올려 드리고, 다음 걸음을 내딛을 때 주님의 평안을 누리세요."
                    : "Bring your worries to God in prayer and receive His peace as you take your next step.",
            prayer: languageCode == "es"
                ? "Señor, afírmame en la confianza y guíame a una acción concreta hoy."
                : languageCode == "pt"
                    ? "Senhor, firma-me na confiança e guia-me a uma ação concreta hoje."
                    : languageCode == "ja"
                        ? "主よ、私の心を信頼のうちに堅くし、今日取るべき具体的な一歩へ導いてください。"
                    : languageCode == "ko"
                        ? "주님, 오늘 제 마음을 믿음 안에 굳게 세우시고 구체적인 한 걸음을 인도해 주세요."
                    : "Lord, ground me in trust and guide one concrete action today.",
            smallStepQuestion: DailyJourneyPackageValidation.defaultSmallStepQuestion,
            suggestedSteps: [
                languageCode == "es"
                    ? "Elige una acción específica que haga avanzar este camino."
                    : languageCode == "pt"
                        ? "Escolha uma ação específica que avance esta jornada."
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
