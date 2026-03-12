import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @EnvironmentObject private var notificationService: NotificationService
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \AppSettings.id) private var settingsRows: [AppSettings]

    @State private var reminderHour = 8
    @State private var reminderMinute = 0

    private var settings: AppSettings? {
        settingsRows.first
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Subscription") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(subscriptionService.isPremium ? "Premium" : "Free")
                            .foregroundStyle(subscriptionService.isPremium ? .green : .secondary)
                    }

                    Button("Restore Purchases") {
                        Task { await subscriptionService.restorePurchases() }
                    }

                    if let error = subscriptionService.errorMessage, !error.isEmpty {
                        Text(error)
                            .font(WWTypography.detail())
                            .foregroundStyle(.red)
                    }
                }

                Section("Reminder") {
                    DatePicker(
                        "Daily Reminder",
                        selection: Binding(
                            get: {
                                Calendar.current.date(from: DateComponents(hour: reminderHour, minute: reminderMinute)) ?? .now
                            },
                            set: { value in
                                let components = Calendar.current.dateComponents([.hour, .minute], from: value)
                                reminderHour = components.hour ?? 8
                                reminderMinute = components.minute ?? 0
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )

                    Button("Enable Daily Reminder") {
                        Task {
                            let granted = await notificationService.requestAuthorization()
                            guard granted else { return }
                            await notificationService.scheduleDailyReminder(hour: reminderHour, minute: reminderMinute)

                            if let settings {
                                settings.preferredReminderHour = reminderHour
                                settings.preferredReminderMinute = reminderMinute
                                try? modelContext.save()
                            }
                        }
                    }
                }

                Section("Support") {
                    Text(AppConstants.supportEmail)
                    Text("Privacy URL and Support URL will be finalized after legal site deployment.")
                        .font(WWTypography.detail())
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                reminderHour = settings?.preferredReminderHour ?? 8
                reminderMinute = settings?.preferredReminderMinute ?? 0
            }
        }
    }
}
