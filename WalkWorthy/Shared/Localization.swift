import Foundation

enum L10n {
    static func string(_ key: String, default defaultValue: String) -> String {
        let language = AppLanguage.selected()
        let table = "Localizable"

        if language == .system {
            return Bundle.main.localizedString(forKey: key, value: defaultValue, table: table)
        }

        if let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: defaultValue, table: table)
        }

        return Bundle.main.localizedString(forKey: key, value: defaultValue, table: table)
    }
}
