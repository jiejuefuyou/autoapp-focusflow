import XCTest
@testable import FocusFlow

/// Tests for the auto-break cycle state machine added to `SessionStore`:
/// completing a FOCUS block can auto-start a BREAK, and a completed break can
/// loop into the next focus block per the armed cycle count.
///
/// `SessionStore` is `@MainActor @Observable`, so this class is `@MainActor`
/// (a sibling test failed CI on exactly this annotation). Determinism: every
/// transition is driven by calling `complete(now:)` with an *injected* `Date`
/// — never a bare `Date()` inside an assertion — and the pure
/// `autoBreakDecision(for:)` is exercised directly so the focus→break→focus
/// logic is verified without any clock at all.
@MainActor
final class AutoBreakCycleTests: XCTestCase {

    /// A fixed instant used as the injected `now` for every `complete(now:)`
    /// call. Its absolute value is irrelevant — only that it's deterministic.
    private let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeStore() -> SessionStore {
        UserDefaults.standard.removeObject(forKey: "focusflow.history.v2")
        UserDefaults.standard.removeObject(forKey: "focusflow.autoStartBreaks.v1")
        UserDefaults.standard.removeObject(forKey: "focusflow.autoCycleCount.v1")
        return SessionStore()
    }

    // MARK: - Pure decision function (no clock, no side effects)

    /// A focus block with a break armed → `.startBreak`; a break with cycles
    /// left → `.startNextFocus`; a break with none left → `.idle`. We exercise
    /// the public decision function through real arming so we never reach into
    /// the private loop vars.
    func testDecisionFocusWithBreakArmedStartsBreak() {
        let store = makeStore()
        store.startSessionWithAutoBreak(focusSeconds: 1500, breakSeconds: 300, cycleCount: 1)

        XCTAssertEqual(
            store.autoBreakDecision(for: .focus),
            .startBreak(seconds: 300, tagId: nil),
            "A finished focus block with a break armed must start the break."
        )
        store.cancel()
    }

    func testDecisionBareFocusGoesIdle() {
        let store = makeStore()
        // A plain start carries no break plan.
        store.startSession(duration: 1500)
        XCTAssertEqual(
            store.autoBreakDecision(for: .focus),
            .idle,
            "A finished focus block with NO break armed must go idle."
        )
        store.cancel()
    }

    func testDecisionLastBreakGoesIdle() {
        let store = makeStore()
        // cycleCount 1 = one focus + one break, no loop. cyclesRemaining == 0.
        store.startSessionWithAutoBreak(focusSeconds: 1500, breakSeconds: 300, cycleCount: 1)
        XCTAssertEqual(
            store.autoBreakDecision(for: .break),
            .idle,
            "After the final break of a single-cycle run, there is nothing to loop into."
        )
        store.cancel()
    }

    // MARK: - Single cycle: focus → break → idle

    func testSingleCycleFocusThenBreakThenIdle() {
        let store = makeStore()
        let historyBefore = store.history.count

        store.startSessionWithAutoBreak(focusSeconds: 1500, breakSeconds: 300, cycleCount: 1)
        XCTAssertEqual(store.currentPhase, .focus)
        XCTAssertTrue(store.isRunning)

        // Focus completes → break auto-starts.
        store.complete(now: fixedNow)
        XCTAssertEqual(store.currentPhase, .break,
            "Completing the focus block must auto-start the break phase.")
        XCTAssertTrue(store.isRunning, "The break timer must be running.")
        XCTAssertEqual(store.timeRemaining, 300, accuracy: 0.5,
            "The break must run for the technique's break length.")
        XCTAssertEqual(store.history.count, historyBefore + 1,
            "The focus block must be recorded to history.")
        XCTAssertNotNil(store.pendingTagAssignmentSessionId,
            "The completed focus block must still prompt for a tag.")

        // The recorded focus session must carry the injected completion time
        // (deterministic — proves we used `now`, not a bare Date()).
        XCTAssertEqual(store.history.last?.completedAt, fixedNow,
            "Recorded focus completion time must equal the injected `now`.")

        // Break completes → idle (single cycle has no loop).
        store.complete(now: fixedNow)
        XCTAssertEqual(store.currentPhase, .focus,
            "After the final break the phase resets to focus (idle).")
        XCTAssertFalse(store.isRunning, "Nothing should be running once the run ends.")
        XCTAssertNil(store.currentSession)
        XCTAssertEqual(store.timeRemaining, 0)
        XCTAssertEqual(store.history.count, historyBefore + 1,
            "Breaks must NOT be recorded to history (only the one focus block).")
    }

    // MARK: - Two cycles: focus → break → focus → break → idle

