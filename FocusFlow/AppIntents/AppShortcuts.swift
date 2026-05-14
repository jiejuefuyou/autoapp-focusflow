import AppIntents

/// Required stub so the AppIntents framework correctly discovers
/// `FocusBlockFilterIntent` in the app bundle.
///
/// FocusFlow does not expose any user-visible Shortcuts Actions (all
/// automation happens through the Focus Filter pathway), but iOS 17
/// requires an `AppShortcutsProvider` to be present for intent discovery
/// to function reliably on first launch.
struct FocusFlowShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        // Intentionally empty — Focus Filter intent is discovered automatically
        // via SetFocusFilterIntent conformance; no Siri or Shortcuts surfacing needed.
    }
}
