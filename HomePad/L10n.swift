import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "Follow system".tr
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        }
    }
    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "system") ?? .system
    }
    var languageCode: String {
        if self != .system { return rawValue }
        return (Locale.preferredLanguages.first ?? "en").hasPrefix("zh") ? "zh-Hans" : "en"
    }
    var locale: Locale { Locale(identifier: languageCode) }
}

/// All translations stay in the native string catalog. Unknown accessory and
/// household names are preserved; language changes never modify HomeKit data.
enum L10n {
    static var locale: Locale { AppLanguage.current.locale }
    private static let bundles: [String: Bundle] = {
        var result: [String: Bundle] = [:]
        for code in ["en", "zh-Hans"] {
            if let path = Bundle.main.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) {
                result[code] = bundle
            }
        }
        return result
    }()
    static func string(_ key: String) -> String {
        let bundle = bundles[AppLanguage.current.languageCode] ?? Bundle.main
        return bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }
    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: locale, arguments: arguments)
    }
}

extension String {
    var tr: String { L10n.string(self) }
}
