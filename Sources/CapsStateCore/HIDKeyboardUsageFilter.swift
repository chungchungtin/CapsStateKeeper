public enum MonitoredKeyboardSignal: Equatable, Sendable {
    case control(isPressed: Bool)
    case space(isPressed: Bool)
}

public enum HIDKeyboardUsageFilter {
    public static func signal(
        usage: UInt32,
        value: Int64,
        isArray: Bool = false
    ) -> MonitoredKeyboardSignal? {
        switch usage {
        case 0xE0, 0xE4:
            return .control(isPressed: value != 0)
        case 0x2C:
            return .space(isPressed: value != 0)
        default:
            // Boot-protocol keyboards, including the Keychron K10 Max in
            // Bluetooth mode, expose ordinary keys through array elements.
            // The element usage is generic and the key usage is the value.
            guard isArray, value == 0x2C else { return nil }
            return .space(isPressed: true)
        }
    }
}

public enum HIDCapsLockUsageFilter {
    public static func isPress(
        usage: UInt32,
        value: Int64,
        isArray: Bool = false
    ) -> Bool {
        if isArray {
            return value == 0x39
        }
        return usage == 0x39 && value != 0
    }
}
