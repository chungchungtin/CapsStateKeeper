import Foundation

public enum TrackedKeyboardKey: Equatable, Sendable {
    case control
    case space
}

public struct TrackedKeyboardEvent: Equatable, Sendable {
    public let deviceID: UInt64
    public let key: TrackedKeyboardKey
    public let isPressed: Bool
    public let timestamp: TimeInterval

    public init(
        deviceID: UInt64,
        key: TrackedKeyboardKey,
        isPressed: Bool,
        timestamp: TimeInterval
    ) {
        self.deviceID = deviceID
        self.key = key
        self.isPressed = isPressed
        self.timestamp = timestamp
    }
}

public struct KeyboardSwitchTracker: Sendable {
    private var devicesWithControlPressed: Set<UInt64> = []
    private var lastSwitchDevice: (id: UInt64, timestamp: TimeInterval)?

    public init() {}

    public mutating func handle(_ event: TrackedKeyboardEvent) {
        switch event.key {
        case .control:
            if event.isPressed {
                devicesWithControlPressed.insert(event.deviceID)
            } else {
                devicesWithControlPressed.remove(event.deviceID)
            }
        case .space:
            guard event.isPressed,
                  devicesWithControlPressed.contains(event.deviceID) else {
                return
            }
            lastSwitchDevice = (event.deviceID, event.timestamp)
        }
    }

    public func recentSwitchDeviceID(
        at timestamp: TimeInterval,
        maximumAge: TimeInterval
    ) -> UInt64? {
        guard let lastSwitchDevice,
              timestamp >= lastSwitchDevice.timestamp,
              timestamp - lastSwitchDevice.timestamp <= maximumAge else {
            return nil
        }
        return lastSwitchDevice.id
    }
}
