import XCTest

/// fastlane snapshot driver. -FASTLANE_SNAPSHOT makes the app skip onboarding
/// (FocusFlowApp.init) and seed an in-progress session + 7 days of history
/// (SessionStore.injectSnapshotData), so every shot shows the app in use
/// (Apple 2.3.3 / lesson #44 — this app was rejected for non-real shots).
///
/// Navigation is positional (toolbar button indices) + guarded so it works in
/// all 8 capture languages; sheets close with a language-independent swipe.
final class FocusFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor
    func testScreenshots() {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-FASTLANE_SNAPSHOT", "YES", "-ui_testing"]
        app.launch()
        sleep(2)

        // 1) Hero: timer mid-session (ring ~60% filled, seeded).
        snapshot("01-Timer")

        let navBar = app.navigationBars.firstMatch
        _ = navBar.waitForExistence(timeout: 5)

        // Toolbar layout: [0] Settings (leading), [1] Analytics, [2] Pro
        // (trailing; Pro present because the sandbox user is never premium).
        // 2) Weekly analytics (seeded history populates the charts).
        if navBar.buttons.count >= 2 {
            navBar.buttons.element(boundBy: 1).tap()
            sleep(2)
            snapshot("02-Analytics")
            app.swipeDown(velocity: .fast)
            sleep(1)
        }

        // 3) Technique presets — scroll the main screen so the picker fills it.
        app.swipeUp()
        sleep(1)
        snapshot("03-Presets")
        app.swipeDown()
        sleep(1)

        // 4) Settings sheet.
        if navBar.buttons.count >= 1 {
            navBar.buttons.element(boundBy: 0).tap()
            sleep(2)
            snapshot("04-Settings")
            app.swipeDown(velocity: .fast)
            sleep(1)
        }

        // 5) Paywall via the trailing Pro button.
        if navBar.buttons.count >= 3 {
            navBar.buttons.element(boundBy: 2).tap()
            sleep(2)
            snapshot("05-Paywall")
        }
    }
}
