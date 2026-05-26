import Foundation
import Observation
import SwiftUI
import UIKit
import UserNotifications

/// Single source of truth for the focus timer state + persisted history + tags.
///
/// v1 persists to `UserDefaults` as JSON. SwiftData was considered and rejected
/// for this scope — schema migration risk outweighs the ergonomic gain at the
/// session counts we expect (≤ a few thousand entries before the user upgrades
/// to Premium which surfaces full history). When history outgrows
/// UserDefaults' ~4 MB practical ceiling we revisit.
@MainActor
@Observable
final class SessionStore {
    /// Free-tier per-day session cap. Premium = unlimited.
    static let freeDailySessionLimit = 5

    /// Free tier sees only the first N default tags.
    static let freeTagLimit = 3

    // MARK: - Persisted state

    private(set) var history: [FocusSession] = []
    private(set) var tags: [ProjectTag] = []

    // MARK: - Transient timer state

    var currentSession: FocusSession?
    var timeRemaining: TimeInterval = 0
    var isRunning: Bool = false

    /// True after `complete()` fires; ContentView watches this to present the
    /// ProjectTagPicker sheet. Caller is expected to clear it via `assignTag`
    /// or `dismissPendingTag`.
    var pendingTagAssignmentSessionId: UUID?

    private var timer: Timer?

    /// Observer token for `UIApplication.didBecomeActiveNotification` — used
    /// to recompute `timeRemaining` from wall-clock when the app comes back
    /// to the foreground (v1.0.11 Sprint A P0-2 timer-drift fix).
    ///
    /// Marked `nonisolated(unsafe)` so `deinit` can read it (which is nonisolated
    /// on `@MainActor` classes). Mirrors the `listenerTask` pattern in IAPManager.
    private nonisolated(unsafe) var foregroundObserver: NSObjectProtocol?

    /// Identifier prefix used when scheduling the session-complete UNNotification.
    /// We append the session UUID so we can cancel exactly the pending request
    /// without disturbing other app-scheduled notifications.
    private static let completionNotifIDPrefix = "focusflow.session.complete."

    // MARK: - Storage keys

    private let historyKey = "focusflow.history.v2"
    private let tagsKey = "focusflow.tags.v1"

    init() {
        loadTags()
        loadHistory()
        installForegroundObserver()
    }