    func testTwoCycleFullTransitionSequence() {
        let store = makeStore()
        let historyBefore = store.history.count

        // 2 focus blocks, each followed by a break.
        store.startSessionWithAutoBreak(focusSeconds: 1500, breakSeconds: 300, cycleCount: 2)
        XCTAssertEqual(store.currentPhase, .focus)
        XCTAssertEqual(store.cyclesRemaining, 1,
            "cyclesRemaining counts focus blocks AFTER the current one (2 - 1).")

        // Focus #1 → Break #1
        store.complete(now: fixedNow)
        XCTAssertEqual(store.currentPhase, .break)
        XCTAssertTrue(store.isRunning)
        XCTAssertEqual(store.cyclesRemaining, 1,
            "A break does not consume a cycle; the loop counter holds.")

        // Break #1 → Focus #2 (loops back; counter decrements)
        store.complete(now: fixedNow)
        XCTAssertEqual(store.currentPhase, .focus,
            "A break with cycles left must loop into the next focus block.")
        XCTAssertTrue(store.isRunning)
        XCTAssertEqual(store.timeRemaining, 1500, accuracy: 0.5,
            "The looped focus block reuses the armed focus length.")
        XCTAssertEqual(store.cyclesRemaining, 0,
            "Entering the final focus block must drop cyclesRemaining to 0.")

        // Focus #2 → Break #2
        store.complete(now: fixedNow)
        XCTAssertEqual(store.currentPhase, .break)
        XCTAssertTrue(store.isRunning)

        // Break #2 → idle (no cycles left)
        store.complete(now: fixedNow)
        XCTAssertEqual(store.currentPhase, .focus)
        XCTAssertFalse(store.isRunning)
        XCTAssertNil(store.currentSession)

        XCTAssertEqual(store.history.count, historyBefore + 2,
            "Exactly the two focus blocks are recorded; neither break is.")
        XCTAssertTrue(store.history.suffix(2).allSatisfy { $0.completed },
            "Both recorded focus blocks must be marked completed.")
    }

    // MARK: - Loop-forever (Int.max) never decrements / never goes idle on its own

    func testLoopForeverKeepsCyclingUntilStopped() {
        let store = makeStore()

        store.startSessionWithAutoBreak(focusSeconds: 600, breakSeconds: 120, cycleCount: Int.max)
        XCTAssertEqual(store.cyclesRemaining, Int.max,
            "Loop-forever must preserve Int.max without overflow (no count - 1).")

        // Run several focus→break→focus transitions; the run must never idle.
        for _ in 0..<3 {
            store.complete(now: fixedNow)               // focus → break
            XCTAssertEqual(store.currentPhase, .break)
            XCTAssertTrue(store.isRunning)

            store.complete(now: fixedNow)               // break → focus (loops)
            XCTAssertEqual(store.currentPhase, .focus,
                "An open-ended run must always loop back into focus.")
            XCTAssertTrue(store.isRunning)
            XCTAssertEqual(store.cyclesRemaining, Int.max,
                "Loop-forever must not decrement the counter.")
        }

        // The user stopping aborts the whole run.
        store.cancel()
        XCTAssertFalse(store.isRunning)
        XCTAssertEqual(store.currentPhase, .focus)
        XCTAssertEqual(store.cyclesRemaining, 0,
            "cancel() must tear down the auto-cycle plan.")
        XCTAssertEqual(
            store.autoBreakDecision(for: .focus),
            .idle,
            "After cancel the plan is cleared, so a focus completion would idle."
        )
    }

    // MARK: - Tier clamp: free users get a single focus+break, Pro gets the loop

    func testClampedAutoCycleCountGatesMultiCycleBehindPro() {
        let store = makeStore()
        store.autoCycleCount = 4

        XCTAssertEqual(store.clampedAutoCycleCount(isPremium: true), 4,
            "Premium honors the stored multi-cycle preference.")
        XCTAssertEqual(store.clampedAutoCycleCount(isPremium: false),
                       SessionStore.freeAutoCycleCount,
            "Free tier is clamped to a single focus+break regardless of the stored value.")

        // A loop-forever preference is likewise clamped for free users.
        store.autoCycleCount = Int.max
        XCTAssertEqual(store.clampedAutoCycleCount(isPremium: false),
                       SessionStore.freeAutoCycleCount,
            "Free tier cannot select loop-forever.")
        XCTAssertEqual(store.clampedAutoCycleCount(isPremium: true), Int.max,
            "Premium can select loop-forever.")
    }

    // MARK: - A custom (no-break) start never arms a break even with toggle intent

    func testZeroBreakSecondsDegradesToPlainFocus() {
        let store = makeStore()

        // breakSeconds 0 (e.g. a custom duration) must not arm a break.
        store.startSessionWithAutoBreak(focusSeconds: 1800, breakSeconds: 0, cycleCount: 3)
        XCTAssertEqual(store.currentPhase, .focus)
        XCTAssertTrue(store.isRunning)

        store.complete(now: fixedNow)
        XCTAssertEqual(store.currentPhase, .focus,
            "With no break armed, a finished focus block goes straight to idle.")
        XCTAssertFalse(store.isRunning)
        XCTAssertNil(store.currentSession)
    }
}
