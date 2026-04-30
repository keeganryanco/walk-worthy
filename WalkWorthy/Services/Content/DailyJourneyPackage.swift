import Foundation

struct CompletionSuggestion: Codable, Equatable {
    let shouldPrompt: Bool
    let reason: String
    let confidence: Double

    init(shouldPrompt: Bool, reason: String, confidence: Double) {
        self.shouldPrompt = shouldPrompt
        self.reason = reason
        self.confidence = confidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shouldPrompt = try container.decodeIfPresent(Bool.self, forKey: .shouldPrompt) ?? false
        reason = try container.decodeIfPresent(String.self, forKey: .reason) ?? ""
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0
    }
}

struct DailyJourneyPackage: Codable, Equatable {
    static let currentQualityVersion = 4

    let dailyTitle: String
    let reflectionThought: String
    let scriptureReference: String
    let scriptureParaphrase: String
    let prayer: String
    let todayAim: String
    let smallStepQuestion: String
    let suggestedSteps: [String]
    let completionSuggestion: CompletionSuggestion
    let updatedJourneyArc: JourneyArcPayload?
    let qualityVersion: Int
    let generatedAt: Date

    init(
        dailyTitle: String = DailyJourneyPackageValidation.defaultDailyTitle,
        reflectionThought: String,
        scriptureReference: String,
        scriptureParaphrase: String,
        prayer: String,
        todayAim: String = DailyJourneyPackageValidation.defaultTodayAim,
        smallStepQuestion: String,
        suggestedSteps: [String],
        completionSuggestion: CompletionSuggestion,
        updatedJourneyArc: JourneyArcPayload? = nil,
        qualityVersion: Int = DailyJourneyPackage.currentQualityVersion,
        generatedAt: Date
    ) {
        self.dailyTitle = dailyTitle
        self.reflectionThought = reflectionThought
        self.scriptureReference = scriptureReference
        self.scriptureParaphrase = scriptureParaphrase
        self.prayer = prayer
        self.todayAim = todayAim
        self.smallStepQuestion = smallStepQuestion
        self.suggestedSteps = suggestedSteps
        self.completionSuggestion = completionSuggestion
        self.updatedJourneyArc = updatedJourneyArc
        self.qualityVersion = qualityVersion
        self.generatedAt = generatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dailyTitle = try container.decodeIfPresent(String.self, forKey: .dailyTitle) ?? DailyJourneyPackageValidation.defaultDailyTitle
        reflectionThought = try container.decodeIfPresent(String.self, forKey: .reflectionThought) ?? ""
        scriptureReference = try container.decodeIfPresent(String.self, forKey: .scriptureReference) ?? ""
        scriptureParaphrase = try container.decodeIfPresent(String.self, forKey: .scriptureParaphrase) ?? ""
        prayer = try container.decodeIfPresent(String.self, forKey: .prayer) ?? ""
        todayAim = try container.decodeIfPresent(String.self, forKey: .todayAim) ?? DailyJourneyPackageValidation.defaultTodayAim
        smallStepQuestion = try container.decodeIfPresent(String.self, forKey: .smallStepQuestion) ?? ""
        suggestedSteps = try container.decodeIfPresent([String].self, forKey: .suggestedSteps) ?? []
        completionSuggestion = try container.decodeIfPresent(CompletionSuggestion.self, forKey: .completionSuggestion)
            ?? CompletionSuggestion(shouldPrompt: false, reason: "", confidence: 0)
        updatedJourneyArc = try container.decodeIfPresent(JourneyArcPayload.self, forKey: .updatedJourneyArc)
        qualityVersion = try container.decodeIfPresent(Int.self, forKey: .qualityVersion) ?? 0

        if let unix = try container.decodeIfPresent(Double.self, forKey: .generatedAt) {
            generatedAt = Date(timeIntervalSince1970: unix)
        } else if let isoString = try container.decodeIfPresent(String.self, forKey: .generatedAt) {
            let iso = ISO8601DateFormatter()
            generatedAt = iso.date(from: isoString) ?? .now
        } else {
            generatedAt = .now
        }
    }
}

enum DailyJourneyPackageValidation {
    private enum SupportedLanguage {
        case english
        case spanish
        case portugueseBrazil
        case german
        case japanese
        case korean
    }

    private static func currentLanguage() -> SupportedLanguage {
        switch AppLanguage.aiLanguageCode() {
        case "es":
            return .spanish
        case "pt":
            return .portugueseBrazil
        case "de":
            return .german
        case "ja":
            return .japanese
        case "ko":
            return .korean
        default:
            return .english
        }
    }

    static var defaultDailyTitle: String {
        switch currentLanguage() {
        case .english:
            return "Today’s Faithful Step"
        case .spanish:
            return "El paso de hoy"
        case .portugueseBrazil:
            return "O passo de hoje"
        case .german:
            return "Der heutige Schritt"
        case .japanese:
            return "今日の一歩"
        case .korean:
            return "오늘의 걸음"
        }
    }

    static var defaultTodayAim: String {
        switch currentLanguage() {
        case .english:
            return "take one faithful step"
        case .spanish:
            return "dar un paso fiel"
        case .portugueseBrazil:
            return "dar um passo fiel"
        case .german:
            return "einen treuen Schritt gehen"
        case .japanese:
            return "忠実な一歩を踏み出す"
        case .korean:
            return "신실한 한 걸음을 내딛기"
        }
    }

