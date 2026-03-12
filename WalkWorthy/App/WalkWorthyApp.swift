import SwiftUI
import SwiftData

@main
struct WalkWorthyApp: App {
    @StateObject private var subscriptionService = SubscriptionService()
    @StateObject private var notificationService = NotificationService()
    private let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                PrayerJourney.self,
                PrayerEntry.self,
                AnsweredPrayer.self,
                OnboardingProfile.self,
                AppSettings.self
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to initialize model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(subscriptionService)
                .environmentObject(notificationService)
        }
        .modelContainer(modelContainer)
    }
}
