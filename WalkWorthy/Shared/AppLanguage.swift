import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case spanish = "es"
    case portugueseBrazil = "pt-BR"
    case german = "de"
    case japanese = "ja"
    case korean = "ko"

    static let storageKey = "app.language"

    var id: String { rawValue }

    var localizationResourceCandidates: [String] {
        switch self {
        case .system:
            return []
        case .english:
            return ["en"]
        case .spanish:
            return ["es", "es-419", "es_MX"]
        case .portugueseBrazil:
            return ["pt-BR", "pt_BR", "pt"]
        case .german:
            return ["de", "de-DE", "de_DE"]
        case .japanese:
            return ["ja", "ja-JP", "ja_JP"]
        case .korean:
            return ["ko", "ko-KR", "ko_KR"]
        }
    }

    var displayName: String {
        displayName(localizedIn: AppLanguage.selected())
    }

    func displayName(localizedIn interfaceLanguage: AppLanguage) -> String {
        let languageOverride: AppLanguage = interfaceLanguage == .system ? .system : interfaceLanguage

        switch self {
        case .system:
            return L10n.string("settings.language.system", default: "System Default", languageOverride: languageOverride)
        case .english:
            return L10n.string("settings.language.english", default: "English", languageOverride: languageOverride)
        case .spanish:
            return L10n.string("settings.language.spanish", default: "Español", languageOverride: languageOverride)
        case .portugueseBrazil:
            return L10n.string(
                "settings.language.portuguese_brazil",
                default: "Português (Brasil)",
                languageOverride: languageOverride
            )
        case .german:
            return L10n.string(
                "settings.language.german",
                default: "Deutsch",
                languageOverride: languageOverride
            )
        case .japanese:
            return L10n.string(
                "settings.language.japanese",
                default: "日本語",
                languageOverride: languageOverride
            )
        case .korean:
            return L10n.string(
                "settings.language.korean",
                default: "한국어",
                languageOverride: languageOverride
            )
        }
    }

    static func selected(defaults: UserDefaults = .standard) -> AppLanguage {
        let raw = defaults.string(forKey: storageKey) ?? AppLanguage.system.rawValue
        return parseStoredLanguage(raw)
    }

    static func resolvedLocale(for selected: AppLanguage, defaults: UserDefaults = .standard) -> Locale {
        switch selected {
        case .system:
            // Keep full locale identifier for region-aware formatting.
            return Locale(identifier: Locale.autoupdatingCurrent.identifier)
        case .english:
            return Locale(identifier: "en")
        case .spanish:
            return Locale(identifier: "es")
        case .portugueseBrazil:
            return Locale(identifier: "pt-BR")
        case .german:
            return Locale(identifier: "de-DE")
        case .japanese:
            return Locale(identifier: "ja-JP")
        case .korean:
            return Locale(identifier: "ko-KR")
        }
    }

    static func currentLocale(defaults: UserDefaults = .standard) -> Locale {
        resolvedLocale(for: selected(defaults: defaults), defaults: defaults)
    }

    static func aiLanguageCode(defaults: UserDefaults = .standard) -> String {
        let localeIdentifier = currentLocale(defaults: defaults).identifier.lowercased()
        if localeIdentifier.hasPrefix("es") {
            return "es"
        }
        if localeIdentifier.hasPrefix("pt") {
            return "pt"
        }
        if localeIdentifier.hasPrefix("de") {
            return "de"
        }
        if localeIdentifier.hasPrefix("ja") {
            return "ja"
        }
        if localeIdentifier.hasPrefix("ko") {
            return "ko"
        }
        return "en"
    }

    static func remoteLocalizationLocaleCode(defaults: UserDefaults = .standard) -> String {
        let localeIdentifier = currentLocale(defaults: defaults).identifier.lowercased()
        if localeIdentifier.hasPrefix("es") {
            return "es"
        }
        if localeIdentifier.hasPrefix("pt") {
            return "pt-br"
        }
        if localeIdentifier.hasPrefix("de") {
            return "de"
        }
        if localeIdentifier.hasPrefix("ja") {
            return "ja"
        }
        if localeIdentifier.hasPrefix("ko") {
            return "ko"
        }
        return "en"
    }

    static func aiLocaleIdentifier(defaults: UserDefaults = .standard) -> String {
        currentLocale(defaults: defaults).identifier
    }

    static func parseStoredLanguage(_ raw: String) -> AppLanguage {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty || normalized == AppLanguage.system.rawValue {
            return .system
        }

        if normalized == "en" || normalized == "english" {
            return .english
        }

        if normalized == "es" || normalized.hasPrefix("es-") || normalized.hasPrefix("es_") || normalized == "spanish" {
            return .spanish
        }

        if normalized == "pt"
            || normalized == "pt-br"
            || normalized == "pt_br"
            || normalized == "portuguese"
            || normalized == "portuguese-brazil" {
            return .portugueseBrazil
        }

        if normalized == "de"
            || normalized.hasPrefix("de-")
            || normalized.hasPrefix("de_")
            || normalized == "german"
            || normalized == "deutsch" {
            return .german
        }

        if normalized == "ja"
            || normalized.hasPrefix("ja-")
            || normalized.hasPrefix("ja_")
            || normalized == "japanese"
            || normalized == "nihongo" {
            return .japanese
        }

        if normalized == "ko"
            || normalized.hasPrefix("ko-")
            || normalized.hasPrefix("ko_")
            || normalized == "korean"
            || normalized == "hangul" {
            return .korean
        }

        return .system
    }
}