    deinit {
        if let token = foregroundObserver {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // MARK: - Free tier helpers

    /// Sessions started today (used for free tier limit).
    func sessionsToday() -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return history.filter { cal.startOfDay(for: $0.startedAt) == today }.count
    }

    /// Tags the user is allowed to pick on the current tier.
    func availableTags(isPremium: Bool) -> [ProjectTag] {
        if isPremium { return tags }
        return Array(tags.prefix(Self.freeTagLimit))
    }

    // MARK: - Timer control

    /// Starts a session with an arbitrary duration in seconds. Caller is
    /// responsible for Premium gating on `.custom` durations.
    ///
    /// v1.0.11 Sprint A P0-2: `startedAt` is anchored to wall clock so
    /// `recomputeTimeRemaining()` can re-derive `timeRemaining` after the
    /// app backgrounds (where `Timer.scheduledTimer` is suspended by iOS).
    ///
    /// v1.0.11 Sprint A P0-3: schedules a `UNTimeIntervalNotificationTrigger`
    /// so iOS fires "Focus complete!" even if the app is killed.
    func startSession(duration: TimeInterval, tagId: UUID? = nil) {
        guard duration > 0 else { return }
        cancelTimer()
        let now = Date()
        let session = FocusSession(
            startedAt: now,
            duration: duration,
            actualDuration: 0,
            tagId: tagId
        )
        currentSession = session
        timeRemaining = duration
        isRunning = true
        scheduleTick()
        scheduleCompletionNotification(for: session, in: duration)
    }

    /// Convenience wrapper for preset taps. `.custom` is a no-op here —
    /// PresetPicker must route the user to `startSession(duration:...)` with
    /// the explicit value from the custom-duration sheet.
    func startSession(preset: FocusPreset, tagId: UUID? = nil) {
        guard preset != .custom else { return }
        startSession(duration: preset.seconds, tagId: tagId)
    }

    /// Called by the Focus Filter activation path in `FocusFlowApp`.
    ///
    /// Starts a session with the user's per-Focus preferences.
    /// If `clearNotifications` is true, any pending FocusFlow notifications
    /// are removed so the Focus mode isn't interrupted by stale reminders.
    func startFocusFilterSession(
        durationSeconds: TimeInterval,
        tagId: UUID? = nil,
        clearNotifications: Bool = false
    ) {
        if clearNotifications {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
        startSession(duration: max(durationSeconds, 60), tagId: tagId)
    }

    func pause() {
        guard isRunning else { return }
        cancelTimer()
        isRunning = false
        // Pull the pending completion notification — wall-clock has stopped
        // advancing for this session.
        if let session = currentSession {
            cancelCompletionNotification(for: session)
        }
        // Re-anchor `startedAt` so that on `resume()` the wall-clock recompute
        // continues from where the user paused, not from the original start.
        if var session = currentSession {
            session.startedAt = Date().addingTimeInterval(-(session.duration - timeRemaining))
            currentSession = session
        }
    }

    func resume() {
        guard !isRunning, var session = currentSession, timeRemaining > 0 else { return }
        // Re-anchor `startedAt` so wall-clock recompute reflects the
        // post-pause start. Equivalent: now - (duration - timeRemaining).
        session.startedAt = Date().addingTimeInterval(-(session.duration - timeRemaining))
        currentSession = session
        isRunning = true
        scheduleTick()
        scheduleCompletionNotification(for: session, in: timeRemaining)
    }

    func cancel() {
        cancelTimer()
        if let session = currentSession {
            cancelCompletionNotification(for: session)
        }
        currentSession = nil
        timeRemaining = 0
        isRunning = false
    }

    /// Called automatically when `timeRemaining` reaches 0.
    func complete() {
        cancelTimer()
        isRunning = false
        guard var session = currentSession else { return }
        // If we are completing via the in-app recompute path before the system
        // notification fires, pull the now-redundant pending notification.
        // (Idempotent if the notification already delivered.)
        cancelCompletionNotification(for: session)
        session.completed = true
        session.completedAt = Date()
        session.actualDuration = session.duration
        history.append(session)
        pendingTagAssignmentSessionId = session.id
        currentSession = nil
        timeRemaining = 0
        persistHistory()
    }

    /// Assigns a tag to the just-completed session and clears the pending flag.
    func assignTag(_ tagId: UUID?, toSessionId sessionId: UUID) {
        guard let idx = history.firstIndex(where: { $0.id == sessionId }) else {
            pendingTagAssignmentSessionId = nil
            return
        }
        history[idx].tagId = tagId
        pendingTagAssignmentSessionId = nil
        persistHistory()
    }

    /// Dismisses the tag-picker sheet without choosing a tag.
    func dismissPendingTag() {
        pendingTagAssignmentSessionId = nil
    }

    // MARK: - Tag CRUD

    func addTag(_ tag: ProjectTag) {
        guard !tags.contains(where: { $0.id == tag.id }) else { return }
        tags.append(tag)
        persistTags()
    }

    func deleteTag(_ tag: ProjectTag) {
        tags.removeAll { $0.id == tag.id }
        persistTags()
    }

    func tag(forId id: UUID) -> ProjectTag? {
        tags.first { $0.id == id }
    }

    // MARK: - Analytics helpers

    /// Returns total focus minutes per calendar day for the last 7 days
    /// (oldest first, today last).
    func dailyMinutesLast7Days() -> [DailyMinutes] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var out: [DailyMinutes] = []
        for offset in stride(from: -6, through: 0, by: 1) {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let nextDay = cal.date(byAdding: .day, value: 1, to: day) ?? day
            let total = history
                .filter { $0.completed && $0.startedAt >= day && $0.startedAt < nextDay }
                .reduce(0.0) { $0 + $1.actualDuration }
            out.append(DailyMinutes(date: day, minutes: total / 60.0))
        }
        return out
    }

    /// Returns focus minutes by tag for the last 7 days. Untagged sessions are
    /// aggregated under `nil` tag id.
    func minutesByTagLast7Days() -> [TagMinutes] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let weekStart = cal.date(byAdding: .day, value: -6, to: today) else { return [] }
        var totals: [UUID?: TimeInterval] = [:]
        for s in history where s.completed && s.startedAt >= weekStart {
            totals[s.tagId, default: 0] += s.actualDuration
        }
        return totals.map { TagMinutes(tagId: $0.key, minutes: $0.value / 60.0) }
            .sorted { $0.minutes > $1.minutes }
    }

