import Foundation

/// Aggregate activity only: no key identity, characters, text, or event objects.
public struct TypingActivitySample: Sendable {
    public let keyDownCount: UInt32
    public let modifierChangeCount: UInt32
    public let secondsSinceKeyDown: TimeInterval
    public let shortcutHeld: Bool

    public init(keyDownCount: UInt32, modifierChangeCount: UInt32,
                secondsSinceKeyDown: TimeInterval, shortcutHeld: Bool) {
        self.keyDownCount = keyDownCount
        self.modifierChangeCount = modifierChangeCount
        self.secondsSinceKeyDown = secondsSinceKeyDown
        self.shortcutHeld = shortcutHeld
    }
}

/// Recovers activity when an AppKit monitor exists but stops delivering events.
/// Permission, secure-input, menu and focus gates are owned by the caller.
public struct TypingActivityFallback {
    private var previous: TypingActivitySample?
    public init() {}

    public mutating func reset() { previous = nil }

    public mutating func observe(_ sample: TypingActivitySample) -> Bool {
        defer { previous = sample }
        guard let previous,
              sample.keyDownCount != previous.keyDownCount,
              sample.secondsSinceKeyDown.isFinite,
              sample.secondsSinceKeyDown >= 0,
              sample.secondsSinceKeyDown <= 0.25,
              !sample.shortcutHeld, !previous.shortcutHeld,
              // A shortcut can be pressed AND released between polls. Reject
              // that ambiguous interval even when the current flags are clear.
              sample.modifierChangeCount == previous.modifierChangeCount else {
            return false
        }
        return true
    }
}
