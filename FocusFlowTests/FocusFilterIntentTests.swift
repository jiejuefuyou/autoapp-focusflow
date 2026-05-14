import XCTest
import AppIntents
@testable import FocusFlow

/// Verifies that `FocusBlockFilterIntent.perform()` correctly writes all four
/// preferences to the App Group `UserDefaults` suite and stamps a recent
/// `lastActivated` timestamp.
///
/// These tests run in the FocusFlowTests host-app bundle which shares the same
/// App Group identifier. In CI (macos-15 fastlane), the simulator is entitled
/// to the group via the test-host entitlement inherited from the main target.
final class FocusFilterIntentTests: XCTestCase {

    private let groupID = FocusFilterKeys.groupID
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: groupID)
        // Wipe any leftover state from previous runs.
        defaults?.removeObject(forKey: FocusFilterKeys.autoStart)
        defaults?.removeObject(forKey: FocusFilterKeys.sessionMinutes)
        defaults?.removeObject(forKey: FocusFilterKeys.projectTag)
        defaults?.removeObject(forKey: FocusFilterKeys.hideNotifications)
        defaults?.removeObject(forKey: FocusFilterKeys.lastActivated)
    }

    // MARK: - Core write test

    func testIntentStoresAllPreferencesInAppGroup() async throws {
        var intent = FocusBlockFilterIntent()
        intent.sessionMinutes   = 25
        intent.autoStart        = true
        intent.projectTag       = "Deep Work"
        intent.hideNotifications = true

        _ = try await intent.perform()

        XCTAssertEqual(defaults?.integer(forKey: FocusFilterKeys.sessionMinutes), 25)
        XCTAssertTrue(defaults?.bool(forKey: FocusFilterKeys.autoStart) ?? false)
        XCTAssertEqual(defaults?.string(forKey: FocusFilterKeys.projectTag), "Deep Work")
        XCTAssertTrue(defaults?.bool(forKey: FocusFilterKeys.hideNotifications) ?? false)

        let timestamp = defaults?.double(forKey: FocusFilterKeys.lastActivated) ?? 0
        XCTAssertGreaterThan(timestamp, Date().timeIntervalSince1970 - 5,
            "lastActivated must be within the last 5 seconds")
    }

    // MARK: - Auto-start disabled

    func testAutoStartFalseIsStored() async throws {
        var intent = FocusBlockFilterIntent()
        intent.sessionMinutes    = 50
        intent.autoStart         = false
        intent.projectTag        = nil
        intent.hideNotifications = false

        _ = try await intent.perform()

        XCTAssertFalse(defaults?.bool(forKey: FocusFilterKeys.autoStart) ?? true)
        XCTAssertEqual(defaults?.integer(forKey: FocusFilterKeys.sessionMinutes), 50)
        XCTAssertNil(defaults?.string(forKey: FocusFilterKeys.projectTag))
    }

    // MARK: - Nil project tag

    func testNilProjectTagStoresNilNotEmptyString() async throws {
        var intent = FocusBlockFilterIntent()
        intent.sessionMinutes    = 25
        intent.autoStart         = true
        intent.projectTag        = nil
        intent.hideNotifications = true

        _ = try await intent.perform()

        // A nil Optional<String> stored via `defaults?.set(nil, forKey:)` is
        // effectively removed from the suite; reading it back returns nil.
        XCTAssertNil(defaults?.string(forKey: FocusFilterKeys.projectTag))
    }

    // MARK: - Timestamp freshness

    func testTimestampIsWrittenWithinOneSecondOfPerform() async throws {
        let before = Date().timeIntervalSince1970

        var intent = FocusBlockFilterIntent()
        intent.sessionMinutes    = 25
        intent.autoStart         = true
        intent.projectTag        = nil
        intent.hideNotifications = false

        _ = try await intent.perform()

        let after = Date().timeIntervalSince1970
        let stored = defaults?.double(forKey: FocusFilterKeys.lastActivated) ?? 0
        XCTAssertGreaterThanOrEqual(stored, before)
        XCTAssertLessThanOrEqual(stored, after + 1)
    }

    // MARK: - Key constant namespace sanity

    func testFocusFilterKeysAreDistinct() {
        let keys = [
            FocusFilterKeys.autoStart,
            FocusFilterKeys.sessionMinutes,
            FocusFilterKeys.projectTag,
            FocusFilterKeys.hideNotifications,
            FocusFilterKeys.lastActivated,
        ]
        XCTAssertEqual(Set(keys).count, keys.count, "All FocusFilterKeys must be unique strings")
    }
}
