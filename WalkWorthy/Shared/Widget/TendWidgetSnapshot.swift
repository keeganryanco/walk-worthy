import Foundation

struct TendWidgetSnapshot: Codable, Equatable {
    static let currentVersion = 1

    let version: Int
    let hasActiveJourney: Bool
    let activeJourneyTitle: String
    let scriptureSnippet: String
    let todayStep: String
    let streakCount: Int
    let updatedAt: Date

    init(
        version: Int = TendWidgetSnapshot.currentVersion,
        hasActiveJourney: Bool,
        activeJourneyTitle: String,
        scriptureSnippet: String,
        todayStep: String,
        streakCount: Int,
        updatedAt: Date
    ) {
        self.version = version
        self.hasActiveJourney = hasActiveJourney
        self.activeJourneyTitle = activeJourneyTitle
        self.scriptureSnippet = scriptureSnippet
        self.todayStep = todayStep
        self.streakCount = streakCount
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? TendWidgetSnapshot.currentVersion
        hasActiveJourney = try container.decodeIfPresent(Bool.self, forKey: .hasActiveJourney) ?? false
        activeJourneyTitle = try container.decodeIfPresent(String.self, forKey: .activeJourneyTitle) ?? "No Active Journey"
        scriptureSnippet = try container.decodeIfPresent(String.self, forKey: .scriptureSnippet) ?? "Open Tend and start a journey."
        todayStep = try container.decodeIfPresent(String.self, forKey: .todayStep) ?? "Start your first tend"
        streakCount = try container.decodeIfPresent(Int.self, forKey: .streakCount) ?? 0
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
    }

    static var empty: TendWidgetSnapshot {
        TendWidgetSnapshot(
            hasActiveJourney: false,
            activeJourneyTitle: "No Active Journey",
            scriptureSnippet: "Open Tend and start a journey.",
            todayStep: "Start your first tend",
            streakCount: 0,
            updatedAt: .now
        )
    }
}

enum TendWidgetSnapshotStore {
    static let appGroupID = AppConstants.appGroupID
    private static let storageKey = "tend.widget.snapshot.v1"

    static func save(_ snapshot: TendWidgetSnapshot) {
        guard let defaults = userDefaults() else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: storageKey)
    }

    static func load() -> TendWidgetSnapshot? {
        guard let defaults = userDefaults() else { return nil }
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(TendWidgetSnapshot.self, from: data)
    }

    static func clear() {
        guard let defaults = userDefaults() else { return }
        defaults.removeObject(forKey: storageKey)
    }

    private static func userDefaults() -> UserDefaults? {
        if let grouped = UserDefaults(suiteName: appGroupID) {
            return grouped
        }
        return UserDefaults.standard
    }
}
