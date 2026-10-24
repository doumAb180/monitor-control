import XCTest
import MonitorCore
@testable import Monitor

final class LocalizationTests: XCTestCase {
    func testSystemLanguageResolutionAndFallback() {
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["pt-BR", "es-MX"]), .spanish)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["zh-Hant-TW"]), .chinese)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["ko_KR"]), .korean)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["it-IT"]), .english)
        XCTAssertEqual(AppLanguage.german.resolved(preferredLanguages: ["ja-JP"]), .german)
    }
    func testCatalogCoversAllLanguagesAndPreservesPlaceholders() throws {
        let pattern = try NSRegularExpression(pattern: #"\{\d+\}"#)
        func placeholders(_ string: String) -> [String] {
            pattern.matches(in: string, range: NSRange(string.startIndex..., in: string)).map {
                String(string[Range($0.range, in: string)!])
            }.sorted()
        }
        for (key, translations) in Localization.catalog {
            XCTAssertEqual(translations.count, 7, key)
            XCTAssertEqual(translations.first, key)
            for translation in translations {
                XCTAssertFalse(translation.isEmpty, key)
                XCTAssertEqual(placeholders(translation), placeholders(key), key)
            }
        }
    }
    func testLanguageAndModesPersistWithoutResettingOtherPreferences() {
        let suite = "MonitorLocalizationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: "volumeKeys")
        defaults.set(true, forKey: "brightnessKeys")
        defaults.set("saved-monitor", forKey: "selectedDisplay")
        let model = AppModel(defaults: defaults, connectHardware: false)
        XCTAssertEqual(model.language, .system)
        XCTAssertEqual(model.volumeMode, .fine)
        model.volumeMode = .standard
        model.brightnessMode = .fine
        for language in AppLanguage.allCases {
            model.language = language
            let loaded = AppModel(defaults: UserDefaults(suiteName: suite)!, connectHardware: false)
            XCTAssertEqual(loaded.language, language)
            XCTAssertEqual(loaded.volumeMode, .standard)
            XCTAssertEqual(loaded.brightnessMode, .fine)
            XCTAssertFalse(loaded.volumeKeys)
            XCTAssertTrue(loaded.brightnessKeys)
            XCTAssertEqual(loaded.selectedID, "saved-monitor")
        }
        defaults.set("unknown-language", forKey: "appLanguage.v1")
        XCTAssertEqual(AppModel(defaults: defaults, connectHardware: false).language, .system)
    }
    func testLegacyStepsMigrateAndExplicitModesTakePrecedence() {
        let suite = "MonitorMigrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(5, forKey: "volumeStep")
        defaults.set(1, forKey: "brightnessStep")
        let model = AppModel(defaults: defaults, connectHardware: false)
        XCTAssertEqual(model.volumeMode, .standard)
        XCTAssertEqual(model.brightnessMode, .fine)
        model.volumeMode = .fine
        XCTAssertEqual(AppModel(defaults: defaults, connectHardware: false).volumeMode, .fine)
    }
    func testVisibleFeedbackChangesLanguageAndArgumentsStayLiteral() {
        let model = AppModel(preview: true)
        model.language = .english
        XCTAssertEqual(model.message, "One step at a time. Just right.")
        model.language = .korean
        XCTAssertEqual(model.message, "한 단계씩, 원하는 만큼만.")
        let feedback = LocalizedText.key("{0} {1} · Applied", [.key("Volume"), .verbatim("21")])
        XCTAssertEqual(feedback.rendered(in: .korean), "볼륨 21 · 적용 완료")
        XCTAssertEqual(feedback.rendered(in: .japanese), "音量 21 · 適用済み")
        let literal = LocalizedText.key("{0} {1} · Applied", [.verbatim("{1}"), .verbatim("21")])
        XCTAssertEqual(literal.rendered(in: .english), "{1} 21 · Applied")
    }
}
