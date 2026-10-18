import Foundation

public struct TypingModifiers: Equatable, Sendable {
    public let capsLock: Bool
    public let shift: Bool

    public init(capsLock: Bool, shift: Bool) {
        self.capsLock = capsLock
        self.shift = shift
    }
}

/// Only sustained changes reach the UI. Caps and Shift settle independently so
/// holding/releasing Shift cannot keep resetting a pending Caps change.
public struct TypingModifierFilter {
    private var caps = SettledFlag(interval: 0.12)
    private var shift = SettledFlag(interval: 0.035)

    public init() {}

    public mutating func acceptKeyboardEvent(capsLock: Bool, shift: Bool) {
        caps.accept(capsLock)
        self.shift.accept(shift)
    }

    public mutating func update(capsLock: Bool, shift: Bool, at time: TimeInterval) -> TypingModifiers {
        TypingModifiers(capsLock: caps.update(capsLock, at: time),
                        shift: self.shift.update(shift, at: time))
    }
}

private struct SettledFlag {
    let interval: TimeInterval
    private var value: Bool?
    private var candidate: Bool?
    private var candidateSince: TimeInterval = 0

    init(interval: TimeInterval) { self.interval = interval }

    mutating func accept(_ value: Bool) {
        self.value = value
        candidate = nil
    }

    mutating func update(_ sample: Bool, at time: TimeInterval) -> Bool {
        guard let value else {
            self.value = sample
            return sample
        }
        guard sample != value else {
            candidate = nil
            return value
        }
        if candidate != sample || time < candidateSince {
            candidate = sample
            candidateSince = time
        } else if time - candidateSince >= interval {
            self.value = sample
            candidate = nil
            return sample
        }
        return value
    }
}
