import XCTest
@testable import CapsStateCore

final class CapsStatePolicyTests: XCTestCase {
    func testReturningToABCRequestsImmediateRestoreWhenEventFlagLagsHIDState() {
        let policy = CapsStatePolicy(latinSourceIDs: ["com.apple.keylayout.ABC"])
        let snapshot = CapsStateSnapshot(
            sourceID: "com.apple.keylayout.ABC",
            eventCapsLock: false,
            hidCapsLock: true
        )

        XCTAssertEqual(policy.action(for: snapshot), .setCapsLock(true))
    }

    func testDoesNotWriteOffStateForTheReverseMismatch() {
        let policy = CapsStatePolicy(latinSourceIDs: ["com.apple.keylayout.ABC"])
        let snapshot = CapsStateSnapshot(
            sourceID: "com.apple.keylayout.ABC",
            eventCapsLock: true,
            hidCapsLock: false
        )

        XCTAssertNil(policy.action(for: snapshot))
    }

    func testDoesNothingWhenABCStateAlreadyMatches() {
        let policy = CapsStatePolicy(latinSourceIDs: ["com.apple.keylayout.ABC"])

        XCTAssertNil(policy.action(for: CapsStateSnapshot(
            sourceID: "com.apple.keylayout.ABC",
            eventCapsLock: false,
            hidCapsLock: false
        )))
        XCTAssertNil(policy.action(for: CapsStateSnapshot(
            sourceID: "com.apple.keylayout.ABC",
            eventCapsLock: true,
            hidCapsLock: true
        )))
    }

    func testDoesNothingWhileTraditionalChineseInputSourceIsActive() {
        let policy = CapsStatePolicy(latinSourceIDs: ["com.apple.keylayout.ABC"])
        let snapshot = CapsStateSnapshot(
            sourceID: "com.apple.inputmethod.TCIM.Zhuyin",
            eventCapsLock: false,
            hidCapsLock: true
        )

        XCTAssertNil(policy.action(for: snapshot))
    }

    func testDoesNothingWhenMultipleKeyboardCachesConflictAndNoDeviceWasIdentified() {
        let policy = CapsStatePolicy(latinSourceIDs: ["com.apple.keylayout.ABC"])
        let snapshot = CapsStateSnapshot(
            sourceID: "com.apple.keylayout.ABC",
            eventCapsLock: false,
            hidCapsLock: nil
        )

        XCTAssertNil(policy.action(for: snapshot))
    }
}
