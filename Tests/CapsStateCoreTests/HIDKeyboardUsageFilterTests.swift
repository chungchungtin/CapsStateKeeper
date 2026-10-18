import XCTest
@testable import CapsStateCore

final class HIDKeyboardUsageFilterTests: XCTestCase {
    func testVariableControlAndSpaceElementsAreAccepted() {
        XCTAssertEqual(
            HIDKeyboardUsageFilter.signal(usage: 0xE0, value: 1),
            .control(isPressed: true)
        )
        XCTAssertEqual(
            HIDKeyboardUsageFilter.signal(usage: 0xE4, value: 0),
            .control(isPressed: false)
        )
        XCTAssertEqual(
            HIDKeyboardUsageFilter.signal(usage: 0x2C, value: 1),
            .space(isPressed: true)
        )
    }

    func testKeychronArraySpaceValueIsAccepted() {
        XCTAssertEqual(
            HIDKeyboardUsageFilter.signal(
                usage: UInt32.max,
                value: 0x2C,
                isArray: true
            ),
            .space(isPressed: true)
        )
    }

    func testCapsLockRemainsRejectedFromKeyboardSwitchTracking() {
        XCTAssertNil(HIDKeyboardUsageFilter.signal(
            usage: 0x39,
            value: 1,
            isArray: false
        ))
        XCTAssertNil(HIDKeyboardUsageFilter.signal(
            usage: UInt32.max,
            value: 0x39,
            isArray: true
        ))
    }

    func testCapsLockPressIsRecognizedForIndicatorRefresh() {
        XCTAssertTrue(HIDCapsLockUsageFilter.isPress(
            usage: 0x39,
            value: 1
        ))
        XCTAssertTrue(HIDCapsLockUsageFilter.isPress(
            usage: UInt32.max,
            value: 0x39,
            isArray: true
        ))
    }

    func testCapsLockReleaseAndOtherKeysDoNotRefreshIndicator() {
        XCTAssertFalse(HIDCapsLockUsageFilter.isPress(
            usage: 0x39,
            value: 0
        ))
        XCTAssertFalse(HIDCapsLockUsageFilter.isPress(
            usage: UInt32.max,
            value: 0,
            isArray: true
        ))
        XCTAssertFalse(HIDCapsLockUsageFilter.isPress(
            usage: 0x04,
            value: 1
        ))
    }

    func testLettersNumbersAndOtherArrayValuesAreImmediatelyRejected() {
        for value in [0x04, 0x05, 0x1E, 0x1F, 0x28, 0x2D] {
            XCTAssertNil(HIDKeyboardUsageFilter.signal(
                usage: UInt32.max,
                value: Int64(value),
                isArray: true
            ))
        }
        XCTAssertNil(HIDKeyboardUsageFilter.signal(usage: 0x04, value: 1))
        XCTAssertNil(HIDKeyboardUsageFilter.signal(
            usage: UInt32.max,
            value: 0,
            isArray: true
        ))
        XCTAssertNil(HIDKeyboardUsageFilter.signal(
            usage: 0x99,
            value: 0x2C,
            isArray: false
        ))
    }
}
