//  CrossPromoSection.swift — PORTFOLIO CANONICAL (orchestrator/ios-core)
//
//  Single source of truth for all autoapp iOS apps. DO NOT edit per-app copies.
//  Edit orchestrator/ios-core/swift/CrossPromoSection.swift, then run:
//      python dashboard/sync_ios_core.py --apply
//  Drift is gated by dashboard/audit_portfolio.py (core-sync check).
//
//  Holds the full 8-app portfolio. When an app is added, update the `portfolio`
//  array HERE once and sync — every app's cross-promo list updates together.
//
import SwiftUI

/// A single app in the developer's portfolio, surfaced for cross-promotion.
///
/// `brandName` is a proper noun and is intentionally NOT localized — it renders
/// verbatim in every language. `taglineKey` IS localized: it is the English
/// tagline used as the `Localizable.strings` lookup key, resolved through the
/// in-app language override like every other `LocalizedStringKey`.
struct PortfolioApp: Identifiable {
    let brandName: String
    let appStoreID: String
    let taglineKey: LocalizedStringKey
    /// The raw English tagline, kept for the accessibility label (which needs a
    /// resolved `String`, not a `LocalizedStringKey`).
    let taglineText: String
    let symbol: String

    var id: String { appStoreID }

    /// Deep link to the App Store product page. The ID is a known-valid numeric
    /// literal, so the force-unwrap can never fail.
    var appStoreURL: URL { URL(string: "https://apps.apple.com/app/id\(appStoreID)")! }

    /// Tagline resolved to a plain `String` for the accessibility label, using
    /// the English tagline as the lookup key. `Bundle.main` is swizzled by
    /// `LocalizationManager` (OverrideBundle), so this honors the in-app
    /// language override and falls back to the English key if a value is missing.
    var localizedTagline: String {
        Bundle.main.localizedString(forKey: taglineText, value: taglineText, table: nil)
    }
}

/// A Settings `Section` that lists the developer's *other* apps, turning the
/// portfolio into a discovery network: each app surfaces the others, and every
/// row links straight to its App Store page.
///
/// Pass the current app's `appStoreID` so the app never lists itself.
struct CrossPromoSection: View {
    /// App Store ID of the app this section is embedded in; filtered out below.
    let currentAppStoreID: String

    @Environment(LocalizationManager.self) private var l10n

    /// The full portfolio. Brand names are literals; taglines are localized keys.
    private static let portfolio: [PortfolioApp] = [
        PortfolioApp(brandName: "AutoChoice",  appStoreID: "6765667062",
                     taglineKey: "Spin to decide — random picker",
                     taglineText: "Spin to decide — random picker", symbol: "dial.medium"),
        PortfolioApp(brandName: "AltitudeNow", appStoreID: "6765668577",
                     taglineKey: "Live altimeter & barometer",
                     taglineText: "Live altimeter & barometer", symbol: "mountain.2.fill"),
        PortfolioApp(brandName: "DaysUntil",   appStoreID: "6765669356",
                     taglineKey: "Countdowns to what matters",
                     taglineText: "Countdowns to what matters", symbol: "calendar"),
        PortfolioApp(brandName: "PromptVault", appStoreID: "6765668776",
                     taglineKey: "Your AI prompt library",
                     taglineText: "Your AI prompt library", symbol: "text.bubble.fill"),
        PortfolioApp(brandName: "HabitHash",   appStoreID: "6770249417",
                     taglineKey: "Build habits, see your streak",
                     taglineText: "Build habits, see your streak", symbol: "checkmark.seal.fill"),
        PortfolioApp(brandName: "FocusFlow",   appStoreID: "6770252811",
                     taglineKey: "Focus timer that tracks your time",
                     taglineText: "Focus timer that tracks your time", symbol: "timer"),
        PortfolioApp(brandName: "TipJar Now",  appStoreID: "6770249058",
                     taglineKey: "A QR tip jar for creators",
                     taglineText: "A QR tip jar for creators", symbol: "qrcode"),
        PortfolioApp(brandName: "WaterNow",    appStoreID: "6770249191",
                     taglineKey: "Stay hydrated every day",
                     taglineText: "Stay hydrated every day", symbol: "drop.fill"),
    ]

    /// Every app except the one we're embedded in.
    private var others: [PortfolioApp] {
        Self.portfolio.filter { $0.appStoreID != currentAppStoreID }
    }

    var body: some View {
        Section(LocalizedStringKey("More from the developer")) {
            ForEach(others) { app in
                Link(destination: app.appStoreURL) {
                    HStack(spacing: 12) {
                        Image(systemName: app.symbol)
                            .font(.title3)
                            // Color.accentColor (not .tint) to keep a concrete
                            // ShapeStyle out of any future ternary (lesson #62).
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.brandName)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(app.taglineKey)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "\(app.brandName), \(app.localizedTagline)"))
                .accessibilityAddTraits(.isLink)
            }
        }
        // Force the section's localized taglines to re-resolve when the in-app
        // language override changes (lesson #34: SwiftUI caches Text resolution
        // without an identity change). The section lives in the view tree, not a
        // modal, so .id() here is sufficient — no per-modal env injection needed.
        .id(l10n.override)
    }
}
