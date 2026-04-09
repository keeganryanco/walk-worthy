import Foundation

struct ScriptureReferenceValidator {
    static let approvedReferences: Set<String> = [
        "Galatians 6:9",
        "1 Corinthians 15:58",
        "Joshua 1:9",
        "2 Timothy 1:7",
        "Philippians 4:6-7",
        "Isaiah 26:3",
        "Colossians 3:23",
        "1 Corinthians 9:27",
        "Galatians 5:13",
        "Mark 10:45",
        "Romans 12:2",
        "Proverbs 3:5-6",
        "James 1:5",
        "Psalm 23:1-3",
        "Psalm 46:10",
        "Psalm 121:1-2",
        "Psalm 119:105",
        "Isaiah 40:31",
        "Lamentations 3:22-23",
        "Matthew 11:28",
        "Matthew 6:33",
        "Matthew 6:34",
        "Matthew 5:16",
        "Matthew 7:7",
        "John 15:5",
        "John 14:27",
        "John 16:33",
        "Romans 8:28",
        "Romans 12:12",
        "Romans 5:3-4",
        "Romans 15:13",
        "1 Corinthians 10:13",
        "2 Corinthians 5:7",
        "2 Corinthians 12:9",
        "Ephesians 2:10",
        "Ephesians 4:2",
        "Ephesians 4:32",
        "Philippians 1:6",
        "Philippians 4:8",
        "Colossians 3:12",
        "1 Thessalonians 5:16-18",
        "2 Thessalonians 3:13",
        "Hebrews 12:1",
        "Hebrews 11:1",
        "Hebrews 10:24",
        "James 1:2-4",
        "James 1:22",
        "James 4:8",
        "1 Peter 5:7",
        "1 Peter 4:10",
        "2 Peter 1:5-7",
        "1 John 4:18",
        "1 John 1:9",
        "Micah 6:8",
        "Proverbs 16:3",
        "Proverbs 27:17",
        "Ecclesiastes 4:9-10",
        "Psalm 37:4-5",
        "Psalm 34:8",
        "Psalm 27:14",
        "Deuteronomy 31:6",
        "Psalm 4:8",
        "Psalm 56:3-4",
        "Psalm 62:8",
        "Psalm 90:14",
        "Psalm 94:19",
        "Psalm 118:24",
        "Psalm 143:8",
        "Proverbs 4:23",
        "Proverbs 11:25",
        "Proverbs 18:10",
        "Isaiah 30:15",
        "Isaiah 30:18",
        "Isaiah 41:10",
        "Jeremiah 17:7-8",
        "Habakkuk 3:19",
        "Zephaniah 3:17",
        "Matthew 9:37-38",
        "Matthew 22:37-39",
        "Matthew 28:19-20",
        "Luke 1:37",
        "Luke 6:36",
        "Luke 16:10",
        "John 8:12",
        "John 10:10",
        "John 13:34-35",
        "John 14:1",
        "John 15:12",
        "Acts 20:35",
        "Romans 8:25",
        "Romans 12:10",
        "Romans 12:21",
        "1 Corinthians 13:4-7",
        "1 Corinthians 16:13-14",
        "2 Corinthians 4:16-18",
        "2 Corinthians 9:6-8",
        "Galatians 6:2",
        "Ephesians 3:20",
        "Philippians 2:3-4",
        "Philippians 2:13",
        "Philippians 3:13-14",
        "Philippians 4:13",
        "1 Thessalonians 5:11",
        "2 Thessalonians 1:3",
        "Hebrews 6:10",
        "Hebrews 6:15",
        "Hebrews 13:5-6",
        "James 5:7-8",
        "1 Peter 3:8",
        "1 Peter 4:8",
        "1 John 3:18"
    ]

    static func isApproved(_ reference: String) -> Bool {
        let trimmed = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if approvedReferences.contains(trimmed) {
            return true
        }

        // Canonical format fallback: "<Book> <Chapter>:<Verse>" or verse ranges.
        let pattern = #"^(?:[1-3]\s)?[A-Za-z]+(?:\s[A-Za-z]+)*\s\d{1,3}:\d{1,3}(?:-\d{1,3})?$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    static var approvedReferencesSorted: [String] {
        approvedReferences.sorted()
    }

