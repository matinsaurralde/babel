import XCTest
@testable import Babel

final class LocalePreferenceTests: XCTestCase {

    private let key = LocalePreference.userDefaultsKey

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: key)
        super.tearDown()
    }

    func testEmptyInstalledReturnsNil() {
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertNil(LocalePreference.resolve(installed: []))
    }

    func testExactBcp47MatchWins() {
        UserDefaults.standard.set("es-AR", forKey: key)
        let installed = [Locale(identifier: "es_ES"), Locale(identifier: "es_AR"), Locale(identifier: "en_US")]
        let resolved = LocalePreference.resolve(installed: installed)
        XCTAssertEqual(resolved?.identifier(.bcp47), "es-AR")
    }

    func testFallsBackToSameLanguageWhenExactNotInstalled() {
        UserDefaults.standard.set("es-AR", forKey: key)
        let installed = [Locale(identifier: "en_US"), Locale(identifier: "es_ES")]
        let resolved = LocalePreference.resolve(installed: installed)
        XCTAssertEqual(resolved?.language.languageCode?.identifier, "es")
    }

    func testFallsBackToEnglishWhenLanguageMissing() {
        UserDefaults.standard.set("ja-JP", forKey: key)
        let installed = [Locale(identifier: "fr_FR"), Locale(identifier: "en_GB"), Locale(identifier: "de_DE")]
        let resolved = LocalePreference.resolve(installed: installed)
        XCTAssertEqual(resolved?.language.languageCode?.identifier, "en")
    }

    func testFallsBackToFirstInstalledAsLastResort() {
        UserDefaults.standard.set("ja-JP", forKey: key)
        let installed = [Locale(identifier: "fr_FR"), Locale(identifier: "de_DE")]
        let resolved = LocalePreference.resolve(installed: installed)
        XCTAssertEqual(resolved?.identifier, "fr_FR")
    }

    func testEmptyPreferenceTreatsAsAuto() {
        UserDefaults.standard.set("", forKey: key)
        let installed = [Locale(identifier: "en_US")]
        XCTAssertNotNil(LocalePreference.resolve(installed: installed))
    }
}
