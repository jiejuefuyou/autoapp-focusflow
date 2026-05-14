import SwiftUI
import UIKit

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentScreen = 0

    var body: some View {
        VStack(spacing: 0) {
            // Always-visible Skip in top-right so users can exit onboarding from any page.
            // Hit area ≥ 44×44pt per Apple HIG (feedback_app_ux_standards P0).
            HStack {
                Spacer()
                Button(action: dismissOnboarding) {
                    Text(LocalizedStringKey("Skip"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .frame(minWidth: 60, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text(LocalizedStringKey("Skip onboarding")))
            }
            .padding(.top, 8)
            .padding(.horizontal, 8)

            TabView(selection: $currentScreen) {
                screen(
                    index: 0,
                    icon: "brain.head.profile",
                    titleKey: "Deep focus, unblocked.",
                    subtitleKey: "Pomodoro 25, deep 45, marathon 90. Pick your length and start.",
                    color: .accentColor
                )
                .tag(0)

                screen(
                    index: 1,
                    icon: "tag.fill",
                    titleKey: "Track by project.",
                    subtitleKey: "Tag each session — Writing, Coding, Study — and see where your week actually went.",
                    color: .indigo
                )
                .tag(1)

                screen(
                    index: 2,
                    icon: "chart.bar.fill",
                    titleKey: "$3.99 once. No sub.",
                    subtitleKey: "Pro: unlimited sessions, full history, unlimited project tags, custom durations, CSV export.",
                    color: .green,
                    showCTA: true
                )
                .tag(2)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }

    private func screen(
        index: Int,
        icon: String,
        titleKey: LocalizedStringKey,
        subtitleKey: LocalizedStringKey,
        color: Color,
        showCTA: Bool = false
    ) -> some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundStyle(color)
            Text(titleKey)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Text(subtitleKey)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            if showCTA {
                Button(action: dismissOnboarding) {
                    Text(LocalizedStringKey("Get Started"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(color, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal)
                .padding(.bottom, 32)
            } else {
                Spacer().frame(height: 80)
            }
        }
    }

    private func dismissOnboarding() {
        hasCompletedOnboarding = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dismiss()
    }
}
