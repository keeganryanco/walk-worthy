import Foundation

struct TemplateTodayCardGenerator: TodayCardGenerating {
    private struct ScriptureReference: Equatable {
        let reference: String
        let canonicalIdea: String
    }

    private let prayerPromptsByGoal: [String: [String]] = [
        "consistency": [
            "Lord, make me faithful in small daily steps.",
            "Give me steadiness to show up with sincerity today."
        ],
        "courage": [
            "God, give me courage to obey in the next hard moment.",
            "Help me choose obedience over fear today."
        ],
        "peace": [
            "Lord, settle my heart and direct my next step.",
            "Teach me to trust You in this specific concern today."
        ],
        "discipline": [
            "Father, form holy discipline in my words and choices.",
            "Strengthen me to do what is right, not just what is easy."
        ],
        "service": [
            "Show me who to serve with humility today.",
            "Teach me to love actively, not only in intention."
        ]
    ]

    private let actionTemplatesByFocus: [String: [String]] = [
        "family": [
            "Send one intentional encouragement to a family member.",
            "Pray out loud for one person in your home today."
        ],
        "anxiety": [
            "Pause for 60 seconds, breathe, and pray before your next task.",
            "Write one fear and one trust statement in your reflection."
        ],
        "purpose": [
            "Complete one meaningful task you have delayed.",
            "Take one small action aligned with your calling today."
        ],
        "work": [
            "Start your next work block with a one-sentence prayer.",
            "Choose one conversation and lead it with gentleness."
        ],
        "relationships": [
            "Initiate one honest and gracious check-in today.",
            "Offer forgiveness or apology where needed."
        ],
        "health": [
            "Take a short walk and pray for strength while moving.",
            "Choose one healthy habit and complete it before noon."
        ]
    ]

    // Constrained to approved references so generated snippets stay tied to actual verses.
    private let scriptureByGoal: [String: [ScriptureReference]] = [
        "consistency": [
            ScriptureReference(reference: "Galatians 6:9", canonicalIdea: "Do not grow weary in doing good; there is fruit in faithful endurance."),
            ScriptureReference(reference: "1 Corinthians 15:58", canonicalIdea: "Stand firm and keep giving yourself fully to the work of the Lord.")
        ],
        "courage": [
            ScriptureReference(reference: "Joshua 1:9", canonicalIdea: "Be strong and courageous because God is with you wherever you go."),
            ScriptureReference(reference: "2 Timothy 1:7", canonicalIdea: "God gives power, love, and self-control instead of fear.")
        ],
        "peace": [
            ScriptureReference(reference: "Philippians 4:6-7", canonicalIdea: "Bring every anxiety to God in prayer and receive His peace."),
            ScriptureReference(reference: "Isaiah 26:3", canonicalIdea: "God keeps in perfect peace those whose minds are fixed on Him.")
        ],
        "discipline": [
            ScriptureReference(reference: "Colossians 3:23", canonicalIdea: "Work wholeheartedly as for the Lord in every task."),
            ScriptureReference(reference: "1 Corinthians 9:27", canonicalIdea: "Practice self-control and train your life with purpose.")
        ],
        "service": [
            ScriptureReference(reference: "Galatians 5:13", canonicalIdea: "Use your freedom to serve one another in love."),
            ScriptureReference(reference: "Mark 10:45", canonicalIdea: "Follow Christ by serving rather than seeking to be served.")
        ]
    ]

    func generateTodayCard(profile: OnboardingProfile, journeys: [PrayerJourney], date: Date = .now) -> TodayCard {
        let goalKey = normalize(profile.growthGoal)
        let focusKey = normalize(profile.prayerFocus)

        let prayerPrompt = pick(
            from: prayerPromptsByGoal[goalKey] ?? prayerPromptsByGoal["consistency"]!,
            seed: seed(for: "\(goalKey)-prompt", date: date)
        )

        let actionStep = pick(
            from: actionTemplatesByFocus[focusKey] ?? actionTemplatesByFocus["purpose"]!,
            seed: seed(for: "\(focusKey)-action", date: date)
        )

        let scripture = pick(
            from: scriptureByGoal[goalKey] ?? scriptureByGoal["consistency"]!,
            seed: seed(for: "\(goalKey)-scripture", date: date)
        )

        let generatedSnippet = buildConstrainedScriptureSnippet(
            reference: scripture.reference,
            canonicalIdea: scripture.canonicalIdea,
            profile: profile
        )

        let approvedReference = ScriptureReferenceValidator.isApproved(scripture.reference) ? scripture.reference : "Philippians 4:6-7"
        let approvedSnippet = ScriptureReferenceValidator.sanitizedSnippet(generatedSnippet)

        return TodayCard(
            prayerPrompt: prayerPrompt,
            actionStep: actionStep,
            scriptureReference: approvedReference,
            scriptureText: approvedSnippet
        )
    }

    private func buildConstrainedScriptureSnippet(
        reference: String,
        canonicalIdea: String,
        profile: OnboardingProfile
    ) -> String {
        // This simulates constrained AI output for MVP: reference is selected from approved list,
        // and snippet is generated from a stable canonical idea to reduce hallucination risk.
        let emphasis = profile.growthGoal.lowercased() == "peace" ? "Rest in that promise today." : "Take one step in response today."
        return "\(canonicalIdea) \(emphasis)"
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func seed(for key: String, date: Date) -> Int {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return abs("\(key)-\(day)".hashValue)
    }

    private func pick<T>(from items: [T], seed: Int) -> T {
        items[seed % items.count]
    }
}