    static var defaultSmallStepQuestion: String {
        switch currentLanguage() {
        case .english:
            return "What small step could you take today?"
        case .spanish:
            return "¿Qué paso pequeño podrías dar hoy?"
        case .portugueseBrazil:
            return "Qual pequeno passo você pode dar hoje?"
        case .german:
            return "Welchen kleinen Schritt kannst du heute gehen?"
        case .japanese:
            return "今日、どんな小さな一歩を踏み出せますか？"
        case .korean:
            return "오늘 어떤 작은 걸음을 내딛을 수 있을까요?"
        }
    }

    static var defaultFirstPersonPrayer: String {
        switch currentLanguage() {
        case .english:
            return "Lord, I place this journey in Your hands today. Give me wisdom for one concrete step. Help me follow through with steady faith. Keep my heart close to You as I act, amen."
        case .spanish:
            return "Señor, pongo este camino en Tus manos hoy. Dame sabiduría para un paso concreto. Ayúdame a cumplirlo con fe firme. Mantén mi corazón cerca de Ti mientras actúo, amén."
        case .portugueseBrazil:
            return "Senhor, coloco esta jornada em Tuas mãos hoje. Dá-me sabedoria para um passo concreto. Ajuda-me a cumprir com fé firme. Mantém meu coração perto de Ti enquanto ajo, amém."
        case .german:
            return "Herr, ich lege diese Journey heute in Deine Hände. Gib mir Weisheit für einen konkreten Schritt. Hilf mir, ihn mit festem Glauben zu gehen. Halte mein Herz nah bei Dir, während ich handle, amen."
        case .japanese:
            return "主よ、今日この歩みをあなたの御手にゆだねます。具体的な一歩のために知恵を与えてください。揺るがない信仰で実行できるよう助けてください。行動する時も、私の心をあなたの近くに保ってください、アーメン。"
        case .korean:
            return "주님, 오늘 이 여정을 주님의 손에 올려드립니다. 구체적인 한 걸음을 위한 지혜를 주세요. 흔들리지 않는 믿음으로 실천하게 도와주세요. 제가 행동할 때에도 제 마음을 주님 가까이에 붙들어 주세요, 아멘."
        }
    }

    static var defaultReflectionThought: String {
        switch currentLanguage() {
        case .english:
            return "Faithful growth usually begins with one concrete response. The journey does not need a dramatic leap today. A small action can make prayer visible in ordinary life. Returning tomorrow gives that action room to become a pattern."
        case .spanish:
            return "El crecimiento fiel suele comenzar con una respuesta concreta. Hoy no hace falta dar un salto enorme. Una acción pequeña puede hacer visible la oración en la vida diaria. Volver mañana permite que esa acción empiece a formar un patrón."
        case .portugueseBrazil:
            return "O crescimento fiel geralmente começa com uma resposta concreta. Hoje não é preciso dar um grande salto. Uma pequena ação pode tornar a oração visível na vida comum. Voltar amanhã dá espaço para essa ação formar um padrão."
        case .german:
            return "Treues Wachstum beginnt oft mit einer konkreten Antwort. Heute braucht es keinen großen Sprung. Eine kleine Handlung kann Gebet im Alltag sichtbar machen. Morgen zurückzukehren gibt diesem Schritt Raum, ein Muster zu werden."
        case .japanese:
            return "忠実な成長は、たいてい一つの具体的な応答から始まります。今日、大きな飛躍をする必要はありません。小さな行動が、日常の中で祈りを見えるものにします。明日また戻ることで、その一歩が続く形になっていきます。"
        case .korean:
            return "신실한 성장은 보통 구체적인 응답 하나에서 시작됩니다. 오늘 큰 도약을 할 필요는 없습니다. 작은 행동 하나가 일상 속에서 기도를 보이게 합니다. 내일 다시 돌아오면 그 행동이 지속되는 흐름이 될 수 있습니다."
        }
    }
    private static let danglingEndings: Set<String> = [
        "a", "an", "and", "at", "because", "for", "from", "in", "into", "of", "on", "or",
        "that", "the", "to", "toward", "towards", "with"
    ]
    private static let firstPersonRegexEnglish = try? NSRegularExpression(
        pattern: #"\b(i|i'm|i've|i'd|i'll|me|my|mine|myself|we|we're|we've|we'd|we'll|us|our|ours|ourselves)\b"#,
        options: [.caseInsensitive]
    )
    private static let firstPersonRegexSpanish = try? NSRegularExpression(
        pattern: #"\b(yo|mi|m[ií]o|m[ií]a|m[ií]os|m[ií]as|m[ií]|me|conmigo|nosotros|nosotras|nuestro|nuestra|nuestros|nuestras|nos)\b"#,
        options: [.caseInsensitive]
    )
    private static let firstPersonRegexPortuguese = try? NSRegularExpression(
        pattern: #"\b(eu|meu|minha|meus|minhas|mim|comigo|n[oó]s|nosso|nossa|nossos|nossas|nos)\b"#,
        options: [.caseInsensitive]
    )
    private static let firstPersonRegexGerman = try? NSRegularExpression(
        pattern: #"\b(ich|mich|mir|mein|meine|meinen|meinem|meiner|meines|wir|uns|unser|unsere|unseren|unserem|unserer)\b"#,
        options: [.caseInsensitive]
    )
    private static let firstPersonRegexJapanese = try? NSRegularExpression(
        pattern: #"(私|わたし|僕|ぼく|俺|おれ|私たち|わたしたち|僕たち|ぼくたち|わたくし)"#,
        options: [.caseInsensitive]
    )
    private static let firstPersonRegexKorean = try? NSRegularExpression(
        pattern: #"(저|제|저는|제가|저를|저의|나|내|나는|내가|우리는|우리가|우리의)"#,
        options: [.caseInsensitive]
    )
    private static let disallowedThirdPersonPhrasesEnglish = [
        "the user",
        "this user",
        "for the user",
        "their journey",
        "his journey",
        "her journey"
    ]
    private static let disallowedThirdPersonPhrasesSpanish = [
        "el usuario",
        "la usuaria",
        "este usuario",
        "esta usuaria",
        "su jornada",
        "su camino"
    ]
    private static let disallowedThirdPersonPhrasesPortuguese = [
        "o usuário",
        "a usuária",
        "este usuário",
        "esta usuária",
        "a jornada do usuário",
        "a caminhada do usuário"
    ]
    private static let disallowedThirdPersonPhrasesGerman = [
        "der nutzer",
        "die nutzerin",
        "dieser nutzer",
        "diese nutzerin",
        "seine journey",
        "ihre journey"
    ]
    private static let disallowedThirdPersonPhrasesJapanese = [
        "ユーザー",
        "利用者",
        "このユーザー",
        "その人の旅",
        "彼らの旅路"
    ]
    private static let disallowedThirdPersonPhrasesKorean = [
        "사용자",
        "유저",
        "그 사람의 여정",
        "그녀의 여정",
        "그들의 여정"
    ]
    private static let suspiciousTailLeadWords: Set<String> = [
        "a", "an", "my", "our", "the", "to", "you", "your"
    ]
    private static let allowedShortTerminalWords: Set<String> = [
        "act", "all", "ask", "can", "day", "end", "far", "god", "joy", "let",
        "new", "now", "old", "one", "pray", "rest", "see", "set", "sin", "try",
        "use", "way", "yes", "yet"
    ]

