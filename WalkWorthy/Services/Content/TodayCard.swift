import Foundation

struct TodayCard: Equatable {
    let prayerPrompt: String
    let actionStep: String
    let scriptureReference: String
    let scriptureText: String
}

protocol TodayCardGenerating {
    func generateTodayCard(profile: OnboardingProfile, journeys: [PrayerJourney], date: Date) -> TodayCard
}
