import Foundation
import SwiftData

enum JourneyThemeKey: String, Codable, CaseIterable {
    case basic
    case faith
    case patience
    case peace
    case resilience
    case community
    case discipline
    case healing
    case joy
    case wisdom
}

enum JourneyStatus: String, Codable, CaseIterable {
    case active
    case completed
}

@Model
final class PrayerJourney {
    @Attribute(.unique) var id: UUID
    var title: String
    var category: String
    var createdAt: Date
    var isArchived: Bool
    var colorToken: String
    var themeKeyRaw: String?
    var statusRaw: String?
    var cycleCountStored: Int?
    var completedTendsStored: Int?
    var lastCompletionPromptAt: Date?
    var lastTendedAt: Date?
    var hydrationStageStored: Int?
    var growthProgressStored: Double?
    var streakLostAt: Date?
    var streakCountBeforeLossStored: Int?
    var reigniteUsedForLossStored: Bool?
    var reigniteOverlayShownAt: Date?
    var reignitedStreakOffsetStored: Int?
    var lastInactiveNudgeAt: Date?
    var lastStreakRiskNudgeAt: Date?
    var lastReigniteOfferAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \PrayerEntry.journey)
    var entries: [PrayerEntry]

    @Relationship(deleteRule: .cascade, inverse: \AnsweredPrayer.journey)
    var answeredPrayers: [AnsweredPrayer]

    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        themeKey: JourneyThemeKey = .basic,
        status: JourneyStatus = .active,
        createdAt: Date = .now,
        isArchived: Bool = false,
        colorToken: String = "sage",
        cycleCount: Int = 0,
        completedTends: Int = 0,
        lastCompletionPromptAt: Date? = nil,
        lastTendedAt: Date? = nil,
        hydrationStage: Int = 3,
        growthProgress: Double? = nil,
        streakLostAt: Date? = nil,
        streakCountBeforeLoss: Int = 0,
        reigniteUsedForLoss: Bool = false,
        reigniteOverlayShownAt: Date? = nil,
        reignitedStreakOffset: Int = 0,
        lastInactiveNudgeAt: Date? = nil,
        lastStreakRiskNudgeAt: Date? = nil,
        lastReigniteOfferAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.colorToken = colorToken
        self.themeKeyRaw = themeKey.rawValue
        self.statusRaw = status.rawValue
        self.cycleCountStored = cycleCount
        self.completedTendsStored = completedTends
        self.lastCompletionPromptAt = lastCompletionPromptAt
        self.lastTendedAt = lastTendedAt
        self.hydrationStageStored = min(max(hydrationStage, 0), 3)
        self.growthProgressStored = growthProgress
        self.streakLostAt = streakLostAt
        self.streakCountBeforeLossStored = max(0, streakCountBeforeLoss)
        self.reigniteUsedForLossStored = reigniteUsedForLoss
        self.reigniteOverlayShownAt = reigniteOverlayShownAt
        self.reignitedStreakOffsetStored = max(0, reignitedStreakOffset)
        self.lastInactiveNudgeAt = lastInactiveNudgeAt
        self.lastStreakRiskNudgeAt = lastStreakRiskNudgeAt
        self.lastReigniteOfferAt = lastReigniteOfferAt
        self.entries = []
        self.answeredPrayers = []
    }

    var themeKey: JourneyThemeKey {
        get { JourneyThemeKey(rawValue: themeKeyRaw ?? "") ?? .basic }
        set { themeKeyRaw = newValue.rawValue }
    }

    var status: JourneyStatus {
        get { JourneyStatus(rawValue: statusRaw ?? "") ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var cycleCount: Int {
        get { max(0, cycleCountStored ?? 0) }
        set { cycleCountStored = max(0, newValue) }
    }

    var completedTends: Int {
        get { max(0, completedTendsStored ?? 0) }
        set { completedTendsStored = max(0, newValue) }
    }

    var hydrationStage: Int {
        get { min(max(hydrationStageStored ?? 3, 0), 3) }
        set { hydrationStageStored = min(max(newValue, 0), 3) }
    }

    var growthProgress: Double {
        get { max(Double(completedTends), growthProgressStored ?? Double(completedTends)) }
        set { growthProgressStored = max(0, newValue) }
    }

    var streakCountBeforeLoss: Int {
        get { max(0, streakCountBeforeLossStored ?? 0) }
        set { streakCountBeforeLossStored = max(0, newValue) }
    }

    var reignitedStreakOffset: Int {
        get { max(0, reignitedStreakOffsetStored ?? 0) }
        set { reignitedStreakOffsetStored = max(0, newValue) }
    }

    var reigniteUsedForLoss: Bool {
        get { reigniteUsedForLossStored ?? false }
        set { reigniteUsedForLossStored = newValue }
    }
}

struct JourneyStreakStatus {
    let latestCompletedDay: Date?
    let contiguousFromLatest: Int
    let daysSinceLatest: Int?
    let activeStreak: Int

    var isAtRisk: Bool {
        activeStreak > 0 && daysSinceLatest == 1
    }

    var isLost: Bool {
        activeStreak == 0 && (daysSinceLatest ?? 0) >= 2
    }
}

struct ReigniteEligibility {
    let isEligible: Bool
    let recoverableStreak: Int
    let remainingSeconds: TimeInterval
}

struct GrowthUpdateResult {
    let appliedGrowth: Double
    let hydrationStageBeforeTend: Int
    let progressAfterUpdate: Double
    let completedTendsAfterUpdate: Int
}

enum JourneyEngagementService {
    static let hydrationMaxStage = 3
    static let reigniteWindowSeconds: TimeInterval = 72 * 60 * 60

    static func registerAppOpen(
        in settings: AppSettings,
        at date: Date = .now,
        calendar: Calendar = .current
    ) {
        let hour = min(max(calendar.component(.hour, from: date), 0), 23)
        var histogram = settings.appOpenHourHistogram
        histogram[hour] += 1
        settings.appOpenHourHistogram = histogram
        settings.lastAppOpenAt = date
    }

    static func topOpenHours(
        from settings: AppSettings,
        allowedHours: ClosedRange<Int> = 9...20,
        limit: Int = 3
    ) -> [Int] {
        let histogram = settings.appOpenHourHistogram
        let ranked = allowedHours
            .map { ($0, histogram[$0]) }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0 < rhs.0
                }
                return lhs.1 > rhs.1
            }
            .filter { $0.1 > 0 }
            .prefix(max(1, limit))
            .map(\.0)

        if !ranked.isEmpty {
            return ranked
        }

        let fallback = [9, 13, 18].filter { allowedHours.contains($0) }
        return fallback.isEmpty ? [allowedHours.lowerBound] : fallback
    }

    static func streakStatus(
        for entries: [PrayerEntry],
        now: Date,
        calendar: Calendar = .current
    ) -> JourneyStreakStatus {
        let completedDays: [Date] = Array(Set(entries.compactMap { entry in
            guard let completedAt = entry.completedAt else { return nil }
            return calendar.startOfDay(for: completedAt)
        }))
        .sorted(by: >)

        guard let latest = completedDays.first else {
            return JourneyStreakStatus(
                latestCompletedDay: nil,
                contiguousFromLatest: 0,
                daysSinceLatest: nil,
                activeStreak: 0
            )
        }

        var contiguous = 1
        var previous = latest
        for day in completedDays.dropFirst() {
            let delta = calendar.dateComponents([.day], from: day, to: previous).day ?? 0
            if delta == 1 {
                contiguous += 1
                previous = day
            } else {
                break
            }
        }

        let today = calendar.startOfDay(for: now)
        let daysSinceLatest = calendar.dateComponents([.day], from: latest, to: today).day ?? 0
        let active = daysSinceLatest <= 1 ? contiguous : 0

        return JourneyStreakStatus(
            latestCompletedDay: latest,
            contiguousFromLatest: contiguous,
            daysSinceLatest: daysSinceLatest,
            activeStreak: active
        )
    }

    static func effectiveStreakCount(
        for journey: PrayerJourney,
        entries: [PrayerEntry],
        now: Date,
        calendar: Calendar = .current
    ) -> Int {
        let status = streakStatus(for: entries, now: now, calendar: calendar)
        if status.activeStreak == 0 {
            return max(0, journey.reignitedStreakOffset)
        }
        return max(0, status.activeStreak + journey.reignitedStreakOffset)
    }

    static func refreshJourneyState(
        for journey: PrayerJourney,
        entries: [PrayerEntry],
        now: Date,
        calendar: Calendar = .current
    ) {
        if let latestCompletion = entries.compactMap(\.completedAt).max() {
            journey.lastTendedAt = latestCompletion
            let daysSinceTend = max(
                0,
                calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: latestCompletion),
                    to: calendar.startOfDay(for: now)
                ).day ?? 0
            )
            journey.hydrationStage = max(0, hydrationMaxStage - daysSinceTend)
        } else {
            journey.lastTendedAt = nil
            journey.hydrationStage = 0
        }

        let status = streakStatus(for: entries, now: now, calendar: calendar)

        if status.isLost, let latestCompletedDay = status.latestCompletedDay {
            let computedLossDate = calendar.date(byAdding: .day, value: 2, to: latestCompletedDay) ?? now
            if journey.streakLostAt == nil || (journey.streakLostAt ?? now) < computedLossDate {
                journey.streakLostAt = computedLossDate
                journey.streakCountBeforeLoss = max(
                    1,
                    status.contiguousFromLatest + journey.reignitedStreakOffset
                )
                journey.reigniteUsedForLoss = false
                journey.reigniteOverlayShownAt = nil
            }
            journey.reignitedStreakOffset = 0
            return
        }

        if status.activeStreak > 0 {
            journey.streakLostAt = nil
            journey.streakCountBeforeLoss = 0
            journey.reigniteUsedForLoss = false
            journey.reigniteOverlayShownAt = nil
        }
    }

    static func reigniteEligibility(
        for journey: PrayerJourney,
        entries: [PrayerEntry],
        now: Date,
        calendar: Calendar = .current
    ) -> ReigniteEligibility {
        let status = streakStatus(for: entries, now: now, calendar: calendar)
        guard status.activeStreak == 0,
              let lossDate = journey.streakLostAt,
              !journey.reigniteUsedForLoss,
              journey.streakCountBeforeLoss > 0
        else {
            return ReigniteEligibility(isEligible: false, recoverableStreak: 0, remainingSeconds: 0)
        }

        let deadline = lossDate.addingTimeInterval(reigniteWindowSeconds)
        let remaining = deadline.timeIntervalSince(now)
        guard remaining > 0 else {
            return ReigniteEligibility(isEligible: false, recoverableStreak: 0, remainingSeconds: 0)
        }

        return ReigniteEligibility(
            isEligible: true,
            recoverableStreak: journey.streakCountBeforeLoss,
            remainingSeconds: remaining
        )
    }

    static func applyReignite(
        to journey: PrayerJourney,
        entries: [PrayerEntry],
        at now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let eligibility = reigniteEligibility(for: journey, entries: entries, now: now, calendar: calendar)
        guard eligibility.isEligible else { return false }

        let status = streakStatus(for: entries, now: now, calendar: calendar)
        let baseStreak = status.activeStreak
        let offset = max(0, eligibility.recoverableStreak - baseStreak)

        journey.reignitedStreakOffset = offset
        journey.reigniteUsedForLoss = true
        journey.reigniteOverlayShownAt = now
        journey.streakLostAt = nil
        return true
    }

    static func growthMultiplier(for hydrationStage: Int) -> Double {
        switch hydrationStage {
        case 3:
            return 1.15
        case 2:
            return 1.0
        case 1:
            return 0.82
        default:
            return 0.65
        }
    }

    static func applyCompletionGrowth(
        to journey: PrayerJourney,
        inferredLegacyCount: Int,
        baseGrowthPoints: Int,
        at completionDate: Date
    ) -> GrowthUpdateResult {
        let hydrationBefore = journey.hydrationStage
        let multiplier = growthMultiplier(for: hydrationBefore)
        let base = max(0.5, Double(baseGrowthPoints))
        let applied = max(0.3, base * multiplier)

        let baseline = max(
            journey.growthProgress,
            Double(journey.completedTends),
            Double(max(0, inferredLegacyCount))
        )
        let nextProgress = baseline + applied

        journey.growthProgress = nextProgress
        journey.completedTends = Int(floor(nextProgress))
        journey.lastTendedAt = completionDate
        journey.hydrationStage = hydrationMaxStage

        return GrowthUpdateResult(
            appliedGrowth: applied,
            hydrationStageBeforeTend: hydrationBefore,
            progressAfterUpdate: nextProgress,
            completedTendsAfterUpdate: journey.completedTends
        )
    }
}
