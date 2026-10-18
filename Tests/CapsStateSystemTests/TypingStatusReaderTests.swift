import AppKit
import Carbon.HIToolbox
import XCTest
@testable import CapsStateSystem

final class TypingStatusReaderTests: XCTestCase {
    @MainActor
    func testMousePollingCannotOverrideLastKeyboardEvent() {
        var hardwareFlags: CGEventFlags = .maskAlphaShift
        let reader = TypingStatusReader(readFlags: { _ in hardwareFlags }, now: { 0 })
        reader.observeKeyboardModifiers(capsLock: false, shift: false)
        for flags: CGEventFlags in [[], .maskAlphaShift, [.maskAlphaShift, .maskShift], []] {
            hardwareFlags = flags
            XCTAssertFalse(reader.snapshot().capsLock)
            XCTAssertFalse(reader.snapshot().shift)
        }
        reader.observeKeyboardModifiers(capsLock: true, shift: true)
        XCTAssertTrue(reader.snapshot().capsLock)
        XCTAssertTrue(reader.snapshot().shift)
        reader.observeKeyboardModifiers(capsLock: false, shift: false)
        XCTAssertFalse(reader.snapshot().capsLock)
        XCTAssertFalse(reader.snapshot().shift)
    }

    @MainActor
    func testWakeOrPermissionLossCanReturnToHardwareFallback() {
        var time = 0.0
        let reader = TypingStatusReader(readFlags: { _ in [] }, now: { time })
        reader.observeKeyboardModifiers(capsLock: true, shift: true)
        reader.invalidateKeyboardModifiers()
        _ = reader.snapshot()
        time = 0.2
        XCTAssertFalse(reader.snapshot().capsLock)
        XCTAssertFalse(reader.snapshot().shift)
    }

    @MainActor
    func testDisplayReadsHardwareNotInjectedSessionFlags() {
        var sessionCaps = false
        let reader = TypingStatusReader(readFlags: { table in
            if table == .combinedSessionState {
                return sessionCaps ? .maskAlphaShift : []
            }
            XCTAssertEqual(table, .hidSystemState)
            return []
        }, now: { 0 })
        XCTAssertFalse(reader.snapshot().capsLock)
        sessionCaps = true
        XCTAssertFalse(reader.snapshot().capsLock)
        sessionCaps = false
        XCTAssertFalse(reader.snapshot().capsLock)
    }

    @MainActor
    func testSourceRefreshDoesNotBypassModifierSettling() {
        var flags: CGEventFlags = []
        var time = 0.0
        let reader = TypingStatusReader(readFlags: { _ in flags }, now: { time })
        XCTAssertFalse(reader.snapshot().capsLock)
        flags = .maskAlphaShift
        time = 0.05
        XCTAssertFalse(reader.snapshot().capsLock)
        reader.refreshInputSource()
        time = 0.1
        XCTAssertFalse(reader.snapshot().capsLock)
        time = 0.2
        XCTAssertTrue(reader.snapshot().capsLock)
    }

    @MainActor
    func testUnavailableInputSourceKeepsModifierDisplayUsable() {
        let reader = TypingStatusReader(readFlags: { _ in [] }, now: { 0 })
        reader.refreshInputSource(selected: nil, asciiLayout: nil)
        XCTAssertEqual(reader.snapshot().source.id, "unknown")
        XCTAssertEqual(reader.snapshot().source.displayName, "輸入法")
        for (caps, shift) in [(false, false), (true, false), (false, true), (true, true)] {
            reader.observeKeyboardModifiers(capsLock: caps, shift: shift)
            XCTAssertEqual(reader.snapshot().isUppercase, caps || shift)
        }
    }

    func testUnavailableInputSourceDoesNotBecomeASynchronizationTarget() {
        XCTAssertEqual(SystemCapsStateReader.inputSourceID(nil), "unknown")
    }

    @MainActor
    func testABCLayoutIncludesShiftAndCapsCombinationWithoutChangingInputSource() throws {
        let filter = [kTISPropertyInputSourceID as String: "com.apple.keylayout.ABC"] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue(),
              let sources = list as? [TISInputSource], let source = sources.first else {
            throw XCTSkip("The ABC layout check requires macOS keyboard input services, unavailable in some CI sessions")
        }
        let pointer = try XCTUnwrap(TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData))
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        // macOS ABC keeps letters uppercase with Caps+Shift; XOR would be incorrect.
        for (caps, shift, expected) in [(false, false, false), (true, false, true), (false, true, true), (true, true, true)] {
            XCTAssertEqual(TypingStatusReader.translatedUppercase(layoutData: data, capsLock: caps, shift: shift), expected)
        }
    }
}
