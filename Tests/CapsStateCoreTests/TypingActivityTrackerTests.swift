import CoreGraphics
import XCTest
@testable import CapsStateCore

final class TypingActivityTrackerTests: XCTestCase {
    func testLaunchIsHiddenUntilTypingOccurs() {
        let tracker = TypingActivityTracker()
        XCTAssertFalse(tracker.isActive(at: 0))
        XCTAssertFalse(tracker.isActive(at: 100))
        XCTAssertNil(tracker.fallbackPosition)
    }

    func testTypingShowsImmediatelyAndHidesAtTwoSeconds() {
        var tracker = TypingActivityTracker()
        tracker.recordTyping(at: 10, pointer: CGPoint(x: 30, y: 40))
        XCTAssertTrue(tracker.isActive(at: 10))
        XCTAssertTrue(tracker.isActive(at: 11.99))
        XCTAssertFalse(tracker.isActive(at: 12))
        XCTAssertFalse(tracker.isActive(at: 100))
    }

    func testMoreTypingExtendsDeadlineAndCanWakeAfterIdle() {
        var tracker = TypingActivityTracker()
        tracker.recordTyping(at: 0, pointer: .zero)
        tracker.recordTyping(at: 1.5, pointer: .zero)
        XCTAssertTrue(tracker.isActive(at: 3))
        XCTAssertFalse(tracker.isActive(at: 3.5))
        tracker.recordTyping(at: 20, pointer: .zero)
        XCTAssertTrue(tracker.isActive(at: 20))
        XCTAssertFalse(tracker.isActive(at: 22))
    }

    func testPositionAndDeadlineDoNotChangeWithoutNewTyping() {
        var tracker = TypingActivityTracker()
        let original = CGPoint(x: 100, y: 200)
        tracker.recordTyping(at: 10, pointer: original)
        for time in [10.1, 10.5, 11, 11.9] {
            XCTAssertTrue(tracker.isActive(at: time))
            XCTAssertEqual(tracker.fallbackPosition, original)
        }
        XCTAssertFalse(tracker.isActive(at: 12))
        let next = CGPoint(x: 900, y: 800)
        tracker.recordTyping(at: 15, pointer: next)
        XCTAssertEqual(tracker.fallbackPosition, next)
    }

    func testResetClearsActivityAndPointerForAppSwitchSleepOrDisable() {
        var tracker = TypingActivityTracker()
        tracker.recordTyping(at: 10, pointer: CGPoint(x: 100, y: 200))
        tracker.reset()
        XCTAssertFalse(tracker.isActive(at: 10.1))
        XCTAssertNil(tracker.fallbackPosition)
        tracker.recordTyping(at: 20, pointer: .zero)
        XCTAssertTrue(tracker.isActive(at: 20))
    }

    func testInvalidOrBackwardTimeCannotShowAnIdleBadge() {
        var tracker = TypingActivityTracker()
        tracker.recordTyping(at: .nan, pointer: .zero)
        XCTAssertFalse(tracker.isActive(at: 10))
        tracker.recordTyping(at: 10, pointer: .zero)
        XCTAssertFalse(tracker.isActive(at: 9))
        XCTAssertFalse(tracker.isActive(at: .nan))
        XCTAssertFalse(tracker.isActive(at: .infinity))
    }
}
