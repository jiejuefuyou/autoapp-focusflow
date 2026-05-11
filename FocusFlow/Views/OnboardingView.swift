import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var currentScreen = 0

    var body: some View {
        TabView(selection: $currentScreen) {
            screen(
                index: 0,
                icon: "brain.head.profile",
                title: "Deep focus, unblocked.",
                subtitle: "Pomodoro 25, deep 45, marathon 90. Pick your length and start.",
                color: .accentColor
            )
            .tag(0)

            screen(
                index: 1,
                icon: "moon.fill",
                title: "Auto Do Not Disturb.",
                subtitle: "Pro: app auto-toggles iOS Focus filter when session starts. No more dings.",
                color: .indigo
            )
            .tag(1)

            screen(
                index: 2,
                icon: "chart.bar.fill",
                title: "$3.99 once. No sub.",
                subtitle: "Pro: unlimited sessions, full history, project tags, Apple Watch, widget.",
                color: .green,
                showCTA: true
            )
            .tag(2)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .ignoresSafeArea()
    }

    private func screen(
        index: Int,
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        showCTA: Bool = false
    ) -> some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundStyle(color)
            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            if showCTA {
                Button {
                    hasSeenOnboarding = true
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(color, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            } else {
                Spacer().frame(height: 80)
            }
        }
    }
}
