import Foundation

struct TemplateTodayCardGenerator: TodayCardGenerating {
    private struct ScriptureSnippet {
        let reference: String
        let text: String
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

    private let scriptureByGoal: [String: [ScriptureSnippet]] = [
        "consistency": [
            ScriptureSnippet(reference: "Galatians 6:9", text: "Let us not be weary in well doing: for in due season we shall reap, if we faint not."),
            ScriptureSnippet(reference: "1 Corinthians 15:58", text: "Be ye stedfast, unmoveable, always abounding in the work of the Lord.")
        ],
        "courage": [
            ScriptureSnippet(reference: "Joshua 1:9", text: "Be strong and of a good courage; be not afraid... for the Lord thy God is with thee."),
            ScriptureSnippet(reference: "2 Timothy 1:7", text: "God hath not given us the spirit of fear; but of power, and of love, and of a sound mind.")
        ],
        "peace": [
            ScriptureSnippet(reference: "Philippians 4:6", text: "Be careful for nothing; but in every thing by prayer... let your requests be made known unto God."),
            ScriptureSnippet(reference: "Isaiah 26:3", text: "Thou wilt keep him in perfect peace, whose mind is stayed on thee.")
        ],
        "discipline": [
            ScriptureSnippet(reference: "1 Corinthians 9:27", text: "I keep under my body, and bring it into subjection."),
            ScriptureSnippet(reference: "Colossians 3:23", text: "Whatsoever ye do, do it heartily, as to the Lord.")
        ],
        "service": [
            ScriptureSnippet(reference: "Galatians 5:13", text: "By love serve one another."),
            ScriptureSnippet(reference: "Mark 10:45", text: "The Son of man came not to be ministered unto, but to minister.")
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

        return TodayCard(
            prayerPrompt: prayerPrompt,
            actionStep: actionStep,
            scriptureReference: scripture.reference,
            scriptureText: scripture.text
        )
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
