import Foundation
import SwiftData
import UserNotifications

@MainActor
final class NotificationService: ObservableObject {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private let managedReminderPrefix = "daily_prayer_reminder_"
    private let reminderHorizonDays = 7
    private let maxManagedRequests = 60

    private struct TendedJourneyContext {
        let journeyTitle: String
        let actionStep: String
        let scriptureSnippet: String
        let scriptureReference: String
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

        guard !enabled.isEmpty else { return }

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

    func clearAllReminderSchedules() async {
        await removeManagedReminderRequests()
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

    private func removeManagedReminderRequests() async {
        let pending = await pendingRequests()
        let managedIDs = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(managedReminderPrefix) || $0 == "daily_prayer_reminder" }
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
