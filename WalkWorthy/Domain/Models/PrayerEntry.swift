import Foundation
import SwiftData

enum FollowThroughStatus: String, Codable, CaseIterable {
    case yes
    case partial
    case no
    case unanswered
}

@Model
final class PrayerEntry {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var prompt: String
    var scriptureReference: String
    var scriptureText: String
    var actionStep: String
    var userReflection: String
    var completedAt: Date?
    var followThroughStatusRaw: String?
    var followThroughAnsweredAt: Date?
    var followThroughForEntryID: UUID?

    var journey: PrayerJourney?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        prompt: String,
        scriptureReference: String,
        scriptureText: String,
        actionStep: String,
        userReflection: String = "",
        completedAt: Date? = nil,
        followThroughStatus: FollowThroughStatus = .unanswered,
        followThroughAnsweredAt: Date? = nil,
        followThroughForEntryID: UUID? = nil,
        journey: PrayerJourney? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.prompt = prompt
        self.scriptureReference = scriptureReference
        self.scriptureText = scriptureText
        self.actionStep = actionStep
        self.userReflection = userReflection
        self.completedAt = completedAt
        self.followThroughStatusRaw = followThroughStatus.rawValue
        self.followThroughAnsweredAt = followThroughAnsweredAt
        self.followThroughForEntryID = followThroughForEntryID
        self.journey = journey
    }

    var followThroughStatus: FollowThroughStatus {
        get { FollowThroughStatus(rawValue: followThroughStatusRaw ?? "") ?? .unanswered }
        set { followThroughStatusRaw = newValue.rawValue }
    }
}
