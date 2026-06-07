//  ScaleButtonStyle.swift — PORTFOLIO CANONICAL (orchestrator/ios-core)
//
//  Single source of truth for all autoapp iOS apps. DO NOT edit per-app copies.
//  Edit orchestrator/ios-core/swift/ScaleButtonStyle.swift, then run:
//      python dashboard/sync_ios_core.py --apply
//  Drift is gated by dashboard/audit_portfolio.py (core-sync check).
//
import SwiftUI

/// Press feedback for custom-styled buttons (filled background + foreground
/// drawn manually inside the label). SwiftUI's default `.borderless` /
/// `.plain` styles don't animate these, so the button feels dead on tap.
/// Apply this on the prime CTAs (paywall purchase, onboarding next).
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
