import AppKit
import CapsStateCore
@preconcurrency import ApplicationServices

public struct TypingAnchor {
    public var window: CGRect?
    public var caret: CGRect?
    public var field: CGRect?
}

@MainActor
public final class TypingAnchorReader {
    private var accessibilityPreparedPID: pid_t?
    public init() {}

    public static var canFollowCaret: Bool { AXIsProcessTrusted() }

    public static func requestCaretAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    public func read(followCaret: Bool) -> TypingAnchor? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return nil
        }
        guard followCaret && Self.canFollowCaret,
              let focus = focusedElement(in: app) else {
            return TypingAnchor(window: nil, caret: nil, field: nil)
        }
        let window: CGRect?
        if let rawWindow = attribute(focus, kAXWindowAttribute),
           CFGetTypeID(rawWindow) == AXUIElementGetTypeID() {
            let focusedWindow = unsafeDowncast(rawWindow, to: AXUIElement.self)
            AXUIElementSetMessagingTimeout(focusedWindow, 0.04)
            window = elementBounds(focusedWindow) ?? frontWindowBounds(pid: app.processIdentifier)
        } else {
            window = frontWindowBounds(pid: app.processIdentifier)
        }
        let field = fieldBounds(focus).flatMap {
            TypingAnchorGeometry.validField($0, window: window) ? $0 : nil
        }
        let caret = caretBounds(focus).flatMap {
            TypingAnchorGeometry.validCaret($0, field: field, window: window) ? $0 : nil
        }
        return TypingAnchor(window: window, caret: caret, field: field)
    }

    private func frontWindowBounds(pid: pid_t) -> CGRect? {
        // Only metadata is used: PID, layer, opacity, and geometry. No screenshot,
        // window title, field value, or typed text is requested or stored.
        let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] ?? []
        return windows.lazy.compactMap { info -> CGRect? in
            guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
                  (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1 > 0,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds),
                  rect.width > 100, rect.height > 50 else { return nil }
            return rect
        }.first
    }

    private func focusedElement(in app: NSRunningApplication) -> AXUIElement? {
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.04)

        // Electron exposes its web input controls only after assistive support
        // is enabled. This documented attribute does not read any text or
        // change keyboard focus. Do it once per foreground app, not per tick.
        if accessibilityPreparedPID != app.processIdentifier {
            accessibilityPreparedPID = app.processIdentifier
            if let bundle = app.bundleURL,
               FileManager.default.fileExists(atPath: bundle.appendingPathComponent(
                   "Contents/Frameworks/Electron Framework.framework"
               ).path) {
                AXUIElementSetAttributeValue(application, "AXManualAccessibility" as CFString, kCFBooleanTrue)
            }
        }
        guard let rawFocus = attribute(application, kAXFocusedUIElementAttribute),
              CFGetTypeID(rawFocus) == AXUIElementGetTypeID() else { return nil }
        let focus = unsafeDowncast(rawFocus, to: AXUIElement.self)
        AXUIElementSetMessagingTimeout(focus, 0.04)
        return focus
    }

    private func fieldBounds(_ focus: AXUIElement) -> CGRect? {
        let role = attribute(focus, kAXRoleAttribute) as? String
        let subrole = attribute(focus, kAXSubroleAttribute) as? String
        let textRoles = [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole]
        guard textRoles.contains(role ?? "") || subrole == kAXSecureTextFieldSubrole
                || attribute(focus, kAXSelectedTextRangeAttribute) != nil
                || attribute(focus, "AXSelectedTextMarkerRange") != nil else { return nil }
        return elementBounds(focus)
    }

    private func elementBounds(_ element: AXUIElement) -> CGRect? {
        guard let position: CGPoint = value(attribute(element, kAXPositionAttribute), type: .cgPoint),
              let size: CGSize = value(attribute(element, kAXSizeAttribute), type: .cgSize) else { return nil }
        return CGRect(origin: position, size: size)
    }

    private func caretBounds(_ focus: AXUIElement) -> CGRect? {
        if var range: CFRange = value(attribute(focus, kAXSelectedTextRangeAttribute), type: .cfRange),
           range.location >= 0 {
            range.length = 0
            if let rect = bounds(focus, range: range), rect.height > 0 { return rect }

            // Some text systems reject a zero-length range (especially at the
            // end of a line). The adjacent character's edge is still a caret;
            // only its geometry is requested, never its string value.
            range.length = 1
            if let rect = bounds(focus, range: range), rect.height > 0 {
                return CGRect(x: rect.minX, y: rect.minY, width: 0, height: rect.height)
            }
            if range.location > 0 {
                range.location -= 1
                if let rect = bounds(focus, range: range), rect.height > 0 {
                    return CGRect(x: rect.maxX, y: rect.minY, width: 0, height: rect.height)
                }
            }
        }
        // WebKit/Chromium contenteditable controls may provide marker ranges
        // instead of numeric selected ranges. Markers contain positions only.
        if let markerRange = attribute(focus, "AXSelectedTextMarkerRange") {
            return parameterizedValue(focus, "AXBoundsForTextMarkerRange", markerRange)
        }
        return nil
    }

    private func bounds(_ focus: AXUIElement, range: CFRange) -> CGRect? {
        var range = range
        guard let parameter = AXValueCreate(.cfRange, &range) else { return nil }
        return parameterizedValue(focus, kAXBoundsForRangeParameterizedAttribute, parameter)
    }

    private func parameterizedValue(_ focus: AXUIElement, _ name: String, _ parameter: CFTypeRef) -> CGRect? {
        var raw: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(focus, name as CFString, parameter, &raw) == .success else {
            return nil
        }
        return value(raw, type: .cgRect)
    }

    private func value<T>(_ raw: CFTypeRef?, type: AXValueType) -> T? {
        guard let raw, CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeDowncast(raw, to: AXValue.self)
        guard AXValueGetType(axValue) == type else { return nil }
        let storage = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { storage.deallocate() }
        guard AXValueGetValue(axValue, type, storage) else { return nil }
        return storage.pointee
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value
    }
}
