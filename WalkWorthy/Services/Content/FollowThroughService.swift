import Foundation

struct FollowThroughContext: Equatable {
    let previousCommitmentText: String
    let previousFollowThroughStatus: FollowThroughStatus
    let daysSinceCommitment: Int?
}

enum FollowThroughService {
    static func pendingClosureCheck(
        in entries: [PrayerEntry],
        currentEntryID: UUID?
    ) -> PrayerEntry? {
        entries
            .sorted(by: { $0.createdAt > $1.createdAt })
            .first(where: { entry in
                guard entry.id != currentEntryID else { return false }
                guard entry.completedAt != nil else { return false }
                guard !entry.actionStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
                return entry.followThroughStatus == .unanswered
            })
    }

    static func growthPoints(
        for status: FollowThroughStatus?,
        hasPriorCommitmentToEvaluate: Bool
    ) -> Int {
        guard hasPriorCommitmentToEvaluate else { return 1 }
        switch status ?? .unanswered {
        case .yes:
            return 2
        case .partial:
            return 1
        case .no, .unanswered:
            return 0
        }
    }

    static func recordFollowThrough(
        status: FollowThroughStatus,
        for priorEntry: PrayerEntry,
        on currentEntry: PrayerEntry,
        at date: Date = .now
    ) {
        priorEntry.followThroughStatus = status
        priorEntry.followThroughAnsweredAt = date
        currentEntry.followThroughForEntryID = priorEntry.id
    }

    static func latestAnsweredContext(
        from entries: [PrayerEntry],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> FollowThroughContext? {
        guard
            let resolved = entries
                .sorted(by: { $0.createdAt > $1.createdAt })
                .first(where: { entry in
                    guard entry.completedAt != nil else { return false }
                    guard !entry.actionStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
                    return entry.followThroughStatus != .unanswered
                })
        else {
            return nil
        }

        let commitmentText = resolved.actionStep.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !commitmentText.isEmpty else { return nil }

        let days: Int?
        if let completedAt = resolved.completedAt {
            days = calendar.dateComponents([.day], from: calendar.startOfDay(for: completedAt), to: calendar.startOfDay(for: now)).day
        } else {
            days = nil
        }

        return FollowThroughContext(
            previousCommitmentText: commitmentText,
            previousFollowThroughStatus: resolved.followThroughStatus,
            daysSinceCommitment: days
        )
    }
}
