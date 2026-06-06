import XCTest
@testable import FocusFlow

/// Tests for NEW pure logic: the `FocusPreset` enrichment (free/premium gating,
/// rawValue + seconds regression guards) and the deterministic, store-state
/// helpers `currentStreak` / `bestStreak` / `todayGoalProgress`.
///
/// `SessionStore` is `@MainActor @Observable`, so every test that touches it is
/// `@MainActor`. Determinism: we never assert on bare `Date()`; store state is
/// driven through the public API (`startSession` + back-date `startedAt` +
/// `recomputeTimeRemaining()` to force `complete()`), exactly as the existing
/// SessionStoreTimerTests do. `history` is `private(set)`, so this is the only
/// supported way to populate it — and a session completed via this path lands on
/// the current calendar day, which is all the streak/goal assertions rely on.
@MainActor
final class FocusFlowNewLogicTests: XCTestCase {

    // MARK: - Fresh store helper (clears persisted UserDefaults blobs)

    private func makeStore() -> SessionStore {
        UserDefaults.standard.removeObject(forKey: "focusflow.history.v2")
        UserDefaults.standard.removeObject(forKey: "focusflow.dailyGoalMinutes.v1")
        UserDefaults.standard.removeObject(forKey: "focusflow.premiumTechniqueTrialUsed.v1")
        return SessionStore()
    }

    /// Completes one session of `durationSeconds` "today" by back-dating its
    /// start past the duration and driving the wall-clock recompute → complete().
    /// Returns after the session has been appended to history.
    private func completeOneSessionToday(_ store: SessionStore, durationSeconds: TimeInterval) {
        store.startSession(duration: durationSeconds)
        guard var session = store.currentSession else {
            XCTFail("currentSession must not be nil after startSession")
            return
        }
        // Back-date so elapsed > duration → recompute calls complete().
        session.startedAt = Date().addingTimeInterval(-(durationSeconds + 5))
        store.currentSession = session
        store.recomputeTimeRemaining()
    }

    // MARK: - FocusPreset: free-tier rawValue + seconds regression guard

    func testFreePresetRawValuesUnchanged() {
        // The refactor MUST keep the original three rawValues so persisted
        // selections / @SceneStorage round-trips stay valid.
        XCTAssertEqual(FocusPreset.short25.rawValue, "25")
        XCTAssertEqual(FocusPreset.medium50.rawValue, "50")
        XCTAssertEqual(FocusPreset.long90.rawValue, "90")
        XCTAssertEqual(FocusPreset.custom.rawValue, "custom")
    }

    func testFreePresetSecondsUnchanged() {
        XCTAssertEqual(FocusPreset.short25.seconds, 1500)  // 25 min
        XCTAssertEqual(FocusPreset.medium50.seconds, 3000) // 50 min
        XCTAssertEqual(FocusPreset.long90.seconds, 5400)   // 90 min
    }

    func testFreePresetsDecodeFromLegacyRawValues() throws {
        // Persisted-as-rawValue backward-compat: "25"/"50"/"90" must still decode.
        for (raw, expected) in [("25", FocusPreset.short25),
                                ("50", FocusPreset.medium50),
                                ("90", FocusPreset.long90)] {
            let json = "\"\(raw)\"".data(using: .utf8)!
            let decoded = try JSONDecoder().decode(FocusPreset.self, from: json)
            XCTAssertEqual(decoded, expected, "rawValue \(raw) must decode to \(expected)")
        }
    }

    // MARK: - FocusPreset: premium gating

    func testRequiresPremiumFalseForTheThreeFreePresets() {
        XCTAssertFalse(FocusPreset.short25.requiresPremium)
        XCTAssertFalse(FocusPreset.medium50.requiresPremium)
        XCTAssertFalse(FocusPreset.long90.requiresPremium)
    }

