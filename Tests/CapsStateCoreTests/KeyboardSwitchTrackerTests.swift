import XCTest
@testable import CapsStateCore

final class KeyboardSwitchTrackerTests: XCTestCase {
    func testControlSpaceFromSameKeyboardRecordsThatKeyboard() {
        var tracker = KeyboardSwitchTracker()

        tracker.handle(.init(
            deviceID: 42,
            key: .control,
            isPressed: true,
            timestamp: 10.0
        ))
        tracker.handle(.init(
            deviceID: 42,
            key: .space,
            isPressed: true,
            timestamp: 10.1
        ))

        XCTAssertEqual(
            tracker.recentSwitchDeviceID(at: 10.2, maximumAge: 1.0),
            42
        )
    }

    func testControlAndSpaceFromDifferentKeyboardsDoNotSelectEitherKeyboard() {
        var tracker = KeyboardSwitchTracker()

        tracker.handle(.init(
            deviceID: 1,
            key: .control,
            isPressed: true,
            timestamp: 20.0
        ))
        tracker.handle(.init(
            deviceID: 2,
            key: .space,
            isPressed: true,
            timestamp: 20.1
        ))

        XCTAssertNil(
            tracker.recentSwitchDeviceID(at: 20.2, maximumAge: 1.0)
        )
    }

    func testReleasedControlDoesNotQualifyLaterSpacePress() {
        var tracker = KeyboardSwitchTracker()

        tracker.handle(.init(
            deviceID: 7,
            key: .control,
            isPressed: true,
            timestamp: 30.0
        ))
        tracker.handle(.init(
            deviceID: 7,
            key: .control,
            isPressed: false,
            timestamp: 30.1
        ))
        tracker.handle(.init(
            deviceID: 7,
            key: .space,
            isPressed: true,
            timestamp: 30.2
        ))

        XCTAssertNil(
            tracker.recentSwitchDeviceID(at: 30.3, maximumAge: 1.0)
        )
    }

    func testOldSwitchDeviceExpiresInsteadOfBeingGuessed() {
        var tracker = KeyboardSwitchTracker()

        tracker.handle(.init(
            deviceID: 9,
            key: .control,
            isPressed: true,
            timestamp: 40.0
        ))
        tracker.handle(.init(
            deviceID: 9,
            key: .space,
            isPressed: true,
            timestamp: 40.1
        ))

        XCTAssertNil(
            tracker.recentSwitchDeviceID(at: 42.0, maximumAge: 1.0)
        )
    }
}