    static func validated(
        _ package: DailyJourneyPackage,
        followThroughStatus: FollowThroughStatus? = nil
    ) -> DailyJourneyPackage {
        let language = currentLanguage()
        let normalizedReference = ScriptureReferenceValidator.isApproved(package.scriptureReference)
            ? package.scriptureReference
            : "Philippians 4:6-7"

        let normalizedParaphrase = ScriptureReferenceValidator.enforceParaphraseFidelity(
            reference: normalizedReference,
            paraphrase: package.scriptureParaphrase
        )

        let normalizedQuestion: String
        if package.smallStepQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalizedQuestion = defaultSmallStepQuestion
        } else {
            normalizedQuestion = package.smallStepQuestion
        }

        let normalizedSuggestedSteps = normalizedChipSteps(package.suggestedSteps)
        let fallbackChips = contextualFallbackChips(
            reflectionThought: package.reflectionThought,
            smallStepQuestion: normalizedQuestion,
            followThroughStatus: followThroughStatus,
            language: language
        )
        let mergedSuggestedSteps = mergedChips(primary: normalizedSuggestedSteps, fallback: fallbackChips)

        let normalizedConfidence = min(1.0, max(0.0, package.completionSuggestion.confidence))
        let normalizedCompletionSuggestion = CompletionSuggestion(
            shouldPrompt: package.completionSuggestion.shouldPrompt,
            reason: package.completionSuggestion.reason.trimmingCharacters(in: .whitespacesAndNewlines),
            confidence: normalizedConfidence
        )

        let normalizedTodayAim = package.todayAim.trimmingCharacters(in: .whitespacesAndNewlines)