    private static let paraphraseFallbacks: [String: [String: String]] = [
        "Galatians 6:9": [
            "en": "Do not grow weary in doing good, because in due time you will reap a harvest if you do not give up.",
            "es": "No te canses de hacer el bien, porque a su tiempo cosecharás si no te rindes.",
            "pt": "Não se canse de fazer o bem, pois no tempo certo você colherá se não desistir.",
            "ko": "선을 행하다가 지치지 마세요. 포기하지 않으면 때가 되어 반드시 열매를 거두게 됩니다."
        ],
        "1 Corinthians 15:58": [
            "en": "Stand firm, let nothing move you, and keep giving yourself fully to the Lord's work, knowing your labor in Him is not in vain.",
            "es": "Mantente firme, que nada te mueva, y sigue entregándote por completo a la obra del Señor, sabiendo que tu trabajo en Él no es en vano.",
            "pt": "Permaneça firme, não deixe nada abalar você e continue se dedicando por completo à obra do Senhor, sabendo que seu trabalho nEle não é em vão.",
            "ko": "굳게 서서 흔들리지 말고 주님의 일을 힘써 계속하세요. 주님 안에서의 수고는 헛되지 않습니다."
        ],
        "Joshua 1:9": [
            "en": "Be strong and courageous, do not be afraid, for the Lord your God is with you wherever you go.",
            "es": "Sé fuerte y valiente, no tengas miedo, porque el Señor tu Dios está contigo dondequiera que vayas.",
            "pt": "Seja forte e corajoso, não tenha medo, pois o Senhor seu Deus está com você por onde você for.",
            "ko": "강하고 담대하세요. 두려워하지 마세요. 어디로 가든지 주 하나님이 함께하십니다."
        ],
        "2 Timothy 1:7": [
            "en": "God gives you a spirit of power, love, and self-control, not fear.",
            "es": "Dios te da un espíritu de poder, amor y dominio propio, no de miedo.",
            "pt": "Deus lhe dá um espírito de poder, amor e domínio próprio, e não de medo.",
            "ko": "하나님은 두려움이 아니라 능력과 사랑과 절제의 영을 주십니다."
        ],
        "Philippians 4:6-7": [
            "en": "Bring every worry and request to God with thanksgiving, and His peace will guard your heart and mind in Christ.",
            "es": "Presenta a Dios cada preocupación y petición con gratitud, y su paz guardará tu corazón y tu mente en Cristo.",
            "pt": "Apresente a Deus cada preocupação e pedido com gratidão, e a paz dEle guardará seu coração e sua mente em Cristo.",
            "ko": "모든 염려와 간구를 감사함으로 하나님께 아뢰면, 그분의 평강이 그리스도 안에서 마음과 생각을 지켜 주십니다."
        ],
        "Isaiah 26:3": [
            "en": "God keeps in perfect peace the one whose mind is steadfast and trusting in Him.",
            "es": "Dios guarda en perfecta paz a quien mantiene su mente firme y confía en Él.",
            "pt": "Deus mantém em perfeita paz quem permanece firme e confia nEle.",
            "ko": "마음을 주님께 굳게 두고 의지하는 사람을 하나님이 온전한 평강으로 지켜 주십니다."
        ],
        "Colossians 3:23": [
            "en": "Work wholeheartedly, as for the Lord and not for people.",
            "es": "Trabaja de todo corazón, como para el Señor y no para las personas.",
            "pt": "Trabalhe de todo o coração, como para o Senhor e não para as pessoas.",
            "ko": "무슨 일을 하든 사람에게 하듯이 하지 말고 주님께 하듯 마음을 다해 하세요."
        ],
        "1 Corinthians 9:27": [
            "en": "Practice disciplined self-control so your life stays aligned with what you proclaim.",
            "es": "Practica un dominio propio disciplinado para que tu vida permanezca alineada con lo que proclamas.",
            "pt": "Pratique domínio próprio com disciplina para que sua vida permaneça alinhada ao que você proclama.",
            "ko": "절제와 훈련으로 자신을 다스려, 말로 고백한 믿음과 삶이 일치하도록 하세요."
        ],
        "Galatians 5:13": [
            "en": "Use your freedom to serve one another humbly in love.",
            "es": "Usa tu libertad para servir a los demás con humildad y amor.",
            "pt": "Use sua liberdade para servir uns aos outros com humildade e amor.",
            "ko": "주어진 자유를 사랑 안에서 서로를 겸손히 섬기는 데 사용하세요."
        ],
        "Mark 10:45": [
            "en": "The Son of Man came not to be served but to serve and to give His life for many.",
            "es": "El Hijo del Hombre no vino para ser servido, sino para servir y dar su vida por muchos.",
            "pt": "O Filho do Homem não veio para ser servido, mas para servir e dar sua vida por muitos.",
            "ko": "인자는 섬김을 받으려 온 것이 아니라 섬기고 많은 사람을 위해 자기 생명을 내어주려 오셨습니다."
        ]
    ]

