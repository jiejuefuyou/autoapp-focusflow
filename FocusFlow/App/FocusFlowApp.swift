import SwiftUI
import UserNotifications

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
            .task { applyFocusFilterIfNeeded() }
        }
    }

    // MARK: - Focus Filter activation

    /// Reads the App Group marker written by `FocusBlockFilterIntent.perform()`
    /// and auto-starts a session if the Focus was activated within the last 60 s.
    ///
    /// The 60-second window prevents stale markers from triggering a session
    /// when the user opens the app hours after Focus was activated.
    private func applyFocusFilterIfNeeded() {
        guard let defaults = UserDefaults(suiteName: FocusFilterKeys.groupID) else { return }

        let lastActivated = defaults.double(forKey: FocusFilterKeys.lastActivated)
        let activatedRecently = Date().timeIntervalSince1970 - lastActivated < 60

        guard activatedRecently else { return }
        guard defaults.bool(forKey: FocusFilterKeys.autoStart) else { return }

        // Clear marker immediately so subsequent cold launches don't re-trigger.
        defaults.set(0.0, forKey: FocusFilterKeys.lastActivated)

        let rawMinutes = defaults.integer(forKey: FocusFilterKeys.sessionMinutes)
        let minutes = rawMinutes > 0 ? rawMinutes : 25
        let tagName = defaults.string(forKey: FocusFilterKeys.projectTag)
        let hideNotif = defaults.bool(forKey: FocusFilterKeys.hideNotifications)

        // Resolve optional tag name → existing ProjectTag UUID in the store.
        let resolvedTagId: UUID? = tagName.flatMap { name in
            store.tags.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }?.id
        }

        // Defer until SwiftUI scene is fully mounted (next run-loop cycle).
        Task { @MainActor in
            store.startFocusFilterSession(
                durationSeconds: TimeInterval(minutes * 60),
                tagId: resolvedTagId,
                clearNotifications: hideNotif
            )
        }
    }
}
