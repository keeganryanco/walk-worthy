import Foundation
import SwiftData

@Model
final class JourneyMemorySnapshot {
    @Attribute(.unique) var id: UUID
    var journeyID: UUID
    var updatedAt: Date
    var summary: String
    var winsSummary: String
    var blockersSummary: String
    var preferredTone: String

    init(
        id: UUID = UUID(),
        journeyID: UUID,
        updatedAt: Date = .now,
        summary: String = "",
        winsSummary: String = "",
        blockersSummary: String = "",
        preferredTone: String = "grounded-encouraging"
    ) {
        self.id = id
        self.journeyID = journeyID
        self.updatedAt = updatedAt
        self.summary = summary
        self.winsSummary = winsSummary
        self.blockersSummary = blockersSummary
        self.preferredTone = preferredTone
    }
}

@Model
final class GlobalLightMemory {
    @Attribute(.unique) var id: UUID
    var updatedAt: Date
    var preferredTone: String

    init(
        id: UUID = UUID(),
        updatedAt: Date = .now,
        preferredTone: String = "grounded-encouraging"
    ) {
        self.id = id
        self.updatedAt = updatedAt
        self.preferredTone = preferredTone
    }
}
