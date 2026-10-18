import AppKit
import XCTest
@testable import CapsStateSystem

final class HIDCapsLockControllerTests: XCTestCase {
    func testControllerCanReadCurrentLockState() throws {
        guard ProcessInfo.processInfo.environment["CAPS_STATE_KEEPER_INTEGRATION"] == "1" else {
            throw XCTSkip("Set CAPS_STATE_KEEPER_INTEGRATION=1 to run the HID integration test")
        }

        let controller = try HIDCapsLockController()
        _ = try controller.currentLockState()
    }

    func testSystemReaderReturnsAUsableSnapshot() throws {
        guard ProcessInfo.processInfo.environment["CAPS_STATE_KEEPER_INTEGRATION"] == "1" else {
            throw XCTSkip("Set CAPS_STATE_KEEPER_INTEGRATION=1 to run the HID integration test")
        }

        let reader = SystemCapsStateReader()
        let snapshot = try reader.snapshot()

        XCTAssertFalse(snapshot.sourceID.isEmpty)
    }
}
