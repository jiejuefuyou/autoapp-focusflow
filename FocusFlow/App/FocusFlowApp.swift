import SwiftUI

@main
struct FocusFlowApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    @State private var iap = IAPManager()
    @State private var store = SessionStore()
    @State private var l10n = LocalizationManager.shared

    init() {
        // Snapshot mode: skip onboarding so UI tests land on the main screen.
        if ProcessInfo.processInfo.arguments.contains("-FASTLANE_SNAPSHOT") {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    ContentView()
                } else {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                }
            }
            .environment(iap)
            .environment(store)
            .environment(l10n)
            .environment(\.locale, l10n.currentLocale)
            .tint(.accentColor)
            .task { await iap.refresh() }
        }
    }
}
