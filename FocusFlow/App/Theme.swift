//  Theme.swift — PORTFOLIO CANONICAL (orchestrator/ios-core)
//
//  Single source of truth for all autoapp iOS apps. DO NOT edit per-app copies.
//  Edit orchestrator/ios-core/swift/Theme.swift, then run:
//      python dashboard/sync_ios_core.py --apply
//  Drift is gated by dashboard/audit_portfolio.py (core-sync check).
//
//  SYNC MODE: brand_inject. Everything below the brand block is identical across
//  the portfolio and enforced. The three `brand*` lines + the hex/name comments
//  are per-app: sync_ios_core.py reads each app's CURRENT brand values and
//  re-injects them, so the design-token system stays unified while each app
//  keeps its own palette. (Supersedes orchestrator/templates/Theme.swift.)
//
import SwiftUI

// MARK: - Brand colors (FocusFlow)
//
// Per-app brand colors are app-specific; shared semantic colors are identical
// across the portfolio. The hex comments must match the (red:r, green:g, blue:b)
// values (so an art audit can grep them) and the AccentColor asset.
//
// FocusFlow palette:
//   brandPrimary:   #FF6B35
//   brandSecondary: #D94312
//   brandTint:      #FFAD82

extension Color {

    // MARK: - Per-app brand
    // These three define this app's visual identity. The `brandPrimary` MUST
    // match the value baked into `Assets.xcassets/AccentColor.colorset` so
    // `Color.accentColor` and `Color.brandPrimary` render identically.
    static let brandPrimary   = Color(red: 1.00, green: 0.42, blue: 0.21)
    static let brandSecondary = Color(red: 0.85, green: 0.26, blue: 0.07)
    static let brandTint      = Color(red: 1.00, green: 0.68, blue: 0.51)

    // MARK: - Shared semantic surfaces (identical across portfolio)
    static let surface            = Color(uiColor: .secondarySystemBackground)
    static let surfaceElevated    = Color(uiColor: .tertiarySystemBackground)
    static let onSurface          = Color.primary
    static let onSurfaceSecondary = Color.secondary

    // MARK: - Shared semantic status (identical across portfolio)
    // Use these for non-brand status indicators — success badges, errors,
    // warnings — so the same green/amber/red shows up everywhere.
    static let success = Color(red: 0.20, green: 0.65, blue: 0.45)   // emerald
    static let warning = Color(red: 0.95, green: 0.60, blue: 0.20)   // amber
    static let error   = Color(red: 0.85, green: 0.25, blue: 0.30)   // red

    // MARK: - Urgency scale (for countdown / progress semantics)
    static let urgent   = Color.error
    static let upcoming = Color.warning
    static let stable   = Color.primary
}

// MARK: - Typography (identical across portfolio)
//
// Use Typography.* in every Text(...).font(...) call. Hardcoded
// `.font(.system(size: N))` is forbidden — see lesson #16 (Dynamic Type
// compliance) and art-audit 2026-05-23 (every app had ≥1 hardcoded font).

enum Typography {
    /// Hero / display — for app-name, splash, top-of-screen title
    static let h1           = Font.system(.largeTitle, design: .rounded, weight: .heavy)
    /// Section title — for navigation titles, large sheet headers
    static let h2           = Font.system(.title,      design: .rounded, weight: .bold)
    /// Subsection title — for grouped row leading titles
    static let h3           = Font.system(.title3,     design: .default, weight: .semibold)
    /// Body — for paragraphs, row content
    static let body         = Font.system(.body,       design: .default)
    /// Body emphasis — for first-line of a multi-line row content
    static let bodyEmphasis = Font.system(.body,       design: .default, weight: .semibold)
    /// Caption — for metadata, timestamps
    static let caption      = Font.system(.caption,    design: .default)
    /// Caption emphasis — for badge text, button affordance hints
    static let captionEmphasis = Font.system(.caption, design: .default, weight: .medium)
    /// Monospace body — for code / prompt / numeric data
    static let monospace    = Font.system(.body,       design: .monospaced)

    /// Display number — for countdown / score / large data readouts (56pt scaling-safe)
    static let displayNumber = Font.system(size: 56, weight: .heavy, design: .rounded)

    /// Display result — for spin-wheel result, large transient feedback
    /// (scales with Dynamic Type, unlike `displayNumber` which is fixed-size)
    static let displayResult = Font.system(.title, design: .rounded, weight: .heavy)

    /// Tabular figures — for time / altitude reads (consistent digit width)
    static var tabularBody: Font {
        Font.system(.body, design: .monospaced).monospacedDigit()
    }

    /// Monospace digit headline — for day-count, ml, percentage that line up in a column
    static var monoHeadline: Font {
        Font.system(.headline, design: .rounded, weight: .heavy).monospacedDigit()
    }
}

// MARK: - Spacing (identical across portfolio)
//
// Use Spacing.* for every `.padding(...)` and HStack/VStack `spacing:`.
// 8pt baseline grid. Hardcoded magic numbers are forbidden in PR review.

enum Spacing {
    /// 4pt — tight icon-to-text, inline badge offset
    static let xs:  CGFloat = 4
    /// 8pt — caption-to-content, dense list rows
    static let sm:  CGFloat = 8
    /// 16pt — default content padding, between paragraphs
    static let md:  CGFloat = 16
    /// 24pt — section breaks, card content padding
    static let lg:  CGFloat = 24
    /// 32pt — between major sections, modal padding
    static let xl:  CGFloat = 32
    /// 48pt — top of hero screens, dramatic separation
    static let xxl: CGFloat = 48
}

// MARK: - Corner radius (identical across portfolio)

enum Radius {
    /// 6pt — pills, small chips, badge corners
    static let sm:   CGFloat = 6
    /// 12pt — card corners, sheet content
    static let md:   CGFloat = 12
    /// 16pt — card content / feature-list container (most-used inset radius)
    static let card: CGFloat = 16
    /// 20pt — large feature card corners, prominent CTA
    static let lg:   CGFloat = 20
    /// 999 — full pill (use over `Capsule()` for type-consistency)
    static let pill: CGFloat = 999
}

// MARK: - Elevation / shadow (identical across portfolio)

struct ShadowSpec {
    let color:  Color
    let radius: CGFloat
    let x:      CGFloat
    let y:      CGFloat
}

enum Elevation {
    /// Card resting state — subtle separation from background
    static let card  = ShadowSpec(color: .black.opacity(0.06), radius: 6,  x: 0, y: 2)
    /// Card hover/press state — lifted feel
    static let hover = ShadowSpec(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
    /// Floating elements — paywall CTA, hero data
    static let floating = ShadowSpec(color: .black.opacity(0.18), radius: 24, x: 0, y: 12)
}

extension View {
    /// Apply a portfolio-standard shadow. Default is `Elevation.card`.
    func brandCardShadow(_ spec: ShadowSpec = Elevation.card) -> some View {
        self.shadow(color: spec.color, radius: spec.radius, x: spec.x, y: spec.y)
    }
}

// MARK: - Brand gradient (for paywall CTA, hero accents)

extension LinearGradient {
    /// brandPrimary → brandTint diagonal — for primary CTAs that need a "wow"
    /// purchase moment. Use sparingly; per art-audit 2026-05-23, paywall CTA is
    /// the single highest-impact place to apply this.
    static var brandHero: LinearGradient {
        LinearGradient(
            colors: [.brandPrimary, .brandTint],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
