import CoreGraphics
import Foundation

/// One short-lived activity timestamp and fallback position, not a key history.
/// Mouse movement and modifier/source changes never extend this interval.
public struct TypingActivityTracker {
    public let idleInterval: TimeInterval
    private var lastTypingTime: TimeInterval?
    public private(set) var fallbackPosition: CGPoint?

    public init(idleInterval: TimeInterval = 2) {
        self.idleInterval = idleInterval
    }

    public mutating func recordTyping(at time: TimeInterval, pointer: CGPoint) {
        guard time.isFinite, pointer.x.isFinite, pointer.y.isFinite else { return }
        lastTypingTime = time
        fallbackPosition = pointer
    }

    public func isActive(at time: TimeInterval) -> Bool {
        guard let lastTypingTime, time.isFinite, time >= lastTypingTime else { return false }
        return time - lastTypingTime < idleInterval
    }

    public mutating func reset() {
        lastTypingTime = nil
        fallbackPosition = nil
    }
}
