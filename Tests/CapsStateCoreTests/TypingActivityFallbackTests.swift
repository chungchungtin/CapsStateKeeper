import XCTest
@testable import CapsStateCore

final class TypingActivityFallbackTests: XCTestCase {
    private func sample(_ count: UInt32, modifiers: UInt32 = 0,
                        age: Double = 0.01, shortcut: Bool = false) -> TypingActivitySample {
        TypingActivitySample(keyDownCount: count, modifierChangeCount: modifiers,
                             secondsSinceKeyDown: age, shortcutHeld: shortcut)
    }

    func testStartupDoesNotReplayTypingBeforeLaunch() {
        var fallback = TypingActivityFallback()
        XCTAssertFalse(fallback.observe(sample(500)))
        XCTAssertTrue(fallback.observe(sample(501)))
    }

    func testLostMonitorStillWakesIndicatorAndHidesTwoSecondsAfterLastKey() {
        var fallback = TypingActivityFallback()
        var activity = TypingActivityTracker()
        let pointer = CGPoint(x: 200, y: 300)
        XCTAssertFalse(fallback.observe(sample(10)))
        // No monitor callbacks at all. Hardware key-down activity is enough.
        for index in 1...60 {
            let now = Double(index) * 0.05
            if fallback.observe(sample(UInt32(10 + index))) {
                activity.recordTyping(at: now - 0.01, pointer: pointer)
            }
            XCTAssertTrue(activity.isActive(at: now))
        }
        XCTAssertFalse(fallback.observe(sample(70, age: 1.9)))
        XCTAssertTrue(activity.isActive(at: 4.98))
        XCTAssertFalse(activity.isActive(at: 5.0))
        XCTAssertEqual(activity.fallbackPosition, pointer)
    }

    func testPollingSameEventNeverExtendsActivityOrMovesPointer() {
        var fallback = TypingActivityFallback()
        var activity = TypingActivityTracker()
        _ = fallback.observe(sample(20))
        XCTAssertTrue(fallback.observe(sample(21)))
        activity.recordTyping(at: 10, pointer: CGPoint(x: 4, y: 5))
        for index in 1...50 {
            // Mouse activity is deliberately absent from this signal.
            XCTAssertFalse(fallback.observe(sample(21, age: Double(index) * 0.05)))
        }
        XCTAssertFalse(activity.isActive(at: 12.5))
        XCTAssertEqual(activity.fallbackPosition, CGPoint(x: 4, y: 5))
    }

    func testHeldShortcutAndReleaseCannotWakeIndicator() {
        var fallback = TypingActivityFallback()
        _ = fallback.observe(sample(1))
        XCTAssertFalse(fallback.observe(sample(2, modifiers: 1, shortcut: true)))
        XCTAssertFalse(fallback.observe(sample(3, modifiers: 1, shortcut: true)))
        XCTAssertFalse(fallback.observe(sample(3, modifiers: 2)))
        XCTAssertTrue(fallback.observe(sample(4, modifiers: 2)))
    }

    func testShortcutPressedAndReleasedBetweenPollsIsRejected() {
        var fallback = TypingActivityFallback()
        _ = fallback.observe(sample(1))
        // Both samples have clear flags, but a modifier transition took place.
        XCTAssertFalse(fallback.observe(sample(2, modifiers: 2)))
        XCTAssertTrue(fallback.observe(sample(3, modifiers: 2)))
    }

    func testShiftOrOptionTypingWorksOnceModifierStateIsStable() {
        var fallback = TypingActivityFallback()
        _ = fallback.observe(sample(1))
        // Conservatively skip the ambiguous modifier-transition interval.
        XCTAssertFalse(fallback.observe(sample(2, modifiers: 1)))
        XCTAssertTrue(fallback.observe(sample(3, modifiers: 1)))
    }

    func testModifierOnlyChangesDoNotWake() {
        var fallback = TypingActivityFallback()
        _ = fallback.observe(sample(2))
        XCTAssertFalse(fallback.observe(sample(2, modifiers: 1)))
        XCTAssertFalse(fallback.observe(sample(2, modifiers: 2)))
    }

    func testOldKeyEventIsNotReplayedAfterStall() {
        var fallback = TypingActivityFallback()
        _ = fallback.observe(sample(1))
        XCTAssertFalse(fallback.observe(sample(8, age: 3)))
        XCTAssertTrue(fallback.observe(sample(9)))
    }

    func testInvalidAgesAreRejected() {
        for age in [Double.nan, Double.infinity, -0.1, 0.251] {
            var fallback = TypingActivityFallback()
            _ = fallback.observe(sample(1))
            XCTAssertFalse(fallback.observe(sample(2, age: age)))
        }
    }

    func testResetForSleepMenuFocusOrPermissionPreventsReplay() {
        var fallback = TypingActivityFallback()
        _ = fallback.observe(sample(1))
        XCTAssertTrue(fallback.observe(sample(2)))
        fallback.reset()
        XCTAssertFalse(fallback.observe(sample(20)))
        XCTAssertTrue(fallback.observe(sample(21)))
    }

    func testCounterWrapStillDetectsFreshActivity() {
        var fallback = TypingActivityFallback()
        _ = fallback.observe(sample(UInt32.max))
        XCTAssertTrue(fallback.observe(sample(0)))
    }
}
