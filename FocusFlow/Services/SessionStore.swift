import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {
    static let freeDailySessionLimit = 5

    var history: [FocusSession] = []
    var currentSession: FocusSession?
    var timeRemaining: TimeInterval = 0
    var isRunning: Bool = false

    private var timer: Timer?
    private let storageKey = "focusflow.history.v1"

    init() {
        load()
    }

    /// Sessions started today (used for free tier limit).
    func sessionsToday() -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return history.filter { cal.startOfDay(for: $0.startedAt) == today }.count
    }

    func startSession(preset: FocusPreset, label: String, tag: String? = nil) {
        let session = FocusSession(duration: preset.seconds, label: label, tag: tag)
        currentSession = session
        timeRemaining = preset.seconds
        isRunning = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.timeRemaining -= 1
                if self.timeRemaining <= 0 {
                    self.complete()
                }
            }
        }
    }

    func pause() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    func resume() {
        guard !isRunning, currentSession != nil else { return }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.timeRemaining -= 1
                if self.timeRemaining <= 0 {
                    self.complete()
                }
            }
        }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        currentSession = nil
        timeRemaining = 0
    }

    func complete() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        guard var session = currentSession else { return }
        session.completed = true
        history.append(session)
        currentSession = nil
        timeRemaining = 0
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([FocusSession].self, from: data) else {
            return
        }
        history = decoded
    }
}
