import Foundation
import SwiftData
import UserNotifications

@MainActor
final class NotificationService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var pendingDeepLinkURL: URL?

    private let center = UNUserNotificationCenter.current()
    private let managedReminderPrefix = "daily_prayer_reminder_"
    private let managedProactivePrefix = "proactive_campaign_"
    private let reminderHorizonDays = 7
    private let proactiveHorizonDays = 3
    private let maxManagedRequests = 60
    private let maxProactivePerDay = 2
    private let deepLinkUserInfoKey = "deep_link"

    private struct TendedJourneyContext {
        let journeyTitle: String
        let actionStep: String
        let scriptureSnippet: String
        let scriptureReference: String
    }

    private struct ProactiveCandidate {
        let campaign: NotificationCampaign
        let priority: Int
        let journey: PrayerJourney
        let entries: [PrayerEntry]
    }

    override init() {
        super.init()
        center.delegate = self
        registerNotificationCategories()
    }

    func consumePendingDeepLink() {
        pendingDeepLinkURL = nil
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            return false
        }
    }

    func recordAppOpen(modelContext: ModelContext, now: Date = .now) {
        let settings = loadOrCreateAppSettings(in: modelContext)
        JourneyEngagementService.registerAppOpen(in: settings, at: now)
        try? modelContext.save()
    }

    func scheduleDailyReminder(hour: Int, minute: Int) async {
        await removeManagedReminderRequests()
        await scheduleRepeatingReminderRequest(
            identifier: "\(managedReminderPrefix)legacy_default",
            hour: hour,
            minute: minute
        )
    }

    func scheduleReminderSchedules(
        _ reminders: [ReminderSchedule],
        modelContext: ModelContext? = nil,
        now: Date = .now
    ) async {
        await removeManagedReminderRequests()

        let enabled = reminders
            .filter(\.isEnabled)
            .sorted {
                if $0.sortOrder == $1.sortOrder {
                    return ($0.normalizedHour, $0.normalizedMinute) < ($1.normalizedHour, $1.normalizedMinute)
                }
                return $0.sortOrder < $1.sortOrder
            }

        if !enabled.isEmpty {
            let tendedContextsToday = modelContext.map { loadTendedJourneyContextsForToday(from: $0, now: now) } ?? []
            let useSequencedToday = !tendedContextsToday.isEmpty

            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: now)
            var scheduledCount = 0

            for dayOffset in 0..<reminderHorizonDays {
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
                let daySlots = enabled
                    .compactMap { reminder -> (reminder: ReminderSchedule, fireDate: Date)? in
                        var components = calendar.dateComponents([.year, .month, .day], from: day)
                        components.hour = reminder.normalizedHour
                        components.minute = reminder.normalizedMinute
                        guard let fireDate = calendar.date(from: components), fireDate > now else { return nil }
                        return (reminder, fireDate)
                    }
                    .sorted { $0.fireDate < $1.fireDate }

                for (slotIndex, slot) in daySlots.enumerated() {
                    guard scheduledCount < maxManagedRequests else { return }
                    let dayKey = dayIdentifier(for: slot.fireDate)
                    let identifier = "\(managedReminderPrefix)\(dayKey)_\(slot.reminder.id.uuidString.lowercased())"
                    let content: UNMutableNotificationContent
                    if dayOffset == 0 && useSequencedToday {
                        content = sequencedReminderContent(slotIndex: slotIndex, tendedContexts: tendedContextsToday)
                    } else {
                        content = genericReminderContent()
                    }
                    await scheduleReminderRequest(
                        identifier: identifier,
                        fireDate: slot.fireDate,
                        content: content
                    )
                    scheduledCount += 1
                }
            }
        }

        if let modelContext {
            await scheduleProactiveCampaigns(reminders: enabled, modelContext: modelContext, now: now)
        }
    }

    func clearAllReminderSchedules() async {
        await removeManagedReminderRequests()
        await removeManagedProactiveRequests()
    }

    private func scheduleProactiveCampaigns(
        reminders: [ReminderSchedule],
        modelContext: ModelContext,
        now: Date
    ) async {
        await removeManagedProactiveRequests()

        let settings = loadOrCreateAppSettings(in: modelContext)
        let journeys = loadActiveJourneys(from: modelContext)
        guard !journeys.isEmpty else {
            try? modelContext.save()
            return
        }

        let entriesByJourneyID = loadEntriesByJourneyID(from: modelContext)
        let calendar = Calendar.current

        var candidates: [ProactiveCandidate] = []

        for journey in journeys {
            let entries = entriesByJourneyID[journey.id] ?? []
            JourneyEngagementService.refreshJourneyState(
                for: journey,
                entries: entries,
                now: now,
                calendar: calendar
            )

            let streakStatus = JourneyEngagementService.streakStatus(
                for: entries,
                now: now,
                calendar: calendar
            )
            let reignite = JourneyEngagementService.reigniteEligibility(
                for: journey,
                entries: entries,
                now: now,
                calendar: calendar
            )

            if reignite.isEligible {
                candidates.append(
                    ProactiveCandidate(
                        campaign: .reigniteOffer,
                        priority: 0,
                        journey: journey,
                        entries: entries
                    )
                )
            }

            if streakStatus.isAtRisk {
                candidates.append(
                    ProactiveCandidate(
                        campaign: .streakRisk,
                        priority: 1,
                        journey: journey,
                        entries: entries
                    )
                )
            }

            let daysSinceLatest = streakStatus.daysSinceLatest ?? Int.max
            if daysSinceLatest >= 2 {
                candidates.append(
                    ProactiveCandidate(
                        campaign: .inactiveJourneyNudge,
                        priority: 2,
                        journey: journey,
                        entries: entries
                    )
                )
            }
        }

        let sortedCandidates = candidates.sorted { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.journey.createdAt < rhs.journey.createdAt
            }
            return lhs.priority < rhs.priority
        }

        let selector = AdaptiveSendTimeSelector(calendar: calendar)
        let startOfToday = calendar.startOfDay(for: now)
        var scheduledTimes: [Date] = []
        var countByDay: [String: Int] = [:]
        var scheduledKeys: Set<String> = []

        for candidate in sortedCandidates {
            let candidateKey = "\(candidate.campaign.rawValue)_\(candidate.journey.id.uuidString.lowercased())"
            if scheduledKeys.contains(candidateKey) {
                continue
            }

            for dayOffset in 0..<proactiveHorizonDays {
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
                let dayKey = dayIdentifier(for: day)
                if countByDay[dayKey, default: 0] >= maxProactivePerDay {
                    continue
                }

                guard let sendDate = selector.selectSendDate(
                    for: day,
                    settings: settings,
                    reminders: reminders,
                    alreadyScheduled: scheduledTimes,
                    now: now
                ) else {
                    continue
                }

                if !campaignCooldownSatisfied(
                    campaign: candidate.campaign,
                    for: candidate.journey,
                    proposedDate: sendDate
                ) {
                    continue
                }

                let identifier = "\(managedProactivePrefix)\(dayKey)_\(candidateKey)"
                let payload = campaignContent(
                    campaign: candidate.campaign,
                    journey: candidate.journey,
                    entries: candidate.entries,
                    now: now,
                    calendar: calendar
                )

                await scheduleReminderRequest(identifier: identifier, fireDate: sendDate, content: payload)
                scheduledTimes.append(sendDate)
                countByDay[dayKey, default: 0] += 1
                scheduledKeys.insert(candidateKey)
                setCampaignLastScheduledDate(
                    campaign: candidate.campaign,
                    for: candidate.journey,
                    date: sendDate
                )
                break
            }
        }

        try? modelContext.save()
    }

    private func campaignCooldownSatisfied(
        campaign: NotificationCampaign,
        for journey: PrayerJourney,
        proposedDate: Date
    ) -> Bool {
        guard let lastScheduledAt = campaignLastScheduledDate(campaign: campaign, for: journey) else {
            return true
        }
        return proposedDate.timeIntervalSince(lastScheduledAt) >= campaign.cooldownSeconds
    }

    private func campaignLastScheduledDate(
        campaign: NotificationCampaign,
        for journey: PrayerJourney
    ) -> Date? {
        switch campaign {
        case .inactiveJourneyNudge:
            return journey.lastInactiveNudgeAt
        case .streakRisk:
            return journey.lastStreakRiskNudgeAt
        case .reigniteOffer:
            return journey.lastReigniteOfferAt
        }
    }

    private func setCampaignLastScheduledDate(
        campaign: NotificationCampaign,
        for journey: PrayerJourney,
        date: Date
    ) {
        switch campaign {
        case .inactiveJourneyNudge:
            journey.lastInactiveNudgeAt = date
        case .streakRisk:
            journey.lastStreakRiskNudgeAt = date
        case .reigniteOffer:
            journey.lastReigniteOfferAt = date
        }
    }

    private func campaignContent(
        campaign: NotificationCampaign,
        journey: PrayerJourney,
        entries: [PrayerEntry],
        now: Date,
        calendar: Calendar
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.categoryIdentifier = campaign.categoryIdentifier

        switch campaign {
        case .inactiveJourneyNudge:
            content.title = "Your Plant Is Ready"
            content.body = compact("\(journey.title) is ready for a fresh Tend.", maxLength: 150)
            content.userInfo = [deepLinkUserInfoKey: homeDeepLink(journeyID: journey.id)]
        case .streakRisk:
            let streak = JourneyEngagementService.effectiveStreakCount(
                for: journey,
                entries: entries,
                now: now,
                calendar: calendar
            )
            content.title = "Keep Your Streak"
            content.body = compact("Don’t lose your \(max(streak, 1))-day streak on \(journey.title).", maxLength: 150)
            content.userInfo = [deepLinkUserInfoKey: homeDeepLink(journeyID: journey.id)]
        case .reigniteOffer:
            content.title = "Reignite Your Streak"
            content.body = compact(
                "Restore your \(max(journey.streakCountBeforeLoss, 1))-day streak with one tap.",
                maxLength: 150
            )
            content.userInfo = [deepLinkUserInfoKey: homeDeepLink(journeyID: journey.id, action: "reignite")]
        }

        return content
    }

    private func homeDeepLink(journeyID: UUID, action: String? = nil) -> String {
        var components = URLComponents()
        components.scheme = AppConstants.DeepLink.scheme
        components.host = AppConstants.DeepLink.homeHost

        var items: [URLQueryItem] = [
            URLQueryItem(name: "journey", value: journeyID.uuidString.lowercased())
        ]
        if let action {
            items.append(URLQueryItem(name: "action", value: action))
        }
        components.queryItems = items
        return components.url?.absoluteString ?? "\(AppConstants.DeepLink.scheme)://\(AppConstants.DeepLink.homeHost)"
    }

    private func scheduleRepeatingReminderRequest(identifier: String, hour: Int, minute: Int) async {
        var components = DateComponents()
        components.hour = min(max(hour, 0), 23)
        components.minute = min(max(minute, 0), 59)

        let content = genericReminderContent()

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            return
        }
    }

    private func scheduleReminderRequest(
        identifier: String,
        fireDate: Date,
        content: UNMutableNotificationContent
    ) async {
        var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        components.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            return
        }
    }

    private func genericReminderContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Tend"
        content.body = "Pray, take one step, and reflect."
        content.sound = .default
        return content
    }

    private func sequencedReminderContent(slotIndex: Int, tendedContexts: [TendedJourneyContext]) -> UNMutableNotificationContent {
        guard !tendedContexts.isEmpty else { return genericReminderContent() }

        // For each tended journey: [action encouragement, scripture, prayer-topic reminder]
        let sequenceLength = max(1, tendedContexts.count * 3)
        let normalizedIndex = slotIndex % sequenceLength
        let journeyIndex = normalizedIndex / 3
        let phase = normalizedIndex % 3
        let context = tendedContexts[min(journeyIndex, tendedContexts.count - 1)]

        let content = UNMutableNotificationContent()
        content.sound = .default

        switch phase {
        case 0:
            content.title = "Take Today's Step"
            content.body = compact("Keep going on \(context.journeyTitle): \(context.actionStep).", maxLength: 150)
        case 1:
            content.title = "Today's Scripture"
            if context.scriptureSnippet.isEmpty {
                content.body = compact("Take a moment with \(context.scriptureReference).", maxLength: 150)
            } else if context.scriptureReference.isEmpty {
                content.body = compact(context.scriptureSnippet, maxLength: 150)
            } else {
                content.body = compact("\(context.scriptureSnippet) — \(context.scriptureReference)", maxLength: 150)
            }
        default:
            content.title = "Prayer Check-In"
            content.body = compact("Take a minute to pray about \(context.journeyTitle) today.", maxLength: 150)
        }

        return content
    }

    private func loadTendedJourneyContextsForToday(from modelContext: ModelContext, now: Date) -> [TendedJourneyContext] {
        let descriptor = FetchDescriptor<PrayerEntry>(
            sortBy: [SortDescriptor(\PrayerEntry.createdAt, order: .forward)]
        )
        let allEntries = (try? modelContext.fetch(descriptor)) ?? []
        let calendar = Calendar.current

        var earliestByJourney: [UUID: PrayerEntry] = [:]

        for entry in allEntries {
            guard let completedAt = entry.completedAt, calendar.isDate(completedAt, inSameDayAs: now) else { continue }
            guard let journey = entry.journey, !journey.isArchived else { continue }

            let journeyID = journey.id
            if let current = earliestByJourney[journeyID],
               let currentCompletedAt = current.completedAt,
               currentCompletedAt <= completedAt {
                continue
            }
            earliestByJourney[journeyID] = entry
        }

        let sortedEntries = earliestByJourney.values.sorted {
            guard let lhs = $0.completedAt, let rhs = $1.completedAt else { return false }
            return lhs < rhs
        }

        return sortedEntries.compactMap { entry in
            guard let journey = entry.journey else { return nil }
            return TendedJourneyContext(
                journeyTitle: compact(journey.title, maxLength: 64),
                actionStep: compact(
                    entry.actionStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "the step you committed to today"
                        : entry.actionStep,
                    maxLength: 92
                ),
                scriptureSnippet: compact(entry.scriptureText, maxLength: 120),
                scriptureReference: compact(entry.scriptureReference, maxLength: 36)
            )
        }
    }

    private func loadOrCreateAppSettings(in modelContext: ModelContext) -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>(
            sortBy: [SortDescriptor(\AppSettings.firstLaunchAt, order: .forward)]
        )
        if let settings = try? modelContext.fetch(descriptor).first {
            return settings
        }

        let settings = AppSettings()
        modelContext.insert(settings)
        return settings
    }

    private func loadActiveJourneys(from modelContext: ModelContext) -> [PrayerJourney] {
        let descriptor = FetchDescriptor<PrayerJourney>(
            predicate: #Predicate<PrayerJourney> { !$0.isArchived },
            sortBy: [SortDescriptor(\PrayerJourney.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func loadEntriesByJourneyID(from modelContext: ModelContext) -> [UUID: [PrayerEntry]] {
        let descriptor = FetchDescriptor<PrayerEntry>(
            sortBy: [SortDescriptor(\PrayerEntry.createdAt, order: .reverse)]
        )
        let allEntries = (try? modelContext.fetch(descriptor)) ?? []
        var byJourney: [UUID: [PrayerEntry]] = [:]
        for entry in allEntries {
            guard let journeyID = entry.journey?.id else { continue }
            byJourney[journeyID, default: []].append(entry)
        }
        return byJourney
    }

    private func dayIdentifier(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    private func compact(_ value: String, maxLength: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        let hard = String(trimmed.prefix(maxLength))
        if let space = hard.lastIndex(of: " "), space > hard.startIndex {
            return String(hard[..<space]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return hard
    }

    private func registerNotificationCategories() {
        let categories = Set(NotificationCampaign.allCases.map { campaign in
            UNNotificationCategory(
                identifier: campaign.categoryIdentifier,
                actions: [],
                intentIdentifiers: [],
                options: [.customDismissAction]
            )
        })
        center.setNotificationCategories(categories)
    }

    private func removeManagedReminderRequests() async {
        let pending = await pendingRequests()
        let managedIDs = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(managedReminderPrefix) || $0 == "daily_prayer_reminder" }
        guard !managedIDs.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: managedIDs)
    }

    private func removeManagedProactiveRequests() async {
        let pending = await pendingRequests()
        let managedIDs = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(managedProactivePrefix) }
        guard !managedIDs.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: managedIDs)
    }

    private func pendingRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }
}

enum NotificationCampaign: String, CaseIterable {
    case inactiveJourneyNudge
    case streakRisk
    case reigniteOffer

    var categoryIdentifier: String {
        "campaign_\(rawValue)"
    }

    var cooldownSeconds: TimeInterval {
        switch self {
        case .inactiveJourneyNudge:
            return 48 * 60 * 60
        case .streakRisk:
            return 24 * 60 * 60
        case .reigniteOffer:
            return 24 * 60 * 60
        }
    }
}

struct AdaptiveSendTimeSelector {
    private let calendar: Calendar
    private let allowedHours: ClosedRange<Int>

    init(calendar: Calendar = .current, allowedHours: ClosedRange<Int> = 9...20) {
        self.calendar = calendar
        self.allowedHours = allowedHours
    }

    func selectSendDate(
        for day: Date,
        settings: AppSettings,
        reminders: [ReminderSchedule],
        alreadyScheduled: [Date],
        now: Date,
        maxAttempts: Int = 12
    ) -> Date? {
        let preferredHours = JourneyEngagementService.topOpenHours(
            from: settings,
            allowedHours: allowedHours,
            limit: 3
        )

        let dayStart = calendar.startOfDay(for: day)
        let reminderTimes = reminderDates(for: dayStart, reminders: reminders)

        for attempt in 0..<maxAttempts {
            let seed = Int(dayStart.timeIntervalSince1970) ^ (attempt * 173) ^ (preferredHours.count * 31)
            let hourIndex = seededIndex(seed: seed, upperBound: preferredHours.count)
            let baseHour = preferredHours[hourIndex]
            let minute = seededMinute(seed: seed)

            var components = calendar.dateComponents([.year, .month, .day], from: dayStart)
            components.hour = min(max(baseHour, allowedHours.lowerBound), allowedHours.upperBound)
            components.minute = minute
            components.second = 0

            guard let candidate = calendar.date(from: components), candidate > now else { continue }
            if isTooCloseToReminders(candidate, reminderTimes: reminderTimes) {
                continue
            }
            if violatesSpacing(candidate, existing: alreadyScheduled, minimumHoursBetween: 6) {
                continue
            }
            return candidate
        }

        return fallbackDate(for: dayStart, reminders: reminderTimes, existing: alreadyScheduled, now: now)
    }

    private func reminderDates(for dayStart: Date, reminders: [ReminderSchedule]) -> [Date] {
        reminders
            .filter(\.isEnabled)
            .compactMap { reminder in
                var components = calendar.dateComponents([.year, .month, .day], from: dayStart)
                components.hour = reminder.normalizedHour
                components.minute = reminder.normalizedMinute
                components.second = 0
                return calendar.date(from: components)
            }
    }

    private func fallbackDate(
        for dayStart: Date,
        reminders: [Date],
        existing: [Date],
        now: Date
    ) -> Date? {
        for hour in allowedHours {
            var components = calendar.dateComponents([.year, .month, .day], from: dayStart)
            components.hour = hour
            components.minute = 0
            components.second = 0
            guard let candidate = calendar.date(from: components), candidate > now else { continue }
            if isTooCloseToReminders(candidate, reminderTimes: reminders) {
                continue
            }
            if violatesSpacing(candidate, existing: existing, minimumHoursBetween: 6) {
                continue
            }
            return candidate
        }
        return nil
    }

    private func violatesSpacing(_ candidate: Date, existing: [Date], minimumHoursBetween: Int) -> Bool {
        let minimumSeconds = TimeInterval(minimumHoursBetween * 60 * 60)
        for current in existing {
            if abs(current.timeIntervalSince(candidate)) < minimumSeconds {
                return true
            }
        }
        return false
    }

    private func isTooCloseToReminders(_ candidate: Date, reminderTimes: [Date], thresholdMinutes: Int = 90) -> Bool {
        let threshold = TimeInterval(thresholdMinutes * 60)
        return reminderTimes.contains { abs($0.timeIntervalSince(candidate)) < threshold }
    }

    private func seededMinute(seed: Int) -> Int {
        let positive = abs(seed)
        return positive % 60
    }

    private func seededIndex(seed: Int, upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return abs(seed) % upperBound
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let deepLinkValue = response.notification.request.content.userInfo["deep_link"] as? String,
              let url = URL(string: deepLinkValue)
        else {
            return
        }

        await MainActor.run {
            self.pendingDeepLinkURL = url
        }
    }
}
