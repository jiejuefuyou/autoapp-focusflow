import SwiftUI

/// Press feedback for custom-styled buttons.
///
/// `.buttonStyle(.plain)` drops the default press animation entirely, which leaves
/// custom-drawn buttons (filled backgrounds, capsules, cards) feeling dead on tap.
/// Apply this style to critical CTAs (paywall, upsell rows, onboarding actions)
/// so the user gets the scale + opacity feedback iOS users expect.
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
