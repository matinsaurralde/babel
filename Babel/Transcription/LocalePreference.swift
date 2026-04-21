import Foundation
import Speech

/// Where Babel stores the user's dictation-language choice.
/// Empty string / missing = "Auto (match the system locale)".
enum LocalePreference {
    static let userDefaultsKey = "babel.dictationLocale"

    /// Resolves the user's preference against the set of SpeechTranscriber
    /// locales that are actually installed on this Mac. Falls back, in order,
    /// to: the system locale, the same language family, English, and finally
    /// whichever locale happens to be installed first.
    static func resolve(installed: [Locale]) -> Locale? {
        guard !installed.isEmpty else { return nil }

        let raw = UserDefaults.standard.string(forKey: userDefaultsKey) ?? ""
        let desired: Locale = raw.isEmpty ? Locale.current : Locale(identifier: raw)

        if let exact = installed.first(where: { $0.identifier(.bcp47) == desired.identifier(.bcp47) }) {
            return exact
        }
        if let lang = desired.language.languageCode?.identifier,
           let sameLanguage = installed.first(where: { $0.language.languageCode?.identifier == lang }) {
            return sameLanguage
        }
        if let english = installed.first(where: { $0.language.languageCode?.identifier == "en" }) {
            return english
        }
        return installed.first
    }

    /// Human-readable label for a locale, for use in Settings pickers.
    /// Uses the system locale so the user sees language names in their language.
    static func displayName(for locale: Locale) -> String {
        let system = Locale.current
        if let language = locale.language.languageCode?.identifier,
           let localized = system.localizedString(forLanguageCode: language) {
            if let region = locale.region?.identifier,
               let regionName = system.localizedString(forRegionCode: region) {
                return "\(localized.capitalized) (\(regionName))"
            }
            return localized.capitalized
        }
        return locale.identifier
    }
}