    private static let paraphraseAnchors: [String: [String]] = [
        "Galatians 6:9": ["weary", "doing good", "harvest", "give up", "due time"],
        "1 Corinthians 15:58": ["stand firm", "lord's work", "labor", "not in vain", "steadfast"],
        "Joshua 1:9": ["strong", "courageous", "afraid", "with you", "wherever"],
        "2 Timothy 1:7": ["spirit", "power", "love", "self-control", "fear"],
        "Philippians 4:6-7": ["anxious", "prayer", "request", "thanksgiving", "peace"],
        "Isaiah 26:3": ["perfect peace", "mind", "steadfast", "trust", "trusts"],
        "Colossians 3:23": ["work", "heartily", "lord", "not for", "people"],
        "1 Corinthians 9:27": ["discipline", "self-control", "body", "disqualified", "after preaching"],
        "Galatians 5:13": ["freedom", "serve", "one another", "love", "humility"],
        "Mark 10:45": ["serve", "served", "son of man", "ransom", "many"]
    ]

    private static let offTargetSignals: [String: [String]] = [
        "Philippians 4:6-7": ["plans", "establish", "business", "provision", "career", "success"]
    ]

    static func sanitizedSnippet(_ text: String, maxLength: Int = 420) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= maxLength {
            return trimmed
        }

        let hard = String(trimmed.prefix(maxLength))
        let sentenceBoundary = max(
            hard.lastIndex(of: ".")?.utf16Offset(in: hard) ?? -1,
            hard.lastIndex(of: "!")?.utf16Offset(in: hard) ?? -1,
            hard.lastIndex(of: "?")?.utf16Offset(in: hard) ?? -1
        )
        if sentenceBoundary >= Int(Double(maxLength) * 0.55) {
            let index = hard.index(hard.startIndex, offsetBy: sentenceBoundary + 1)
            return String(hard[..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let wordBoundary = hard.lastIndex(of: " ") {
            let offset = wordBoundary.utf16Offset(in: hard)
            if offset >= Int(Double(maxLength) * 0.55) {
                return String(hard[..<wordBoundary]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Keep the full text when we cannot trim naturally to avoid mid-sentence clipping.
        return trimmed
    }

    static func enforceParaphraseFidelity(reference: String, paraphrase: String, languageCode: String = AppLanguage.aiLanguageCode()) -> String {
        let normalizedReference = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedParaphrase = sanitizedSnippet(paraphrase)
        let normalizedLanguageCode = normalizedLanguage(languageCode)
        let fallback = paraphraseFallback(for: normalizedReference, languageCode: normalizedLanguageCode)
        let anchors = paraphraseAnchors[normalizedReference]

        guard let fallback else {
            return normalizedParaphrase
        }

        // Anchor keywords are English-only; avoid forcing English fidelity checks on non-English output.
        guard normalizedLanguageCode == "en" else {
            return normalizedParaphrase.isEmpty ? fallback : normalizedParaphrase
        }

        guard let anchors else {
            return normalizedParaphrase.isEmpty
                ? (paraphraseFallback(for: "Philippians 4:6-7", languageCode: normalizedLanguageCode) ?? fallback)
                : normalizedParaphrase
        }

        guard !normalizedParaphrase.isEmpty else { return fallback }

        let lowered = normalizedParaphrase.lowercased()
        let anchorMatches = anchors.reduce(into: 0) { partial, anchor in
            if lowered.contains(anchor) {
                partial += 1
            }
        }
        let offTargetMatches = (offTargetSignals[normalizedReference] ?? []).reduce(into: 0) { partial, signal in
            if lowered.contains(signal) {
                partial += 1
            }
        }

        if anchorMatches < 2 || (anchorMatches == 0 && offTargetMatches >= 2) {
            return fallback
        }

        return normalizedParaphrase
    }

    static func fallbackParaphrase(for reference: String, languageCode: String = AppLanguage.aiLanguageCode()) -> String? {
        paraphraseFallback(
            for: reference.trimmingCharacters(in: .whitespacesAndNewlines),
            languageCode: normalizedLanguage(languageCode)
        )
    }

    static func deterministicApprovedReference(seed: String, excluding: Set<String> = []) -> String {
        let pool = approvedReferencesSorted.filter { !excluding.contains($0) }
        let candidates = pool.isEmpty ? approvedReferencesSorted : pool
        guard !candidates.isEmpty else {
            return "Philippians 4:6-7"
        }
        let index = abs(seedHash(seed)) % candidates.count
        return candidates[index]
    }

    private static func seedHash(_ value: String) -> Int {
        var hash = 0
        for scalar in value.unicodeScalars {
            hash = (hash << 5) &- hash &+ Int(scalar.value)
        }
        return hash
    }

    private static func normalizedLanguage(_ languageCode: String) -> String {
        let raw = languageCode.lowercased()
        if raw.hasPrefix("es") { return "es" }
        if raw.hasPrefix("pt") { return "pt" }
        if raw.hasPrefix("ko") { return "ko" }
        return "en"
    }

    private static func paraphraseFallback(for reference: String, languageCode: String) -> String? {
        guard let localized = paraphraseFallbacks[reference] else { return nil }
        return localized[languageCode] ?? localized["en"]
    }
}
