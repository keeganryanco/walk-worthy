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
    let reflectionThought: String
    let scriptureReference: String
    let scriptureParaphrase: String
    let prayer: String
    let smallStepQuestion: String
    let suggestedSteps: [String]
    let completionSuggestion: CompletionSuggestion
    let generatedAt: Date

    init(
        reflectionThought: String,
        scriptureReference: String,
        scriptureParaphrase: String,
        prayer: String,
        smallStepQuestion: String,
        suggestedSteps: [String],
        completionSuggestion: CompletionSuggestion,
        generatedAt: Date
    ) {
        self.reflectionThought = reflectionThought
        self.scriptureReference = scriptureReference
        self.scriptureParaphrase = scriptureParaphrase
        self.prayer = prayer
        self.smallStepQuestion = smallStepQuestion
        self.suggestedSteps = suggestedSteps
        self.completionSuggestion = completionSuggestion
        self.generatedAt = generatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reflectionThought = try container.decodeIfPresent(String.self, forKey: .reflectionThought) ?? ""
        scriptureReference = try container.decodeIfPresent(String.self, forKey: .scriptureReference) ?? ""
        scriptureParaphrase = try container.decodeIfPresent(String.self, forKey: .scriptureParaphrase) ?? ""
        prayer = try container.decodeIfPresent(String.self, forKey: .prayer) ?? ""
        smallStepQuestion = try container.decodeIfPresent(String.self, forKey: .smallStepQuestion) ?? ""
        suggestedSteps = try container.decodeIfPresent([String].self, forKey: .suggestedSteps) ?? []
        completionSuggestion = try container.decodeIfPresent(CompletionSuggestion.self, forKey: .completionSuggestion)
            ?? CompletionSuggestion(shouldPrompt: false, reason: "", confidence: 0)

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
        case korean
    }

    private static func currentLanguage() -> SupportedLanguage {
        switch AppLanguage.aiLanguageCode() {
        case "es":
            return .spanish
        case "pt":
            return .portugueseBrazil
        case "ko":
            return .korean
        default:
            return .english
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
        case .korean:
            return "오늘 어떤 작은 걸음을 내딛을 수 있을까요?"
        }
    }

    static var defaultFirstPersonPrayer: String {
        switch currentLanguage() {
        case .english:
            return "Lord, I place this journey in Your hands today. Give me wisdom, courage, and steady faith for my next step. Amen."
        case .spanish:
            return "Señor, pongo este camino en Tus manos hoy. Dame sabiduría, valentía y fe firme para mi próximo paso. Amén."
        case .portugueseBrazil:
            return "Senhor, coloco esta jornada em Tuas mãos hoje. Dá-me sabedoria, coragem e fé firme para meu próximo passo. Amém."
        case .korean:
            return "주님, 오늘 이 여정을 주님의 손에 올려드립니다. 다음 걸음을 위한 지혜와 용기, 흔들리지 않는 믿음을 주세요. 아멘."
        }
    }

    static var defaultReflectionThought: String {
        switch currentLanguage() {
        case .english:
            return "Faithful action today can shape long-term growth."
        case .spanish:
            return "Una acción fiel hoy puede formar un crecimiento duradero."
        case .portugueseBrazil:
            return "Uma ação fiel hoje pode gerar crescimento duradouro."
        case .korean:
            return "오늘의 신실한 실천 하나가 오래 남는 성장을 만듭니다."
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

        return DailyJourneyPackage(
            reflectionThought: normalizedReflectionThought(package.reflectionThought, language: language),
            scriptureReference: normalizedReference,
            scriptureParaphrase: normalizedParaphrase,
            prayer: normalizedFirstPersonPrayer(package.prayer, language: language),
            smallStepQuestion: normalizedQuestion,
            suggestedSteps: mergedSuggestedSteps,
            completionSuggestion: normalizedCompletionSuggestion,
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
            case .korean:
                chips = ["다음 한 걸음을 두고 기도하세요", "신실한 행동 하나를 하세요", "미뤄 둔 일 하나를 끝내세요"]
            }
        }

        if signal.contains("worry") || signal.contains("anx") || signal.contains("peace") || signal.contains("fear")
            || signal.contains("preocupa") || signal.contains("ansied") || signal.contains("paz") || signal.contains("medo")
            || signal.contains("불안") || signal.contains("걱정") || signal.contains("평안") || signal.contains("두려") {
            chips.insert(
                contentsOf: language == .spanish
                    ? ["Respira profundo cinco veces", "Ora por esta preocupación"]
                    : language == .portugueseBrazil
                        ? ["Respire fundo cinco vezes", "Ore sobre esta preocupação"]
                        : language == .korean
                            ? ["천천히 다섯 번 숨 쉬세요", "이 걱정을 두고 기도하세요"]
                        : ["Take five calm breaths", "Pray through this specific worry"],
                at: 0
            )
        }
        if signal.contains("focus") || signal.contains("discipline") || signal.contains("habit") || signal.contains("consisten")
            || signal.contains("foco") || signal.contains("disciplina") || signal.contains("hábito") || signal.contains("const")
            || signal.contains("집중") || signal.contains("훈련") || signal.contains("습관") {
            chips.insert(
                contentsOf: language == .spanish
                    ? ["Haz un bloque de enfoque", "Quita una distracción clara"]
                    : language == .portugueseBrazil
                        ? ["Faça um bloco de foco", "Remova uma distração clara"]
                        : language == .korean
                            ? ["집중 시간 블록을 만드세요", "분명한 방해 요소 하나를 치우세요"]
                        : ["Start one focused work block", "Remove one clear distraction"],
                at: 0
            )
        }
        if signal.contains("relationship") || signal.contains("family") || signal.contains("friend") || signal.contains("community")
            || signal.contains("relacion") || signal.contains("famíl") || signal.contains("amig") || signal.contains("comunid")
            || signal.contains("관계") || signal.contains("가족") || signal.contains("친구") || signal.contains("공동체") {
            chips.insert(
                contentsOf: language == .spanish
                    ? ["Envía un mensaje de ánimo", "Ora por una persona específica"]
                    : language == .portugueseBrazil
                        ? ["Envie uma mensagem de encorajamento", "Ore por uma pessoa específica"]
                        : language == .korean
                            ? ["격려 메시지 하나를 보내세요", "한 사람을 위해 구체적으로 기도하세요"]
                        : ["Send one encouragement text", "Pray for one specific person"],
                at: 0
            )
        }
        if signal.contains("work") || signal.contains("career") || signal.contains("money") || signal.contains("business")
            || signal.contains("trabalho") || signal.contains("carreira") || signal.contains("dinheiro") || signal.contains("negócio")
            || signal.contains("일") || signal.contains("커리어") || signal.contains("돈") || signal.contains("사업") {
            chips.insert(
                contentsOf: language == .spanish
                    ? ["Completa una tarea importante", "Revisa una decisión clave hoy"]
                    : language == .portugueseBrazil
                        ? ["Conclua uma tarefa importante", "Revise uma decisão-chave hoje"]
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
                    : isKorean
                        ? "믿음으로 하나님께 간구를 올려 드리고, 오늘 신실한 한 걸음을 내딛으세요."
                    : "Bring your requests to God with trust, and take one faithful step today.")

        return DailyJourneyPackage(
            reflectionThought: isSpanish
                ? "No vas tarde. Una acción fiel hoy sí importa."
                : isPortuguese
                    ? "Você não está atrasado. Uma ação fiel hoje importa."
                    : isKorean
                        ? "늦지 않았습니다. 오늘의 신실한 실천 하나가 분명히 중요합니다."
                    : "You are not behind. Faithful action today matters.",
            scriptureReference: reference,
            scriptureParaphrase: paraphrase,
            prayer: isSpanish
                ? "Señor, ayúdame a mantenerme firme y sincero en este camino hoy."
                : isPortuguese
                    ? "Senhor, ajuda-me a permanecer firme e sincero nesta jornada hoje."
                    : isKorean
                        ? "주님, 오늘 이 여정에서 제가 흔들리지 않고 진실하게 걸어가도록 도와주세요."
                    : "Lord, help me stay steady and sincere in this journey today.",
            smallStepQuestion: isSpanish
                ? "¿Qué paso pequeño podrías dar hoy?"
                : isPortuguese
                    ? "Qual pequeno passo você pode dar hoje?"
                    : isKorean
                        ? "오늘 어떤 작은 걸음을 내딛을 수 있을까요?"
                    : "What small step could you take today?",
            suggestedSteps: [
                isSpanish
                    ? "Ora 5 minutos específicamente por este camino."
                    : isPortuguese
                        ? "Ore por 5 minutos especificamente por esta jornada."
                        : isKorean
                            ? "이 여정을 위해 5분 동안 구체적으로 기도하세요."
                        : "Take 5 minutes to pray specifically for this journey.",
                isSpanish
                    ? "Haz una tarea concreta que haga avanzar este camino."
                    : isPortuguese
                        ? "Faça uma tarefa concreta que avance esta jornada."
                        : isKorean
                            ? "이 여정을 앞으로 나아가게 할 구체적인 일 하나를 하세요."
                        : "Do one concrete task that moves this journey forward.",
                isSpanish
                    ? "Envía un mensaje a una persona de confianza pidiendo oración."
                    : isPortuguese
                        ? "Envie uma mensagem para alguém de confiança pedindo oração."
                        : isKorean
                            ? "신뢰하는 한 사람에게 기도를 부탁하는 메시지를 보내세요."
                        : "Text one trusted person and ask for prayer."
            ],
            completionSuggestion: CompletionSuggestion(
                shouldPrompt: false,
                reason: "",
                confidence: 0
            ),
            generatedAt: .now
        )
    }
}
