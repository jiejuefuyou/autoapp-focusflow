import XCTest
@testable import FocusFlow

/// Device-free CI gate for the in-app language switch.
///
/// The entire in-app language picker works through `OverrideBundle.localizedString`,
/// which resolves a language by calling
/// `Bundle.main.path(forResource: <lang>, ofType: "lproj")`.
/// If that returns `nil` — which happens when project.yml declares the `.lproj`
/// folders as explicit `resources:` paths (with `excludes:` removing them from
/// `sources`) instead of letting XcodeGen auto-detect them as localization
/// variant groups — the override silently falls back to the system language and
/// the picker appears to do nothing. That is the exact root cause of the
/// "language won't switch" reports (proven 2026-06-07: this test failed on the
/// explicit-resource config and passed on the auto-detect config).
///
/// These tests fail loudly in CI on the broken bundling config, so the fix can
/// never again be claimed "done" without proof.
final class LocalizationBundlingTests: XCTestCase {

    /// Every shipped language's `.lproj` must be resolvable from `Bundle.main`
    /// exactly the way `OverrideBundle` resolves it at runtime.
    func testEveryShippedLanguageLprojIsResolvableFromMainBundle() throws {
        for lang in LocalizationManager.supportedLanguages {
            let path = try XCTUnwrap(
                Bundle.main.path(forResource: lang, ofType: "lproj"),
                "\(lang).lproj is NOT resolvable from Bundle.main — the in-app language picker (OverrideBundle) cannot switch to \(lang). Fix: let XcodeGen auto-detect .lproj (remove explicit lproj excludes + resources in project.yml)."
            )
            let lprojBundle = try XCTUnwrap(Bundle(path: path), "\(lang).lproj did not load as a Bundle")
            let stringsPath = try XCTUnwrap(
                lprojBundle.path(forResource: "Localizable", ofType: "strings"),
                "\(lang).lproj has no Localizable.strings"
            )
            let dict = NSDictionary(contentsOfFile: stringsPath) as? [String: String]
            XCTAssertNotNil(dict, "\(lang) Localizable.strings is not a valid .strings file")
            XCTAssertFalse(dict?.isEmpty ?? true, "\(lang) Localizable.strings is empty")
        }
    }

    /// Proves a real switch is observable: at least one key resolves to a
    /// DIFFERENT value in `ja` vs the `en` base (not just that files exist).
    func testOverrideProducesDistinctTranslationVsBase() throws {
        let enPath = try XCTUnwrap(Bundle.main.path(forResource: "en", ofType: "lproj"))
        let jaPath = try XCTUnwrap(Bundle.main.path(forResource: "ja", ofType: "lproj"))
        let en = try XCTUnwrap(Bundle(path: enPath))
        let ja = try XCTUnwrap(Bundle(path: jaPath))
        let enStringsPath = try XCTUnwrap(en.path(forResource: "Localizable", ofType: "strings"))
        let enStrings = try XCTUnwrap(NSDictionary(contentsOfFile: enStringsPath) as? [String: String])

        let sentinel = "\u{1}__missing__"
        var differingKeys = 0
        for (key, enValue) in enStrings {
            let jaValue = ja.localizedString(forKey: key, value: sentinel, table: nil)
            if jaValue != sentinel && jaValue != enValue { differingKeys += 1 }
        }
        XCTAssertGreaterThan(
            differingKeys, 0,
            "No key resolved to a different value in ja vs en — switching to Japanese would be a visible no-op (ja.lproj not actually providing translations)."
        )
    }
}
