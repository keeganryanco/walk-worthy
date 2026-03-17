import SwiftUI
import SwiftData

struct JourneysView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var connectivityService: ConnectivityService

    let isPremium: Bool
    let onRequirePaywall: (PaywallTriggerReason) -> Void

    @Query(filter: #Predicate<PrayerJourney> { !$0.isArchived }, sort: \PrayerJourney.createdAt, order: .reverse)
    private var journeys: [PrayerJourney]
    @Query(sort: \AppSettings.lastSessionDate, order: .reverse)
    private var settingsRows: [AppSettings]

    @State private var draftTitle = ""
    @State private var draftCategory = ""
    @State private var alertMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if journeys.isEmpty {
                        Text("No journeys yet. Start with one focused prayer area.")
                            .font(WWTypography.body(16))
                            .foregroundStyle(WWColor.charcoal.opacity(0.7))
                    } else {
                        ForEach(journeys) { journey in
                            NavigationLink {
                                JourneyDetailView(journey: journey)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(journey.title)
                                        .font(WWTypography.body(18).weight(.semibold))
                                        .foregroundStyle(WWColor.charcoal)
                                    Text(journey.category)
                                        .font(WWTypography.detail())
                                        .foregroundStyle(WWColor.sapphire)
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                }

                Section("Create Journey") {
                    TextField("Journey title", text: $draftTitle)
                    TextField("Category", text: $draftCategory)

                    Button("Create") {
                        createJourney()
                    }
                    .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Journeys")
            .scrollContentBackground(.hidden)
        }
        .alert("Unable to Create Journey", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func createJourney() {
        let activeCount = journeys.count
        let settings = settingsRows.first
        let decision = JourneyCreationPolicy.evaluate(
            isOnline: connectivityService.isOnline,
            hasPremium: isPremium,
            activeJourneyCount: activeCount,
            settings: settings
        )

        switch decision {
        case .allowed:
            break
        case .blocked(let reason):
            switch reason {
            case .noInternet:
                alertMessage = "You need an internet connection to start a new journey. You can still continue your existing journeys offline."
            case .paywallRequired, .freeTierLimitReached:
                onRequirePaywall(.secondJourney)
            }
            return
        }

        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = draftCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "General" : draftCategory

        let journey = PrayerJourney(title: title, category: category)
        modelContext.insert(journey)
        try? modelContext.save()

        draftTitle = ""
        draftCategory = ""
    }
}

struct JourneyDetailView: View {
    let journey: PrayerJourney

    var body: some View {
        List {
            Section("Overview") {
                Text(journey.title)
                    .font(WWTypography.section(24))
                Text(journey.category)
                    .font(WWTypography.detail())
                    .foregroundStyle(WWColor.sapphire)
            }

            Section("Recent Entries") {
                if journey.entries.isEmpty {
                    Text("No entries yet for this journey.")
                        .foregroundStyle(WWColor.charcoal.opacity(0.7))
                } else {
                    ForEach(journey.entries.sorted(by: { $0.createdAt > $1.createdAt })) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.prompt)
                                .font(WWTypography.body(16))
                            Text(entry.createdAt.formatted(date: .abbreviated, time: .omitted))
                                .font(WWTypography.detail())
                                .foregroundStyle(WWColor.charcoal.opacity(0.6))
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Journey")
        .navigationBarTitleDisplayMode(.inline)
    }
}
