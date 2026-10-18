import AppKit
import CapsStateCore
import Carbon.HIToolbox

@MainActor
public final class TypingStatusReader {
    private var source = TypingInputSource(id: "unknown", name: "輸入法", languageCode: "")
    private var uppercaseByModifiers: [Bool] = [false, true, true, true]
    private var modifiers = TypingModifierFilter()
    private var lastKeyboardModifiers: TypingModifiers?
    private let readFlags: (CGEventSourceStateID) -> CGEventFlags
    private let now: () -> TimeInterval

    public init(
        readFlags: @escaping (CGEventSourceStateID) -> CGEventFlags = { CGEventSource.flagsState($0) },
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.readFlags = readFlags
        self.now = now
        refreshInputSource()
    }

    public func refreshInputSource() {
        refreshInputSource(
            selected: TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
            asciiLayout: TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue()
        )
    }

    // Input services can be unavailable in a session without a keyboard source.
    func refreshInputSource(selected: TISInputSource?, asciiLayout: TISInputSource?) {
        let languages: [String] = property(selected, kTISPropertyInputSourceLanguages) ?? []
        let sourceID: String = property(selected, kTISPropertyInputSourceID) ?? "unknown"
        if sourceID != source.id { invalidateKeyboardModifiers() }
        source = TypingInputSource(
            id: sourceID,
            name: property(selected, kTISPropertyLocalizedName) ?? "輸入法",
            languageCode: languages.first ?? ""
        )

        // Read a layout table; never observe or generate typed characters. The ASCII
        // layout also defines the Latin-letter case indicator while using an IME.
        let data: Data? = property(asciiLayout, kTISPropertyUnicodeKeyLayoutData)
        for index in 0..<4 {
            let caps = index & 1 != 0
            let shift = index & 2 != 0
            uppercaseByModifiers[index] = data.flatMap {
                Self.translatedUppercase(layoutData: $0, capsLock: caps, shift: shift)
            } ?? (caps || shift)
        }
    }

    public func observeKeyboardModifiers(capsLock: Bool, shift: Bool) {
        lastKeyboardModifiers = TypingModifiers(capsLock: capsLock, shift: shift)
        // A real keyboard event is authoritative and needs no polling delay.
        modifiers.acceptKeyboardEvent(capsLock: capsLock, shift: shift)
    }

    public func invalidateKeyboardModifiers() { lastKeyboardModifiers = nil }

    public func snapshot() -> TypingStatus {
        // The session table also includes injected events (including mouse
        // events). Their modifier bits must not overwrite the keyboard badge.
        // Use the hardware event table for both the floating and menu-bar UI.
        // Keyboard-event flags take precedence until the next keyboard event.
        // Mouse movement must not replace them with a different device's flags.
        let settled: TypingModifiers
        if let lastKeyboardModifiers {
            settled = lastKeyboardModifiers
        } else {
            let flags = readFlags(.hidSystemState)
            settled = modifiers.update(capsLock: flags.contains(.maskAlphaShift),
                                       shift: flags.contains(.maskShift), at: now())
        }
        let caps = settled.capsLock
        let shift = settled.shift
        return TypingStatus(
            source: source, capsLock: caps, shift: shift,
            isUppercase: uppercaseByModifiers[(caps ? 1 : 0) | (shift ? 2 : 0)]
        )
    }

    static func translatedUppercase(layoutData: Data, capsLock: Bool, shift: Bool) -> Bool? {
        layoutData.withUnsafeBytes { bytes in
            guard bytes.count >= MemoryLayout<UCKeyboardLayout>.size,
                  let baseAddress = bytes.baseAddress else { return nil }
            let layout = baseAddress.assumingMemoryBound(to: UCKeyboardLayout.self)
            let modifiers = (capsLock ? UInt32(alphaLock) : 0)
                | (shift ? UInt32(shiftKey) : 0)
            var deadKeyState: UInt32 = 0
            var length = 0
            var characters = [UniChar](repeating: 0, count: 8)
            let result = UCKeyTranslate(
                layout, UInt16(kVK_ANSI_A), UInt16(kUCKeyActionDown), modifiers >> 8,
                UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask),
                &deadKeyState, characters.count, &length, &characters
            )
            guard result == noErr, length > 0 else { return nil }
            let sample = String(utf16CodeUnits: characters, count: length)
            guard sample.lowercased() != sample.uppercased() else { return nil }
            return sample == sample.uppercased()
        }
    }

    private func property<T>(_ source: TISInputSource?, _ key: CFString) -> T? {
        guard let source, let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? T
    }
}
