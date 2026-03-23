import Foundation
import SwiftData

enum JourneyThemeKey: String, Codable, CaseIterable {
    case basic
    case faith
    case patience
    case peace
    case resilience
    case community
    case discipline
    case healing
    case joy
    case wisdom
}

enum JourneyStatus: String, Codable, CaseIterable {
    case active
    case completed
}

@Model
final class PrayerJourney {
    @Attribute(.unique) var id: UUID
    var title: String
    var category: String
    var createdAt: Date
    var isArchived: Bool
    var colorToken: String
    var themeKeyRaw: String?
    var statusRaw: String?
    var cycleCountStored: Int?
    var completedTendsStored: Int?
    var lastCompletionPromptAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \PrayerEntry.journey)
    var entries: [PrayerEntry]

    @Relationship(deleteRule: .cascade, inverse: \AnsweredPrayer.journey)
    var answeredPrayers: [AnsweredPrayer]

    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        themeKey: JourneyThemeKey = .basic,
        status: JourneyStatus = .active,
        createdAt: Date = .now,
        isArchived: Bool = false,
        colorToken: String = "sage",
        cycleCount: Int = 0,
        completedTends: Int = 0,
        lastCompletionPromptAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.colorToken = colorToken
        self.themeKeyRaw = themeKey.rawValue
        self.statusRaw = status.rawValue
        self.cycleCountStored = cycleCount
        self.completedTendsStored = completedTends
        self.lastCompletionPromptAt = lastCompletionPromptAt
        self.entries = []
        self.answeredPrayers = []
    }

    var themeKey: JourneyThemeKey {
        get { JourneyThemeKey(rawValue: themeKeyRaw ?? "") ?? .basic }
        set { themeKeyRaw = newValue.rawValue }
    }

    var status: JourneyStatus {
        get { JourneyStatus(rawValue: statusRaw ?? "") ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var cycleCount: Int {
        get { max(0, cycleCountStored ?? 0) }
        set { cycleCountStored = max(0, newValue) }
    }

    var completedTends: Int {
        get { max(0, completedTendsStored ?? 0) }
        set { completedTendsStored = max(0, newValue) }
    }
}
