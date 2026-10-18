import CapsStateCore
import CoreGraphics

public enum TypingActivitySampler {
    /// Read only aggregate counters from the hardware event source, before
    /// application/IME dispatch. Never read a key code or construct an event.
    public static func sample() -> TypingActivitySample {
        let state = CGEventSourceStateID.hidSystemState
        let flags = CGEventSource.flagsState(state)
        return TypingActivitySample(
            keyDownCount: CGEventSource.counterForEventType(state, eventType: .keyDown),
            modifierChangeCount: CGEventSource.counterForEventType(state, eventType: .flagsChanged),
            secondsSinceKeyDown: CGEventSource.secondsSinceLastEventType(state, eventType: .keyDown),
            shortcutHeld: !flags.intersection([.maskCommand, .maskControl, .maskSecondaryFn]).isEmpty
        )
    }
}
