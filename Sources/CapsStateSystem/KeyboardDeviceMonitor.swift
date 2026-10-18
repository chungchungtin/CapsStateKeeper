import CapsStateCore
import Foundation
import IOKit
import IOKit.hid
import IOKit.hidsystem

public enum KeyboardDeviceMonitorError: Error {
    case inputMonitoringNotGranted
    case openFailed(IOReturn)
}

public final class KeyboardDeviceMonitor {
    private let manager: IOHIDManager
    private let capsLockDidChange: @Sendable () -> Void
    private let lock = NSLock()
    private var tracker = KeyboardSwitchTracker()
    private var keyboardsByID: [UInt64: KeyboardDescriptor] = [:]

    public static func hasInputMonitoringAccess() -> Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) ==
            kIOHIDAccessTypeGranted
    }

    @discardableResult
    public static func requestInputMonitoringAccess() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    public init(
        capsLockDidChange: @escaping @Sendable () -> Void = {}
    ) throws {
        guard Self.hasInputMonitoringAccess() else {
            throw KeyboardDeviceMonitorError.inputMonitoringNotGranted
        }

        self.capsLockDidChange = capsLockDidChange
        manager = IOHIDManagerCreate(
            kCFAllocatorDefault,
            IOOptionBits(kIOHIDOptionsTypeNone)
        )

        let keyboardMatch: [String: Any] = [
            kIOHIDDeviceUsagePageKey: 0x01,
            kIOHIDDeviceUsageKey: 0x06,
        ]
        IOHIDManagerSetDeviceMatching(
            manager,
            keyboardMatch as CFDictionary
        )

        // Boot-protocol keyboards encode ordinary keys in array elements, so
        // Space cannot be selected at the IOHID subscription boundary. Receive
        // keyboard-page values, then immediately reject every non-approved
        // usage in HIDKeyboardUsageFilter before recording any state.
        let inputMatches: [[String: Any]] = [[
            kIOHIDElementUsagePageKey: 0x07,
        ]]
        IOHIDManagerSetInputValueMatchingMultiple(
            manager,
            inputMatches as CFArray
        )

        IOHIDManagerRegisterInputValueCallback(
            manager,
            Self.inputValueCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        IOHIDManagerScheduleWithRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.commonModes.rawValue
        )

        let result = IOHIDManagerOpen(
            manager,
            IOOptionBits(kIOHIDOptionsTypeNone)
        )
        guard result == kIOReturnSuccess else {
            IOHIDManagerUnscheduleFromRunLoop(
                manager,
                CFRunLoopGetMain(),
                CFRunLoopMode.commonModes.rawValue
            )
            throw KeyboardDeviceMonitorError.openFailed(result)
        }
    }

    public func recentSwitchKeyboard(
        maximumAge: TimeInterval = 1.0
    ) -> KeyboardDescriptor? {
        lock.withLock {
            guard let deviceID = tracker.recentSwitchDeviceID(
                at: ProcessInfo.processInfo.systemUptime,
                maximumAge: maximumAge
            ) else {
                return nil
            }
            return keyboardsByID[deviceID]
        }
    }

    deinit {
        IOHIDManagerUnscheduleFromRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.commonModes.rawValue
        )
        IOHIDManagerClose(
            manager,
            IOOptionBits(kIOHIDOptionsTypeNone)
        )
    }

    private static let inputValueCallback: IOHIDValueCallback = {
        context,
        result,
        sender,
        value in
        guard result == kIOReturnSuccess,
              let context else {
            return
        }
        Unmanaged<KeyboardDeviceMonitor>
            .fromOpaque(context)
            .takeUnretainedValue()
            .handle(value)
    }

    private func handle(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        guard IOHIDElementGetUsagePage(element) == 0x07 else {
            return
        }
        let usage = IOHIDElementGetUsage(element)
        let rawValue = Int64(IOHIDValueGetIntegerValue(value))
        let isArray = IOHIDElementIsArray(element)
        if HIDCapsLockUsageFilter.isPress(
            usage: usage,
            value: rawValue,
            isArray: isArray
        ) {
            capsLockDidChange()
            return
        }
        guard let signal = HIDKeyboardUsageFilter.signal(
            usage: usage,
            value: rawValue,
            isArray: isArray
        ) else {
            return
        }
        let device = IOHIDElementGetDevice(element)
        guard let descriptor = descriptor(for: device) else {
            return
        }

        lock.withLock {
            keyboardsByID[descriptor.deviceID] = descriptor
        }
        let key: TrackedKeyboardKey
        let isPressed: Bool
        switch signal {
        case let .control(pressed):
            key = .control
            isPressed = pressed
        case let .space(pressed):
            key = .space
            isPressed = pressed
        }

        let event = TrackedKeyboardEvent(
            deviceID: descriptor.deviceID,
            key: key,
            isPressed: isPressed,
            timestamp: ProcessInfo.processInfo.systemUptime
        )
        lock.withLock {
            tracker.handle(event)
        }
    }

    private func descriptor(
        for device: IOHIDDevice
    ) -> KeyboardDescriptor? {
        let service = IOHIDDeviceGetService(device)
        var registryID: UInt64 = 0
        guard service != 0,
              IORegistryEntryGetRegistryEntryID(
                service,
                &registryID
              ) == KERN_SUCCESS else {
            return nil
        }

        let product = IOHIDDeviceGetProperty(
            device,
            kIOHIDProductKey as CFString
        ) as? String ?? "unknown"
        let vendor = IOHIDDeviceGetProperty(
            device,
            kIOHIDVendorIDKey as CFString
        ) as? NSNumber ?? 0
        let productID = IOHIDDeviceGetProperty(
            device,
            kIOHIDProductIDKey as CFString
        ) as? NSNumber ?? 0

        return KeyboardDescriptor(
            deviceID: registryID,
            product: product,
            vendorID: vendor.intValue,
            productID: productID.intValue
        )
    }
}