    // MARK: - Persistence (UserDefaults Codable JSON)

    private func persistHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([FocusSession].self, from: data) else {
            return
        }
        history = decoded
    }

    private func persistTags() {
        guard let data = try? JSONEncoder().encode(tags) else { return }
        UserDefaults.standard.set(data, forKey: tagsKey)
    }

    private func loadTags() {
        if let data = UserDefaults.standard.data(forKey: tagsKey),
           let decoded = try? JSONDecoder().decode([ProjectTag].self, from: data),
           !decoded.isEmpty {
            tags = decoded
            return
        }
        // First launch — seed defaults.
        tags = ProjectTag.defaults
        persistTags()
    }

    // MARK: - Timer plumbing

    /// 1-Hz tick used purely to drive UI refresh of `timeRemaining`. The actual
    /// remaining-time math is anchored to wall clock (`Date()` vs
    /// `session.startedAt`) so backgrounding the app does NOT drift the timer.
    ///
    /// v1.0.11 Sprint A P0-2: previous implementation decremented a counter
    /// per tick. iOS suspends the timer on background, so the counter stalled
    /// while wall clock advanced. On foreground the user saw stale remaining
    /// time. New behavior: every tick re-derives `timeRemaining` from the
    /// wall-clock delta, and `recomputeTimeRemaining()` is also invoked from
    /// `UIApplication.didBecomeActiveNotification` for immediate accuracy on
    /// foreground.
    private func scheduleTick() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.recomputeTimeRemaining()
            }
        }
    }

    /// Re-derives `timeRemaining` from `Date()` and the session's
    /// `startedAt`. Called from the 1-Hz tick and the foreground observer.
    /// If the session has elapsed, drives `complete()`.
    func recomputeTimeRemaining() {
        guard isRunning, let session = currentSession else { return }
        let elapsed = Date().timeIntervalSince(session.startedAt)
        let remaining = max(0, session.duration - elapsed)
        timeRemaining = remaining
        if remaining <= 0 {
            complete()
        }
    }

    private func cancelTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Foreground observer (v1.0.11 Sprint A P0-2)

    private func installForegroundObserver() {
        // Coalesce duplicates: never install more than one observer per instance.
        guard foregroundObserver == nil else { return }
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // `addObserver` queue `.main` means this block already executes on
            // the main thread, but `recomputeTimeRemaining` is @MainActor —
            // hop explicitly so the Swift concurrency checker is satisfied.
            Task { @MainActor [weak self] in
                self?.recomputeTimeRemaining()
            }
        }
    }

    // MARK: - Notifications (v1.0.11 Sprint A P0-3)

    /// Requests user permission to post local notifications for the
    /// session-complete signal. Idempotent — repeated calls are cheap
    /// because the system tracks the prior authorization decision.
    /// Errors are swallowed: notification authorization is best-effort,
    /// not required for the timer to function.
    private func requestNotifPermission() async {
        do {
            _ = try await UNUserNotificationCenter
                .current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            // No-op — permission denial doesn't break the in-app flow.
        }
    }

    /// Schedules a one-shot "Focus complete!" local notification `seconds`
    /// from now. Identifier embeds the session UUID so we can cancel exactly
    /// this pending request from `pause()` / `cancel()`.
    private func scheduleCompletionNotification(for session: FocusSession, in seconds: TimeInterval) {
        guard seconds > 0 else { return }
        // Fire-and-forget permission request — never blocks the timer start.
        Task { [weak self] in
            await self?.requestNotifPermission()
        }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.session_complete.title")
        content.body = String(localized: "notification.session_complete.body")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.completionNotifIDPrefix + session.id.uuidString,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    /// Removes the pending completion notification for the given session, if any.
    private func cancelCompletionNotification(for session: FocusSession) {
        UNUserNotificationCenter
            .current()
            .removePendingNotificationRequests(
                withIdentifiers: [Self.completionNotifIDPrefix + session.id.uuidString]
            )
    }
}

// MARK: - Analytics row types

struct DailyMinutes: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let minutes: Double
}

struct TagMinutes: Identifiable, Hashable {
    var id: String { tagId?.uuidString ?? "untagged" }
    let tagId: UUID?
    let minutes: Double
}
