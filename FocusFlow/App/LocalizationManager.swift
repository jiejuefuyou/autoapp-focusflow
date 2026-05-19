import Foundation
import SwiftUI
import ObjectiveC.runtime

/// Subclass of `Bundle` that resolves `localizedString` against an in-app
/// language override. iOS resolves strings via `Bundle.main.localizedString`,
/// which honors `AppleLanguages` UserDefaults set at launch — but ignores the
/// SwiftUI `.environment(\.locale)` for resource lookup. That's why a picker
/// that only mutates the locale environment never actually changed any text.
///
/// We swap `Bundle.main` to an instance of this class on app launch so that
/// every `Text("key")`, `String(localized: "...")`, and `LocalizedStringKey`
/// resolves against the override's `.lproj` immediately, no restart required.
private final class OverrideBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        let override = LocalizationManager.shared.override
        if !override.isEmpty,
           let path = Bundle.main.path(forResource: override, ofType: "lproj"),
           let overrideBundle = Bundle(path: path) {
            return overrideBundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

/// Centralized language override for the in-app language picker.
@Observable
final class LocalizationManager {

    static let shared = LocalizationManager()

    static let supportedLanguages: [String] = [
        "en", "ja", "zh-Hans", "zh-Hant", "ko", "es", "fr", "de"
    ]

    private let storageKey = "appLanguageOverride"

    var override: String {
        didSet { persist() }
    }

    var currentLocale: Locale {
        if override.isEmpty {
            return .current
        }
        return Locale(identifier: override)
    }

    private init() {
        self.override = UserDefaults.standard.string(forKey: storageKey) ?? ""
        Self.installBundleOverride()
        applyAppleLanguages(override)
    }

    func setOverride(_ code: String) {
        let normalized = Self.supportedLanguages.contains(code) ? code : ""
        override = normalized
        applyAppleLanguages(normalized)
    }

    private func persist() {
        UserDefaults.standard.set(override, forKey: storageKey)
    }

    private static func installBundleOverride() {
        guard !(Bundle.main is OverrideBundle) else { return }
        object_setClass(Bundle.main, OverrideBundle.self)
    }

    private func applyAppleLanguages(_ code: String) {
        let defaults = UserDefaults.standard
        if code.isEmpty {
            defaults.removeObject(forKey: "AppleLanguages")
        } else {
            defaults.set([code], forKey: "AppleLanguages")
        }
    }

    static let displayNames: [String: String] = [
        "en":      "English",
        "ja":      "日本語",
        "ko":      "한국어",
        "zh-Hans": "简体中文",
        "zh-Hant": "繁體中文",
        "es":      "Español",
        "fr":      "Français",
        "de":      "Deutsch",
    ]

    static func displayName(for code: String) -> String {
        if code.isEmpty {
            return String(localized: "System default")
        }
        if let native = displayNames[code] {
            return native
        }
        let locale = Locale(identifier: code)
        return locale.localizedString(forIdentifier: code)
            ?? Locale.current.localizedString(forIdentifier: code)
            ?? code
    }
}
