import Foundation
import UserNotifications

@MainActor
final class NotificationService: ObservableObject {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

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
        center.removePendingNotificationRequests(withIdentifiers: ["daily_prayer_reminder"])

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "Walk Worthy"
        content.body = "Pray, take one step, and reflect."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_prayer_reminder", content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            return
        }
    }
}
