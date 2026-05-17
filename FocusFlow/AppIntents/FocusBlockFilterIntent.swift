import AppIntents
import Foundation

/// FocusFlow Focus Filter — auto-starts a Pomodoro session when the user
/// activates a Focus mode (Work / Personal / Sleep / Custom) in iOS Settings.
///
/// iOS discovers this automatically because it conforms to `SetFocusFilterIntent`
/// and is included in the app bundle. Users see it under:
///   Settings → Focus → <any Focus mode> → Add Filter → FocusFlow
///
/// `perform()` writes the chosen preferences to an App Group `UserDefaults`
/// suite. The main app reads the marker on every launch and auto-starts a
/// session if it was activated within the last 60 seconds.
struct FocusBlockFilterIntent: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "FocusFlow"
    static var description: IntentDescription? = IntentDescription(
        "Auto-start a session and apply preferences when this Focus is active."
    )

    // iOS 18+ requires SetFocusFilterIntent to conform to InstanceDisplayRepresentable.
    // This property provides the per-instance display label shown in Settings → Focus.
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "FocusFlow — \(sessionMinutes) min",
            subtitle: projectTag.map { LocalizedStringResource(stringLiteral: $0) }
        )
    }

    /// Session length the user wants when this Focus is active (1–180 min).
    @Parameter(title: "Default session length", default: 25, inclusiveRange: (1, 180))
    var sessionMinutes: Int

    /// Whether to start a session automatically the moment this Focus turns on.
    @Parameter(title: "Auto-start session", default: true)
    var autoStart: Bool

    /// Optional project tag name to pre-select (must match an existing tag in
    /// FocusFlow; if absent or unrecognized the session starts with no tag).
    @Parameter(title: "Project tag")
    var projectTag: String?

    /// When enabled, any pending FocusFlow notifications are cleared so the
    /// Focus filter is not interrupted by earlier reminders.
    @Parameter(title: "Hide notifications", default: true)
    var hideNotifications: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Auto-start \(\.$sessionMinutes)-minute session when Focus turns on") {
            \.$autoStart
            \.$projectTag
            \.$hideNotifications
        }
    }

    // MARK: - Perform

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: FocusFilterKeys.groupID)
        defaults?.set(autoStart,          forKey: FocusFilterKeys.autoStart)
        defaults?.set(sessionMinutes,     forKey: FocusFilterKeys.sessionMinutes)
        defaults?.set(projectTag,         forKey: FocusFilterKeys.projectTag)
        defaults?.set(hideNotifications,  forKey: FocusFilterKeys.hideNotifications)
        defaults?.set(Date().timeIntervalSince1970, forKey: FocusFilterKeys.lastActivated)
        return .result()
    }
}

// MARK: - Shared key constants

/// Single source of truth for App Group UserDefaults keys shared between
/// `FocusBlockFilterIntent` (AppIntents side) and `FocusFlowApp.swift`
/// (main-app side). Using a namespace enum avoids string typos across files.
enum FocusFilterKeys {
    static let groupID          = "group.com.jiejuefuyou.focusflow"
    static let autoStart        = "focusFilter.autoStart"
    static let sessionMinutes   = "focusFilter.sessionMinutes"
    static let projectTag       = "focusFilter.projectTag"
    static let hideNotifications = "focusFilter.hideNotifications"
    static let lastActivated    = "focusFilter.lastActivated"
}
