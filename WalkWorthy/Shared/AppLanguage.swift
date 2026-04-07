import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case spanish = "es"
    case portugueseBrazil = "pt-BR"

    static let storageKey = "app.language"

    var id: String { rawValue }

    var displayName: String {
        displayName(localizedIn: AppLanguage.selected())
    }

    func displayName(localizedIn interfaceLanguage: AppLanguage) -> String {
        let languageOverride: AppLanguage = interfaceLanguage == .system ? .system : interfaceLanguage

        switch self {
        case .system:
            return L10n.string("settings.language.system", default: "System Default", languageOverride: languageOverride)
        case .english:
            return "English"
        case .spanish:
            return "Español"
        case .portugueseBrazil:
            return "Português (Brasil)"
        }
    }

    static func selected(defaults: UserDefaults = .standard) -> AppLanguage {
        let raw = defaults.string(forKey: storageKey) ?? AppLanguage.system.rawValue
        return AppLanguage(rawValue: raw) ?? .system
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
        return "en"
    }

    static func aiLocaleIdentifier(defaults: UserDefaults = .standard) -> String {
        currentLocale(defaults: defaults).identifier
    }
}
