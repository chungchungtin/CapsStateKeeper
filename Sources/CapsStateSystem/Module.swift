import AppKit
import CapsStateCore
import Carbon.HIToolbox
import Foundation
import IOKit
import IOKit.hidsystem

public enum HIDCapsLockError: Error {
    case serviceUnavailable
    case openFailed(kern_return_t)
    case readFailed(kern_return_t)
    case writeFailed(kern_return_t)
}

public final class HIDCapsLockController {
    private var connection: io_connect_t = 0

    public init() throws {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching(kIOHIDSystemClass)
        )
        guard service != 0 else {
            throw HIDCapsLockError.serviceUnavailable
        }
        defer { IOObjectRelease(service) }

        let result = IOServiceOpen(
            service,
            mach_task_self_,
            UInt32(kIOHIDParamConnectType),
            &connection
        )
        guard result == KERN_SUCCESS else {
            throw HIDCapsLockError.openFailed(result)
        }
    }

    public func currentLockState() throws -> Bool {
        var state = false
        let result = IOHIDGetModifierLockState(
            connection,
            Int32(kIOHIDCapsLockState),
            &state
        )
        guard result == KERN_SUCCESS else {
            throw HIDCapsLockError.readFailed(result)
        }
        return state
    }

    public func currentTypingEventFlag() -> Bool {
        CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)
    }

    public func setLockState(_ enabled: Bool) throws {
        let result = IOHIDSetModifierLockState(
            connection,
            Int32(kIOHIDCapsLockState),
            enabled
        )
        guard result == KERN_SUCCESS else {
            throw HIDCapsLockError.writeFailed(result)
        }
    }

    /// Restores the ON state observed in the keyboard driver's cache.
    ///
    /// macOS can leave the session event flag OFF while IOHIDSystem already
    /// reports ON. In that split state, an idempotent ON write may be ignored,
    /// so pulse OFF only while the effective typing flag is already OFF, then
    /// finish ON. Callers must gate this to a verified restore-ON mismatch.
    @discardableResult
    public func restoreOnState() throws -> Bool {
        guard !currentTypingEventFlag() else { return false }
        if try currentLockState() {
            try setLockState(false)
        }
        try setLockState(true)
        return true
    }

    deinit {
        if connection != 0 {
            IOServiceClose(connection)
        }
    }
}

public struct SystemCapsStateReader {
    private let cacheReader = KeyboardCapsCacheReader()

    public init() {}

    public func snapshot(
        preferredKeyboard: KeyboardDescriptor? = nil
    ) throws -> CapsStateSnapshot {
        CapsStateSnapshot(
            sourceID: currentInputSourceID(),
            eventCapsLock: CGEventSource.flagsState(.combinedSessionState)
                .contains(.maskAlphaShift),
            hidCapsLock: KeyboardCapsCacheSelector.state(
                from: cacheReader.readAll(),
                preferredKeyboard: preferredKeyboard
            )
        )
    }

    private func currentInputSourceID() -> String {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let pointer = TISGetInputSourceProperty(
            source,
            kTISPropertyInputSourceID
        ) else {
            return "unknown"
        }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }

}
