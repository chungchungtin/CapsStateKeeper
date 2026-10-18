import XCTest
@testable import CapsStateCore

final class TypingModifierFilterTests: XCTestCase {
    func testInitialStateIsAvailableImmediately() {
        var filter = TypingModifierFilter()
        let state = filter.update(capsLock: true, shift: false, at: 0)
        XCTAssertTrue(state.capsLock)
        XCTAssertFalse(state.shift)
    }

    func testBriefOppositeCapsSamplesDoNotFlash() {
        var filter = TypingModifierFilter()
        _ = filter.update(capsLock: true, shift: false, at: 0)
        for (time, caps) in [(0.05, false), (0.10, true), (0.15, false), (0.20, true)] {
            XCTAssertTrue(filter.update(capsLock: caps, shift: false, at: time).capsLock)
        }
    }

    func testSustainedOnAndOffChangesBothArrive() {
        var filter = TypingModifierFilter()
        _ = filter.update(capsLock: false, shift: false, at: 0)
        XCTAssertFalse(filter.update(capsLock: true, shift: false, at: 0.1).capsLock)
        XCTAssertTrue(filter.update(capsLock: true, shift: false, at: 0.23).capsLock)
        XCTAssertTrue(filter.update(capsLock: false, shift: false, at: 0.3).capsLock)
        XCTAssertFalse(filter.update(capsLock: false, shift: false, at: 0.43).capsLock)
    }

    func testShiftDoesNotDelayCapsAndReleaseDoesNotStick() {
        var filter = TypingModifierFilter()
        _ = filter.update(capsLock: false, shift: false, at: 0)
        _ = filter.update(capsLock: true, shift: true, at: 0.1)
        XCTAssertTrue(filter.update(capsLock: true, shift: true, at: 0.14).shift)
        _ = filter.update(capsLock: true, shift: false, at: 0.19)
        let result = filter.update(capsLock: true, shift: false, at: 0.24)
        XCTAssertTrue(result.capsLock)
        XCTAssertFalse(result.shift)
    }
}