    func testRequiresPremiumTrueForAllPremiumPlusCustom() {
        let premium: [FocusPreset] = [
            .deskTime5217, .studySprint45, .examCram60, .writingFlow50,
            .quickSprint15, .flowState75, .windDown20, .custom,
        ]
        for preset in premium {
            XCTAssertTrue(preset.requiresPremium, "\(preset) must require premium")
        }
        // Exactly 3 free presets across all cases (custom is premium-gated).
        let free = FocusPreset.allCases.filter { !$0.requiresPremium }
        XCTAssertEqual(free.count, 3, "Exactly three presets are free")
    }

    // MARK: - FocusPreset: new techniques (content-depth additions)

    func testNewPremiumTechniquesRawValuesAndDurations() {
        // New curated techniques: stable rawValues + minute-derived seconds.
        XCTAssertEqual(FocusPreset.flowState75.rawValue, "flowState75")
        XCTAssertEqual(FocusPreset.windDown20.rawValue, "windDown20")
        XCTAssertEqual(FocusPreset.flowState75.focusMinutes, 75)
        XCTAssertEqual(FocusPreset.windDown20.focusMinutes, 20)
        XCTAssertEqual(FocusPreset.flowState75.seconds, 75 * 60)
        XCTAssertEqual(FocusPreset.windDown20.seconds, 20 * 60)
        // Both are premium and both appear in the library.
        XCTAssertTrue(FocusPreset.flowState75.requiresPremium)
        XCTAssertTrue(FocusPreset.windDown20.requiresPremium)
        XCTAssertTrue(FocusPreset.library.contains(.flowState75))
        XCTAssertTrue(FocusPreset.library.contains(.windDown20))
    }

    func testEveryLibraryPresetHasNonEmptyNameAndDescriptionKeys() {
        for preset in FocusPreset.library {
            XCTAssertFalse(preset.nameKey.isEmpty, "\(preset) needs a name key")
            XCTAssertFalse(preset.descriptionKey.isEmpty, "\(preset) needs a description key")
        }
    }

    func testPremiumLibraryMatchesRequiresPremiumFilter() {
        // premiumLibrary is the source of truth for "unlock all N" copy + trial
        // accounting — it must equal the requires-premium subset of the library.
        XCTAssertEqual(Set(FocusPreset.premiumLibrary),
                       Set(FocusPreset.library.filter(\.requiresPremium)))
        XCTAssertFalse(FocusPreset.premiumLibrary.contains(.custom),
                       "custom has its own chip; never counted in premiumLibrary")
        XCTAssertEqual(FocusPreset.premiumLibrary.count, 7,
                       "3 free of 10 library techniques → 7 premium")
        XCTAssertEqual(FocusPreset.library.count, 10)
    }

    // MARK: - FocusPreset: library composition

    func testLibraryExcludesCustom() {
        XCTAssertFalse(FocusPreset.library.contains(.custom), "library must not list the custom-duration affordance")
        // library = all named techniques = allCases minus custom.
        XCTAssertEqual(FocusPreset.library.count, FocusPreset.allCases.count - 1)
        XCTAssertEqual(Set(FocusPreset.library), Set(FocusPreset.allCases).subtracting([.custom]))
    }

    func testLibrarySecondsAllPositive() {
        for preset in FocusPreset.library {
            XCTAssertGreaterThan(preset.seconds, 0, "Library preset \(preset) must have positive seconds")
        }
    }

    // MARK: - SessionStore streak / goal (deterministic via public API)

    func testEmptyStoreStreaksAndGoalAreZero() {
        let store = makeStore()
        XCTAssertEqual(store.currentStreak, 0, "Fresh store has no completed sessions → streak 0")
        XCTAssertEqual(store.bestStreak, 0, "Fresh store has no completed sessions → best streak 0")
        XCTAssertEqual(store.todayFocusMinutes(), 0)
        XCTAssertEqual(store.todayGoalProgress(), 0, accuracy: 1e-9, "No focus today → progress 0")
        XCTAssertFalse(store.isTodayGoalMet())
    }