        return DailyJourneyPackage(
            dailyTitle: package.dailyTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? defaultDailyTitle
                : package.dailyTitle,
            reflectionThought: normalizedReflectionThought(package.reflectionThought, language: language),
            scriptureReference: normalizedReference,
            scriptureParaphrase: normalizedParaphrase,
            prayer: normalizedFirstPersonPrayer(package.prayer, language: language),
            todayAim: normalizedTodayAim.isEmpty
                ? defaultTodayAim
                : normalizedTodayAim,
            smallStepQuestion: normalizedQuestion,
            suggestedSteps: mergedSuggestedSteps,
            completionSuggestion: normalizedCompletionSuggestion,
            updatedJourneyArc: package.updatedJourneyArc,
            qualityVersion: package.qualityVersion,
            generatedAt: package.generatedAt
        )
    }

    private static func normalizedChipSteps(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var chips: [String] = []

        for value in values {
            let compact = value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

            guard !compact.isEmpty else { continue }

            let words = compact.split(separator: " ")
            guard (2...7).contains(words.count) else { continue }

            let first = words.first?.lowercased() ?? ""
            let last = words.last?.lowercased() ?? ""
            guard !["and", "or", "to", "for", "with", "because", "if", "when"].contains(first) else { continue }
            guard !danglingEndings.contains(last) else { continue }

            let key = compact.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            chips.append(compact)

            if chips.count == 4 {
                break
            }
        }

        return chips
    }

    private static func normalizedFirstPersonPrayer(_ value: String, language: SupportedLanguage) -> String {
        let trimmed = normalizedProseEnding(value.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !trimmed.isEmpty else { return defaultFirstPersonPrayer }

        let normalized = trimmed
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")

        let disallowed: [String]
        switch language {
        case .english:
            disallowed = disallowedThirdPersonPhrasesEnglish
        case .spanish:
            disallowed = disallowedThirdPersonPhrasesSpanish
        case .portugueseBrazil:
            disallowed = disallowedThirdPersonPhrasesPortuguese
        case .german:
            disallowed = disallowedThirdPersonPhrasesGerman
        case .japanese:
            disallowed = disallowedThirdPersonPhrasesJapanese
        case .korean:
            disallowed = disallowedThirdPersonPhrasesKorean
        }
        let mentionsThirdPersonTemplate = disallowed.contains { normalized.contains($0) }
        guard !mentionsThirdPersonTemplate else { return defaultFirstPersonPrayer }

        let firstPersonRegex: NSRegularExpression?
        switch language {
        case .english:
            firstPersonRegex = firstPersonRegexEnglish
        case .spanish:
            firstPersonRegex = firstPersonRegexSpanish
        case .portugueseBrazil:
            firstPersonRegex = firstPersonRegexPortuguese
        case .german:
            firstPersonRegex = firstPersonRegexGerman
        case .japanese:
            firstPersonRegex = firstPersonRegexJapanese
        case .korean:
            firstPersonRegex = firstPersonRegexKorean
        }
        guard let firstPersonRegex else { return defaultFirstPersonPrayer }
        let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        let hasFirstPerson = firstPersonRegex.firstMatch(in: normalized, options: [], range: range) != nil
        return hasFirstPerson ? trimmed : defaultFirstPersonPrayer
    }

    private static func normalizedProseEnding(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let last = trimmed.last, ".!?".contains(last) {
            return repairedTrailingFragment(in: trimmed)
        }

        if let punctuationIndex = trimmed.lastIndex(where: { ".!?".contains($0) }) {
            let offset = trimmed.distance(from: trimmed.startIndex, to: punctuationIndex)
            if offset >= Int(Double(trimmed.count) * 0.45) {
                let candidate = String(trimmed[...punctuationIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                return repairedTrailingFragment(in: candidate)
            }
        }

        if let wordBoundary = trimmed.lastIndex(of: " ") {
            let offset = trimmed.distance(from: trimmed.startIndex, to: wordBoundary)
            if offset >= Int(Double(trimmed.count) * 0.7) {
                let candidate = String(trimmed[..<wordBoundary]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !candidate.isEmpty {
                    return repairedTrailingFragment(in: "\(candidate).")
                }
            }
        }

        return repairedTrailingFragment(in: trimmed)
    }

    private static func normalizedReflectionThought(_ value: String, language: SupportedLanguage) -> String {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard !trimmed.isEmpty else { return defaultReflectionThought }

        var topic = trimmed
            .replacingOccurrences(of: "?", with: " ")
            .replacingOccurrences(of: #"^take a moment to reflect on\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"^reflect on\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\bmy\b"#, with: "your", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\bmine\b"#, with: "yours", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\bme\b"#, with: "you", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\bi\b"#, with: "you", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\bour\b"#, with: "your", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\bours\b"#, with: "yours", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\bus\b"#, with: "you", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\bwe\b"#, with: "you", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\bwe're\b"#, with: "you're", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if language == .portugueseBrazil {
            topic = topic
                .replacingOccurrences(of: #"\bmeu\b"#, with: "seu", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: #"\bminha\b"#, with: "sua", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: #"\bmeus\b"#, with: "seus", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: #"\bminhas\b"#, with: "suas", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: #"\beu\b"#, with: "você", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: #"\bn[oó]s\b"#, with: "vocês", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: #"\bnosso\b"#, with: "seu", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: #"\bnossa\b"#, with: "sua", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: #"\bnossos\b"#, with: "seus", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: #"\bnossas\b"#, with: "suas", options: [.regularExpression, .caseInsensitive])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else if language == .german {
            topic = topic
                .replacingOccurrences(of: #"\bmein\b"#, with: "dein", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: #"\bmeine\b"#, with: "deine", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: #"\bmeinen\b"#, with: "deinen", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: #"\bmeinem\b"#, with: "deinem", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: #"\bmeiner\b"#, with: "deiner", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: #"\bich\b"#, with: "du", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: #"\bwir\b"#, with: "ihr", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: #"\bunser\b"#, with: "euer", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: #"\bunsere\b"#, with: "eure", options: [.regularExpression, .caseInsensitive])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else if language == .japanese {
            topic = topic
                .replacingOccurrences(of: "私の", with: "あなたの")
                .replacingOccurrences(of: "わたしの", with: "あなたの")
                .replacingOccurrences(of: "僕の", with: "あなたの")
                .replacingOccurrences(of: "俺の", with: "あなたの")
                .replacingOccurrences(of: "私たちの", with: "あなたの")
                .replacingOccurrences(of: "わたしたちの", with: "あなたの")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else if language == .korean {
            topic = topic
                .replacingOccurrences(of: "내 ", with: "당신의 ")
                .replacingOccurrences(of: "나의 ", with: "당신의 ")
                .replacingOccurrences(of: "우리는 ", with: "당신은 ")
                .replacingOccurrences(of: "우리의 ", with: "당신의 ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        topic = topic
            .replacingOccurrences(
                of: language == .spanish
                    ? #"^(c[oó]mo|qu[eé]|por qu[eé]|cu[aá]ndo|d[oó]nde|qui[eé]n|puedo|puedes|debo|deber[ií]a|es|son|est[aá]|est[aá]n|hay)\s+"#
                    : language == .portugueseBrazil
                        ? #"^(como|o que|que|por que|quando|onde|quem|posso|pode|devo|deveria|[ée]|s[aã]o|est[aá]|est[aã]o|h[aá])\s+"#
                        : language == .german
                            ? #"^(wie|was|warum|wann|wo|wer|kann|könnte|sollte|würde|ist|sind|bin|habe|hast|hat)\s+"#
                        : language == .japanese
                            ? #"^(どう|何|なぜ|いつ|どこ|誰|どのように)\s*"#
                        : language == .korean
                            ? #"^(어떻게|무엇|왜|언제|어디|누가|어떤)\s*"#
                        : #"^(how|what|why|when|where|who)\s+(do|does|did|can|could|should|would|is|are|am|will|have|has|had)\s+"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: language == .spanish
                    ? #"^(puedo|puedes|debo|deber[ií]a|es|son|est[aá]|est[aá]n|hay)\s+"#
                    : language == .portugueseBrazil
                        ? #"^(posso|pode|devo|deveria|[ée]|s[aã]o|est[aá]|est[aã]o|h[aá])\s+"#
                        : language == .german
                            ? #"^(kann|könnte|sollte|würde|ist|sind|bin|habe|hast|hat)\s+"#
                        : language == .japanese
                            ? #"^(できますか|すべき|でしょうか|ですか)\s*"#
                        : language == .korean
                            ? #"^(할\s*수\s*있나요|해야\s*하나요|인가요|있나요)\s*"#
                        : #"^(do|does|did|can|could|should|would|is|are|am|will|have|has|had)\s+"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .trimmingCharacters(in: CharacterSet(charactersIn: " .!?"))

        guard !topic.isEmpty else { return defaultReflectionThought }

        if topic.lowercased().hasPrefix("reflect on ") {
            topic = String(topic.dropFirst("reflect on ".count))
                .trimmingCharacters(in: CharacterSet(charactersIn: " ."))
        }

        if topic.isEmpty {
            return defaultReflectionThought
        }

        let sentence = topic.hasSuffix(".") || topic.hasSuffix("!") ? topic : "\(topic)."
        return normalizedProseEnding(sentence)
    }

    private static func repairedTrailingFragment(in value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let punctuation = CharacterSet(charactersIn: ".!?")
        let trailingToTrim = CharacterSet(charactersIn: ".!?\"'”’)]} ")
        let core = trimmed.trimmingCharacters(in: trailingToTrim)
        let words = core.split(separator: " ")

        guard words.count >= 4,
              let rawLast = words.last,
              let rawPrevious = words.dropLast().last else {
            return trimmed
        }

        let last = rawLast.lowercased()
        let previous = rawPrevious.lowercased()
        let lettersOnly = last.filter(\.isLetter)
        let letterCount = lettersOnly.count

        let shouldDropLast =
            danglingEndings.contains(last) ||
            letterCount <= 1 ||
            (
                suspiciousTailLeadWords.contains(previous) &&
                letterCount <= 3 &&
                !allowedShortTerminalWords.contains(last)
            )

        guard shouldDropLast else {
            return trimmed
        }

        let repairedCore = words.dropLast().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !repairedCore.isEmpty else { return trimmed }

        if let lastCharacter = trimmed.last,
           let scalar = lastCharacter.unicodeScalars.first,
           punctuation.contains(scalar) {
            return "\(repairedCore)."
        }

        return "\(repairedCore)."
    }

    private static func contextualFallbackChips(
        reflectionThought: String,
        smallStepQuestion: String,
        followThroughStatus: FollowThroughStatus?,
        language: SupportedLanguage
    ) -> [String] {
        let signal = "\(reflectionThought) \(smallStepQuestion)".lowercased()
        var chips: [String]
        if followThroughStatus == .partial || followThroughStatus == .no {
            switch language {
            case .english:
                chips = ["Take one tiny step", "Do a two minute task", "Choose one easier action"]
            case .spanish:
                chips = ["Da un paso de dos minutos", "Elige una acción más fácil", "Ora y empieza pequeño"]
            case .portugueseBrazil:
                chips = ["Dê um passo de dois minutos", "Escolha uma ação mais fácil", "Ore e comece pequeno"]
            case .german:
                chips = ["Mach einen Zwei-Minuten-Schritt", "Wähle eine leichtere Aktion", "Bete und starte klein"]
            case .japanese:
                chips = ["2分でできる一歩を選びましょう", "もっと簡単な行動を一つ選びましょう", "祈ってから小さく始めましょう"]
            case .korean:
                chips = ["아주 작은 한 걸음을 하세요", "2분짜리 행동 하나를 하세요", "더 쉬운 행동 하나를 고르세요"]
            }
        } else {
            switch language {
            case .english:
                chips = ["Pray over one next step", "Take one faithful action", "Finish one delayed task"]
            case .spanish:
                chips = ["Ora por un próximo paso", "Da una acción fiel", "Termina una tarea pendiente"]
            case .portugueseBrazil:
                chips = ["Ore por um próximo passo", "Dê uma ação fiel", "Conclua uma tarefa pendente"]
            case .german:
                chips = ["Bete über deinen nächsten Schritt", "Tu eine treue Handlung", "Schließe eine offene Aufgabe ab"]
            case .japanese:
                chips = ["次の一歩を祈りましょう", "忠実な行動を一つ取りましょう", "先延ばしの課題を一つ終えましょう"]
            case .korean:
                chips = ["다음 한 걸음을 두고 기도하세요", "신실한 행동 하나를 하세요", "미뤄 둔 일 하나를 끝내세요"]
            }
        }

        if signal.contains("worry") || signal.contains("anx") || signal.contains("peace") || signal.contains("fear")
            || signal.contains("preocupa") || signal.contains("ansied") || signal.contains("paz") || signal.contains("medo")
            || signal.contains("不安") || signal.contains("心配") || signal.contains("平安") || signal.contains("恐れ")
            || signal.contains("불안") || signal.contains("걱정") || signal.contains("평안") || signal.contains("두려") {
            chips.insert(
                contentsOf: language == .spanish
                    ? ["Respira profundo cinco veces", "Ora por esta preocupación"]
                    : language == .portugueseBrazil
                        ? ["Respire fundo cinco vezes", "Ore sobre esta preocupação"]
                        : language == .german
                            ? ["Atme fünfmal ruhig durch", "Bete über diese Sorge"]
                        : language == .japanese
                            ? ["ゆっくり深呼吸を5回しましょう", "この不安を祈りに委ねましょう"]
                        : language == .korean
                            ? ["천천히 다섯 번 숨 쉬세요", "이 걱정을 두고 기도하세요"]
                        : ["Take five calm breaths", "Pray through this specific worry"],
                at: 0
            )
        }
        if signal.contains("husband") || signal.contains("wife") || signal.contains("spouse") || signal.contains("marriage") {
            chips.insert(
                contentsOf: language == .spanish
                    ? ["Escribe una nota amable", "Haz una pregunta cariñosa", "Ora por tu cónyuge"]
                    : language == .portugueseBrazil
                        ? ["Escreva uma nota bondosa", "Faça uma pergunta carinhosa", "Ore por seu cônjuge"]
                        : language == .german
                            ? ["Schreibe eine liebevolle Notiz", "Stelle eine fürsorgliche Frage", "Bete für deinen Ehepartner"]
                        : language == .japanese
                            ? ["優しい言葉を一つ書きましょう", "思いやりのある質問を一つしましょう", "配偶者のために祈りましょう"]
                        : language == .korean
                            ? ["다정한 메모 하나를 쓰세요", "배려 깊은 질문 하나를 하세요", "배우자를 위해 기도하세요"]
                            : ["Write a kind note", "Ask one caring question", "Do one helpful chore", "Pray for your wife"],
                at: 0
            )
        }
        if signal.contains("focus") || signal.contains("discipline") || signal.contains("habit") || signal.contains("consisten")
            || signal.contains("foco") || signal.contains("disciplina") || signal.contains("hábito") || signal.contains("const")
            || signal.contains("集中") || signal.contains("鍛錬") || signal.contains("習慣") || signal.contains("継続")
            || signal.contains("집중") || signal.contains("훈련") || signal.contains("습관") {
            chips.insert(
                contentsOf: language == .spanish
                    ? ["Haz un bloque de enfoque", "Quita una distracción clara"]
                    : language == .portugueseBrazil
                        ? ["Faça um bloco de foco", "Remova uma distração clara"]
                        : language == .german
                            ? ["Starte einen Fokus-Block", "Entferne eine klare Ablenkung"]
                        : language == .japanese
                            ? ["集中ブロックを一つ作りましょう", "はっきりした妨げを一つ取り除きましょう"]
                        : language == .korean
                            ? ["집중 시간 블록을 만드세요", "분명한 방해 요소 하나를 치우세요"]
                        : ["Start one focused work block", "Remove one clear distraction"],
                at: 0
            )
        }
        if signal.contains("relationship") || signal.contains("family") || signal.contains("friend") || signal.contains("community")
            || signal.contains("relacion") || signal.contains("famíl") || signal.contains("amig") || signal.contains("comunid")
            || signal.contains("関係") || signal.contains("家族") || signal.contains("友人") || signal.contains("共同体")
            || signal.contains("관계") || signal.contains("가족") || signal.contains("친구") || signal.contains("공동체") {
            chips.insert(
                contentsOf: language == .spanish
                    ? ["Envía un mensaje de ánimo", "Ora por una persona específica"]
                    : language == .portugueseBrazil
                        ? ["Envie uma mensagem de encorajamento", "Ore por uma pessoa específica"]
                        : language == .german
                            ? ["Sende eine ermutigende Nachricht", "Bete für eine konkrete Person"]
                        : language == .japanese
                            ? ["励ましのメッセージを一つ送りましょう", "一人のために具体的に祈りましょう"]
                        : language == .korean
                            ? ["격려 메시지 하나를 보내세요", "한 사람을 위해 구체적으로 기도하세요"]
                        : ["Send one encouragement text", "Pray for one specific person"],
                at: 0
            )
        }
        if signal.contains("work") || signal.contains("career") || signal.contains("money") || signal.contains("business")
            || signal.contains("trabalho") || signal.contains("carreira") || signal.contains("dinheiro") || signal.contains("negócio")
            || signal.contains("仕事") || signal.contains("キャリア") || signal.contains("お金") || signal.contains("事業")
            || signal.contains("일") || signal.contains("커리어") || signal.contains("돈") || signal.contains("사업") {
            chips.insert(
                contentsOf: language == .spanish
                    ? ["Completa una tarea importante", "Revisa una decisión clave hoy"]
                    : language == .portugueseBrazil
                        ? ["Conclua uma tarefa importante", "Revise uma decisão-chave hoje"]
                        : language == .german
                            ? ["Erledige eine wichtige Aufgabe", "Prüfe heute eine zentrale Entscheidung"]
                        : language == .japanese
                            ? ["重要なタスクを一つ完了しましょう", "大切な判断を今日見直しましょう"]
                        : language == .korean
                            ? ["중요한 일 하나를 마무리하세요", "핵심 결정을 오늘 다시 점검하세요"]
                        : ["Complete one important work task", "Review one key decision today"],
                at: 0
            )
        }

        return normalizedChipSteps(chips)
    }

    private static func mergedChips(primary: [String], fallback: [String]) -> [String] {
        var seen: Set<String> = []
        var merged: [String] = []

        for value in (primary + fallback) {
            let key = value.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            merged.append(value)
            if merged.count == 4 {
                break
            }
        }

        if merged.isEmpty {
            switch currentLanguage() {
            case .english:
                return [
                    "Pray over one next step",
                    "Take one faithful action",
                    "Finish one delayed task"
                ]
            case .spanish:
                return [
                    "Ora por un próximo paso",
                    "Da una acción fiel",
                    "Termina una tarea pendiente"
                ]
            case .portugueseBrazil:
                return [
                    "Ore por um próximo passo",
                    "Dê uma ação fiel",
                    "Conclua uma tarefa pendente"
                ]
            case .german:
                return [
                    "Bete über deinen nächsten Schritt",
                    "Tu eine treue Handlung",
                    "Schließe eine offene Aufgabe ab"
                ]
            case .japanese:
                return [
                    "次の一歩を祈りましょう",
                    "忠実な行動を一つ取りましょう",
                    "先延ばしの課題を一つ終えましょう"
                ]
            case .korean:
                return [
                    "다음 한 걸음을 두고 기도하세요",
                    "신실한 행동 하나를 하세요",
                    "미뤄 둔 일 하나를 끝내세요"
                ]
            }
        }

        return merged
    }
}

protocol DailyJourneyPackageGenerating {
    func generatePackage(
        profile: OnboardingProfile,
        journey: PrayerJourney,
        recentEntries: [PrayerEntry],
        memory: JourneyMemorySnapshot?
    ) async throws -> DailyJourneyPackage
}

struct TemplateDailyJourneyPackageGenerator: DailyJourneyPackageGenerating {
    func generatePackage(
        profile: OnboardingProfile,
        journey: PrayerJourney,
        recentEntries: [PrayerEntry],
        memory: JourneyMemorySnapshot?
    ) async throws -> DailyJourneyPackage {
        let languageCode = AppLanguage.aiLanguageCode()
        let isSpanish = languageCode == "es"
        let isPortuguese = languageCode == "pt"
        let isGerman = languageCode == "de"
        let isJapanese = languageCode == "ja"
        let isKorean = languageCode == "ko"
        let usedReferences = Set(
            recentEntries
                .map { $0.scriptureReference.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        let reference = ScriptureReferenceValidator.deterministicApprovedReference(
            seed: "\(journey.id.uuidString)-\(journey.cycleCount)-\(recentEntries.count)",
            excluding: usedReferences
        )
        let paraphrase = ScriptureReferenceValidator.fallbackParaphrase(for: reference)
            ?? (isSpanish
                ? "Presenta tus peticiones a Dios con confianza y da hoy un paso fiel."
                : isPortuguese
                    ? "Apresente seus pedidos a Deus com confiança e dê hoje um passo fiel."
                    : isGerman
                        ? "Bringe deine Anliegen im Vertrauen zu Gott und gehe heute einen treuen Schritt."
                    : isJapanese
                        ? "神に願いを信頼してゆだね、今日、忠実な一歩を踏み出しましょう。"
                    : isKorean
                        ? "믿음으로 하나님께 간구를 올려 드리고, 오늘 신실한 한 걸음을 내딛으세요."
                    : "Bring your requests to God with trust, and take one faithful step today.")

        return DailyJourneyPackage(
            dailyTitle: isSpanish
                ? "Un paso fiel hoy"
                : isPortuguese
                    ? "Um passo fiel hoje"
                    : isGerman
                        ? "Ein treuer Schritt heute"
                    : isJapanese
                        ? "今日の忠実な一歩"
                    : isKorean
                        ? "오늘의 신실한 한 걸음"
                    : "One Faithful Step Today",
            reflectionThought: isSpanish
                ? "Dios encuentra a su pueblo en pasos pequeños y concretos. La fidelidad no siempre se ve grande, pero puede formar una dirección real para el día. La Escritura llama a entregar las cargas a Dios y caminar con confianza. Este camino puede avanzar hoy con una respuesta sencilla y sincera."
                : isPortuguese
                    ? "Deus encontra seu povo em passos pequenos e concretos. A fidelidade nem sempre parece grande, mas pode formar uma direção real para o dia. A Escritura chama a entregar os pesos a Deus e caminhar com confiança. Esta jornada pode avançar hoje com uma resposta simples e sincera."
                    : isGerman
                        ? "Gott begegnet seinem Volk in kleinen und konkreten Schritten. Treue wirkt nicht immer groß, kann aber dem Tag eine klare Richtung geben. Die Schrift lädt dazu ein, Lasten Gott anzuvertrauen und mit Vertrauen weiterzugehen. Diese Journey kann heute durch eine einfache und aufrichtige Antwort weiterwachsen."
                    : isJapanese
                        ? "神は小さく具体的な歩みの中で、ご自分の民に出会われます。忠実さは大きく見えないこともありますが、その日の方向を形づくります。聖書は重荷を神にゆだね、信頼して歩むよう招いています。この歩みは、今日の誠実な一つの応答によって前に進みます。"
                    : isKorean
                        ? "하나님은 작고 구체적인 걸음 속에서 자기 백성을 만나십니다. 신실함은 늘 크게 보이지 않지만, 오늘의 방향을 분명하게 세울 수 있습니다. 성경은 짐을 하나님께 맡기고 신뢰로 걸으라고 초대합니다. 이 여정은 오늘의 단순하고 진실한 응답으로 앞으로 나아갈 수 있습니다."
                    : "God often meets His people in small, concrete steps. Faithfulness may not look dramatic, but it can give the day a clear direction. Scripture invites burdens to be brought to God with trust instead of carried alone. This journey can move forward today through one simple, sincere response.",
            scriptureReference: reference,
            scriptureParaphrase: paraphrase,
            prayer: isSpanish
                ? "Señor, te entrego este camino hoy. Ayúdame a confiar en ti con lo que realmente llevo. Dame claridad para dar un paso fiel y pequeño."
                : isPortuguese
                    ? "Senhor, entrego esta jornada a ti hoje. Ajuda-me a confiar em ti com o que realmente carrego. Dá-me clareza para dar um passo pequeno e fiel."
                    : isGerman
                        ? "Herr, ich lege diese Journey heute in deine Hände. Hilf mir, dir mit dem zu vertrauen, was ich wirklich trage. Gib mir Klarheit für einen kleinen, treuen Schritt."
                    : isJapanese
                        ? "主よ、今日この歩みをあなたにゆだねます。私が本当に抱えていることの中で、あなたを信頼できるよう助けてください。小さく忠実な一歩を知る明確さを与えてください。"
                    : isKorean
                        ? "주님, 오늘 이 여정을 주님께 맡깁니다. 제가 실제로 짊어진 것 안에서 주님을 신뢰하게 도와주세요. 작고 신실한 한 걸음을 알 수 있는 분명함을 주세요."
                    : "Lord, I place this journey in Your hands today. Help me trust You with what I am actually carrying. Give me clarity for one small, faithful step.",
            todayAim: DailyJourneyPackageValidation.defaultTodayAim,
            smallStepQuestion: isSpanish
                ? "¿Qué paso pequeño podrías dar hoy?"
                : isPortuguese
                    ? "Qual pequeno passo você pode dar hoje?"
                    : isGerman
                        ? "Welchen kleinen Schritt kannst du heute gehen?"
                    : isJapanese
                        ? "今日、どんな小さな一歩を踏み出せますか？"
                    : isKorean
                        ? "오늘 어떤 작은 걸음을 내딛을 수 있을까요?"
                    : "What small step could you take today?",
            suggestedSteps: [
                isSpanish
                    ? "Ora cinco minutos por esto."
                    : isPortuguese
                        ? "Ore cinco minutos por isso."
                        : isGerman
                            ? "Bete fünf Minuten dafür."
                        : isJapanese
                            ? "5分間これを祈る"
                        : isKorean
                            ? "5분 동안 기도하기"
                        : "Pray for five minutes.",
                isSpanish
                    ? "Da un paso pequeño."
                    : isPortuguese
                        ? "Dê um passo pequeno."
                        : isGerman
                            ? "Geh einen kleinen Schritt."
                        : isJapanese
                            ? "小さな一歩を選ぶ"
                        : isKorean
                            ? "작은 한 걸음 선택하기"
                        : "Take one small step.",
                isSpanish
                    ? "Pide oración a alguien."
                    : isPortuguese
                        ? "Peça oração a alguém."
                        : isGerman
                            ? "Bitte jemanden um Gebet."
                        : isJapanese
                            ? "祈りを頼む"
                        : isKorean
                            ? "기도 부탁하기"
                        : "Ask for prayer."
            ],
            completionSuggestion: CompletionSuggestion(
                shouldPrompt: false,
                reason: "",
                confidence: 0
            ),
            qualityVersion: DailyJourneyPackage.currentQualityVersion,
            generatedAt: .now
        )
    }
}
