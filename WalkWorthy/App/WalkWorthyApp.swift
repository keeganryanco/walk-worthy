import SwiftUI
import SwiftData

@main
struct TendApp: App {
    @StateObject private var subscriptionService = SubscriptionService()
    @StateObject private var notificationService = NotificationService()
    @StateObject private var connectivityService = ConnectivityService()
    private let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                PrayerJourney.self,
                PrayerEntry.self,
                AnsweredPrayer.self,
                OnboardingProfile.self,
                AppSettings.self,
                JourneyMemorySnapshot.self,
                JourneyProgressEvent.self,
                DailyJourneyPackageRecord.self
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
                .environmentObject(connectivityService)
        }
        .modelContainer(modelContainer)
    }
}
