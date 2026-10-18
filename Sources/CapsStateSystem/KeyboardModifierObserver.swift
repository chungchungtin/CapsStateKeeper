import AppKit
import Carbon.HIToolbox

/// Passive modifier and typing-activity observation. Event type and shortcut
/// modifiers classify activity; no characters, key codes, event objects, text
/// values, or keystroke history are retained.
@MainActor
public final class KeyboardModifierObserver {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var generation: UInt64 = 0
    // A local monitor alone cannot detect typing in another application.
    public var isActive: Bool { globalMonitor != nil }
    public static var isSecureInput: Bool { IsSecureEventInputEnabled() }

    public init() {}

    public func start(onChange: @escaping @MainActor (Bool, Bool, Bool) -> Void) {
        guard globalMonitor == nil, TypingAnchorReader.canFollowCaret else { return }
        let generation = generation
        let mask: NSEvent.EventTypeMask = [.keyDown, .keyUp, .flagsChanged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            let caps = event.modifierFlags.contains(.capsLock)
            let shift = event.modifierFlags.contains(.shift)
            let typing = Self.countsAsTyping(type: event.type, modifiers: event.modifierFlags)
            Task { @MainActor [weak self] in
                guard self?.generation == generation else { return }
                onChange(caps, shift, typing)
            }
        }
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
                let caps = event.modifierFlags.contains(.capsLock)
                let shift = event.modifierFlags.contains(.shift)
                // Our menu-only app has no editor. Navigating its menu with
                // the keyboard must update modifiers without waking the badge.
                Task { @MainActor [weak self] in
                    guard self?.generation == generation else { return }
                    onChange(caps, shift, false)
                }
                return event
            }
        }
    }

    nonisolated static func countsAsTyping(type: NSEvent.EventType,
                                           modifiers: NSEvent.ModifierFlags) -> Bool {
        // Shift/Option can produce letters and accents. Command/Control/Fn
        // shortcuts, Caps toggles, releases and mouse events do not wake a badge.
        type == .keyDown && modifiers.intersection([.command, .control, .function]).isEmpty
    }

    public func stop() {
        generation &+= 1
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }
}
