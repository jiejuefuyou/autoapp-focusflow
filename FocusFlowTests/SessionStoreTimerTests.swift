import XCTest
@testable import FocusFlow

/// Regression tests for SessionStore's wall-clock-anchored timer logic.
///
/// SessionStore is @MainActor @Observable, so every test method is marked
/// `@MainActor`. We call public/internal methods directly; we do NOT drive
/// the 1-Hz Timer (which is an iOS-side runloop artifact) — instead we
/// test `recomputeTimeRemaining()` directly with a manipulated `startedAt`.
///
/// All tests are deterministic: no bare `Date()` comparisons in assertions;
/// simulated elapsed intervals are injected via `startedAt` arithmetic.
@MainActor
final class SessionStoreTimerTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a fresh SessionStore. Because SessionStore.init() loads
    /// persisted UserDefaults, we clear the history key first to avoid
    /// cross-test contamination from previous CI runs.
    private func makeStore() -> SessionStore {
        UserDefaults.standard.removeObject(forKey: "focusflow.history.v2")
        return SessionStore()
    }

    // MARK: - (a) timeRemaining computed from wall-clock is correct after simulated elapsed interval

    /// After starting a 300-second session and simulating 60 s of elapsed
    /// time by back-dating `startedAt`, `recomputeTimeRemaining()` must
    /// produce a value within 1 s of 240.
    func testTimeRemainingAfterSimulatedElapse() {
        let store = makeStore()
        store.startSession(duration: 300)

        // Confirm initial state
        XCTAssertEqual(store.timeRemaining, 300, accuracy: 1.0,
            "timeRemaining should equal duration at session start")
        XCTAssertTrue(store.isRunning)
        XCTAssertNotNil(store.currentSession)

        // Simulate 60 s of elapsed wall-clock by back-dating startedAt
        guard var session = store.currentSession else {
            XCTFail("currentSession must not be nil after startSession")
            return
        }
        session.startedAt = Date().addingTimeInterval(-60)
        store.currentSession = session

        // Trigger the same recompute that the 1-Hz tick calls
        store.recomputeTimeRemaining()

        XCTAssertEqual(store.timeRemaining, 240, accuracy: 1.5,
            "After 60 s elapsed of a 300 s session, timeRemaining must be ≈240 s")
        XCTAssertTrue(store.isRunning,
            "Session must still be running after partial elapsed time")

        store.cancel()
    }

    // MARK: - (b) pause() then resume() preserves remaining time

    /// A 300-second session is started, 100 s simulated, then paused.
    /// After pause the `startedAt` re-anchor must preserve ≈200 s remaining.
    /// After resume, the same remaining time is still available.
    func testPauseResumePrevervesRemainingTime() {
        let store = makeStore()
        store.startSession(duration: 300)

        // Simulate 100 s elapsed before pause
        guard var session = store.currentSession else {
            XCTFail("currentSession must not be nil")
            return
        }
        session.startedAt = Date().addingTimeInterval(-100)
        store.currentSession = session
        store.recomputeTimeRemaining()

        let remainingBeforePause = store.timeRemaining
        XCTAssertEqual(remainingBeforePause, 200, accuracy: 2.0,
            "Precondition: ~200 s should remain after 100 s of a 300 s session")

        // Pause: SessionStore re-anchors startedAt so remaining time is frozen
        store.pause()
        XCTAssertFalse(store.isRunning, "isRunning must be false after pause()")

        let remainingAtPause = store.timeRemaining
        XCTAssertEqual(remainingAtPause, remainingBeforePause, accuracy: 1.0,
            "timeRemaining must be unchanged immediately after pause()")

        // Resume without simulating additional elapsed time
        store.resume()
        XCTAssertTrue(store.isRunning, "isRunning must be true after resume()")

        // Force a recompute right after resume (clock barely moved)
        store.recomputeTimeRemaining()
        XCTAssertEqual(store.timeRemaining, remainingAtPause, accuracy: 2.0,
            "timeRemaining after resume must still be ≈ the value at pause time")

        store.cancel()
    }

    // MARK: - (c) session past its duration reports completion, not negative

    /// A 60-second session with `startedAt` set 70 s in the past should
    /// call `complete()` (via `recomputeTimeRemaining`), leaving
    /// `timeRemaining == 0` (not negative) and the session recorded.
    func testSessionPastDurationCompletesNotNegative() {
        let store = makeStore()
        let initialHistoryCount = store.history.count

        store.startSession(duration: 60)

        guard var session = store.currentSession else {
            XCTFail("currentSession must not be nil")
            return
        }
        // Back-date by 70 s — 10 s past the 60 s duration
        session.startedAt = Date().addingTimeInterval(-70)
        store.currentSession = session

        // Trigger recompute — this should call complete() internally
        store.recomputeTimeRemaining()

        XCTAssertFalse(store.isRunning,
            "isRunning must be false after the session duration has elapsed")
        XCTAssertEqual(store.timeRemaining, 0,
            "timeRemaining must be 0, never negative, after session ends")
        XCTAssertNil(store.currentSession,
            "currentSession must be nil after completion")
        XCTAssertEqual(store.history.count, initialHistoryCount + 1,
            "Completed session must be appended to history")

        let completed = store.history.last
        XCTAssertEqual(completed?.completed, true,
            "Recorded session must be marked completed")
        XCTAssertGreaterThan(completed?.actualDuration ?? 0, 0,
            "actualDuration must be positive for a completed session")
    }

    // MARK: - Bonus: cancel() leaves no residual state

    /// A started session that is cancelled must leave isRunning=false,
    /// timeRemaining=0, and currentSession=nil without adding to history.
    func testCancelLeavesCleanState() {
        let store = makeStore()
        let historyBefore = store.history.count

        store.startSession(duration: 300)
        XCTAssertTrue(store.isRunning)

        store.cancel()

        XCTAssertFalse(store.isRunning)
        XCTAssertEqual(store.timeRemaining, 0)
        XCTAssertNil(store.currentSession)
        XCTAssertEqual(store.history.count, historyBefore,
            "cancel() must not append to history")
    }

    // MARK: - Bonus: FocusPreset seconds are nonzero for non-custom presets

    func testPresetSecondsArePositive() {
        for preset in FocusPreset.allCases where preset != .custom {
            XCTAssertGreaterThan(preset.seconds, 0,
                "\(preset) must have a positive duration")
        }
        XCTAssertEqual(FocusPreset.custom.seconds, 0,
            ".custom must return 0 (caller supplies explicit duration)")
    }
}