    func testSingleTodaySessionMakesStreakOne() {
        let store = makeStore()
        completeOneSessionToday(store, durationSeconds: 1500) // 25 min, lands today
        XCTAssertEqual(store.history.count, 1)
        XCTAssertEqual(store.currentStreak, 1, "One completed session today → current streak 1")
        XCTAssertEqual(store.bestStreak, 1, "Best streak is at least the single active day")
        store.cancel()
    }

    func testTodayGoalProgressIsClampedToUnitInterval() {
        let store = makeStore()
        // Goal floor is 15 min (dailyGoalRange.lowerBound). Complete a session
        // far exceeding it so raw progress would be >1, then assert the clamp.
        store.dailyGoalMinutes = SessionStore.dailyGoalRange.lowerBound // 15 min
        completeOneSessionToday(store, durationSeconds: 60 * 60) // 60 focus minutes today

        let progress = store.todayGoalProgress()
        XCTAssertGreaterThanOrEqual(progress, 0.0)
        XCTAssertLessThanOrEqual(progress, 1.0, "todayGoalProgress() must clamp to 0...1 even when minutes exceed goal")
        XCTAssertEqual(progress, 1.0, accuracy: 1e-9, "60 min focused against a 15 min goal must clamp to exactly 1.0")
        XCTAssertTrue(store.isTodayGoalMet(), "Goal must read as met when focus minutes ≥ goal")
        store.cancel()
    }

    func testDailyGoalMinutesClampsToRange() {
        let store = makeStore()
        store.dailyGoalMinutes = 9999
        XCTAssertEqual(store.dailyGoalMinutes, SessionStore.dailyGoalRange.upperBound,
                       "Over-max goal must clamp to the range upper bound")
        store.dailyGoalMinutes = 1
        XCTAssertEqual(store.dailyGoalMinutes, SessionStore.dailyGoalRange.lowerBound,
                       "Below-min goal must clamp to the range lower bound")
    }

    // MARK: - Premium-technique free trial (bypass-proof, one-time)

    func testTrialAvailableForFreshFreeUser() {
        let store = makeStore()
        XCTAssertFalse(store.usedPremiumTechniqueTrial, "Fresh store has an unspent trial")
        XCTAssertTrue(store.premiumTrialAvailable(isPremium: false),
                      "A free user who hasn't spent the trial is eligible")
    }

    func testTrialNeverOfferedToPremiumUsers() {
        let store = makeStore()
        // Even with an unspent flag, a premium user never sees the trial — they
        // already own every technique.
        XCTAssertFalse(store.premiumTrialAvailable(isPremium: true),
                       "Premium users are never offered the trial")
    }

    func testConsumingTrialMakesItUnavailableAndIsBypassProof() {
        let store = makeStore()
        store.consumePremiumTechniqueTrial()
        XCTAssertTrue(store.usedPremiumTechniqueTrial, "Consuming sets the flag")
        XCTAssertFalse(store.premiumTrialAvailable(isPremium: false),
                       "Once spent, a free user is no longer eligible — no bypass loop")
        // Calling consume again is idempotent (no resurrection, no crash).
        store.consumePremiumTechniqueTrial()
        XCTAssertTrue(store.usedPremiumTechniqueTrial)
        XCTAssertFalse(store.premiumTrialAvailable(isPremium: false))
    }

    func testTrialFlagPersistsAcrossStoreInstances() {
        // Burn the trial, then build a NEW store from the same UserDefaults
        // (no clear) — the spent state must survive an app relaunch, otherwise
        // the trial could be re-taken by killing the app (a bypass loop).
        let first = makeStore()
        first.consumePremiumTechniqueTrial()

        let reopened = SessionStore()   // reads persisted flag, no key removal
        XCTAssertTrue(reopened.usedPremiumTechniqueTrial,
                      "Spent trial must persist across launches")
        XCTAssertFalse(reopened.premiumTrialAvailable(isPremium: false),
                       "A relaunch must not resurrect the one-time trial")

        // Cleanup so the persisted flag doesn't leak into other tests.
        UserDefaults.standard.removeObject(forKey: "focusflow.premiumTechniqueTrialUsed.v1")
    }
}
