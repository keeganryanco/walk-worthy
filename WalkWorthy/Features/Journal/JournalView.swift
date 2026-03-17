import SwiftUI
import SwiftData

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var connectivityService: ConnectivityService
    
    let isPremium: Bool
    let onRequirePaywall: (PaywallTriggerReason) -> Void
    
    @Query(sort: \PrayerJourney.createdAt, order: .reverse)
    private var allJourneys: [PrayerJourney]
    
    @State private var isCreating = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(allJourneys) { journey in
                        NavigationLink(destination: JourneyDetailView(journey: journey)) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(journey.title)
                                        .font(WWTypography.body(18).weight(.semibold))
                                        .foregroundStyle(WWColor.nearBlack)
                                    Spacer()
                                    if journey.isArchived {
                                        Text("Memory")
                                            .font(WWTypography.caption())
                                            .foregroundStyle(WWColor.morningGold)
                                    }
                                }
                                Text(journey.category)
                                    .font(WWTypography.detail())
                                    .foregroundStyle(WWColor.growGreen)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                
                Section {
                    Button("Start New Journey") {
                        isCreating = true
                    }
                    .foregroundStyle(WWColor.growGreen)
                }
            }
            .navigationTitle("Journal")
            .scrollContentBackground(.hidden)
            .background(WWColor.surface.ignoresSafeArea())
            .sheet(isPresented: $isCreating) {
                CreateJourneyView(isPremium: isPremium, onRequirePaywall: onRequirePaywall)
            }
        }
    }
}

struct CreateJourneyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var connectivityService: ConnectivityService
    
    let isPremium: Bool
    let onRequirePaywall: (PaywallTriggerReason) -> Void
    
    @Query(filter: #Predicate<PrayerJourney> { !$0.isArchived })
    private var activeJourneys: [PrayerJourney]
    
    @Query(sort: \AppSettings.lastSessionDate, order: .reverse)
    private var settingsRows: [AppSettings]
    
    @State private var draftTitle = ""
    @State private var draftCategory = ""
    @State private var alertMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Journey Details") {
                    TextField("What are you praying for?", text: $draftTitle)
                    TextField("Category (e.g. Peace, Family)", text: $draftCategory)
                }
            }
            .navigationTitle("New Journey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createJourney()
                    }
                    .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
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
    }
    
    private func createJourney() {
        let activeCount = activeJourneys.count
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

        dismiss()
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
                    .foregroundStyle(WWColor.growGreen)
            }

            Section("Recent Entries") {
                if journey.entries.isEmpty {
                    Text("No entries yet for this journey.")
                        .foregroundStyle(WWColor.nearBlack.opacity(0.7))
                } else {
                    ForEach(journey.entries.sorted(by: { $0.createdAt > $1.createdAt })) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.prompt)
                                .font(WWTypography.body(16))
                                .foregroundStyle(WWColor.nearBlack)
                            Text(entry.createdAt.formatted(date: .abbreviated, time: .omitted))
                                .font(WWTypography.detail())
                                .foregroundStyle(WWColor.nearBlack.opacity(0.6))
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
