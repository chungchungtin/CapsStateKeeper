import AppKit
import CapsStateCore
import CapsStateSystem
import OSLog

private final class InputIndicatorPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
public final class FloatingInputIndicator {
    private let logger = Logger(subsystem: "com.zhongyongting.CapsStateKeeper", category: "InputIndicator")
    private let reader = TypingStatusReader()
    private let anchorReader = TypingAnchorReader()
    private let modifierObserver = KeyboardModifierObserver()
    private var typingActivity = TypingActivityTracker()
    private var activityFallback = TypingActivityFallback()
    private let view = InputIndicatorView()
    private let panel: NSPanel
    private let defaults: UserDefaults
    private let onStatusChange: (TypingStatus) -> Void
    private let onLocationChange: (String) -> Void
    private let onDetectionChange: (String) -> Void
    private var timer: Timer?
    private var lastStatus: TypingStatus?
    private var lastLocationDescription: String?
    private var lastLocationRefresh = -Double.infinity
    private var lastSourceRefresh = -Double.infinity
    private var screenIsAwake = true
    private var keyboardObservationAllowed = false
    private var menuIsTracking = false
    private var lastObservedTypingTime = -Double.infinity
    private var lastMonitorRecovery = -Double.infinity
    private var detectionDescription = "尚未收到打字訊號"
    private var lastReportedDetection: String?
    // This is the saved feature toggle, not the panel's idle visibility.
    public private(set) var isVisible: Bool
    public private(set) var followsCaret: Bool
    public private(set) var opacity: InputIndicatorOpacity

    public init(defaults: UserDefaults = .standard,
                onLocationChange: @escaping (String) -> Void = { _ in },
                onDetectionChange: @escaping (String) -> Void = { _ in },
                onStatusChange: @escaping (TypingStatus) -> Void) {
        self.defaults = defaults
        self.onStatusChange = onStatusChange
        self.onLocationChange = onLocationChange
        self.onDetectionChange = onDetectionChange
        defaults.register(defaults: ["FloatingInputIndicatorEnabled": true, "FloatingInputIndicatorFollowsCaret": true])
        isVisible = defaults.bool(forKey: "FloatingInputIndicatorEnabled")
        followsCaret = defaults.bool(forKey: "FloatingInputIndicatorFollowsCaret")
        opacity = InputIndicatorOpacity(defaults: defaults)
        panel = InputIndicatorPanel(
            contentRect: view.bounds,
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
        )
        panel.title = "輸入狀態提示"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.alphaValue = 1
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = view
        view.updateOpacity(opacity)
    }

    public func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        timer.tolerance = 0.01
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        refresh(force: true)
        logger.notice("Input indicator started; enabled=\(self.isVisible, privacy: .public), autoHideAfter=2s, nonactivating=true, clickThrough=true")
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        modifierObserver.stop()
        keyboardObservationAllowed = false
        typingActivity.reset()
        activityFallback.reset()
        panel.orderOut(nil)
    }

    public func setVisible(_ visible: Bool) {
        isVisible = visible
        defaults.set(visible, forKey: "FloatingInputIndicatorEnabled")
        typingActivity.reset()
        activityFallback.reset()
        if visible { refresh(force: true) } else { hide(reason: "已關閉") }
    }

    public func setFollowsCaret(_ enabled: Bool) {
        followsCaret = enabled
        defaults.set(enabled, forKey: "FloatingInputIndicatorFollowsCaret")
        refresh(force: true)
    }

    public func setOpacity(_ value: InputIndicatorOpacity) {
        opacity = value
        opacity.save(to: defaults)
        view.updateOpacity(opacity)
        // Appearance-only change: keep the current idle timer, location, focus,
        // and hidden state. The menu has its own non-interactive sample preview.
    }

    public func setScreenAwake(_ awake: Bool) {
        screenIsAwake = awake
        reader.invalidateKeyboardModifiers()
        typingActivity.reset()
        activityFallback.reset()
        if awake { refresh(force: true) } else { hide(reason: "已隱藏（螢幕休眠）") }
    }

    public func resetModifierObservation() { reader.invalidateKeyboardModifiers() }

    public func focusedApplicationDidChange() {
        reader.invalidateKeyboardModifiers()
        typingActivity.reset()
        activityFallback.reset()
        hide(reason: "未打字，已隱藏")
        inputSourceDidChange()
    }

    public func setMenuTracking(_ tracking: Bool) {
        menuIsTracking = tracking
        typingActivity.reset()
        activityFallback.reset()
        if tracking { hide(reason: "選單開啟中，已隱藏") }
        refresh(force: true)
    }

    public func restartTypingDetection() {
        modifierObserver.stop()
        reader.invalidateKeyboardModifiers()
        typingActivity.reset()
        activityFallback.reset()
        lastObservedTypingTime = -.infinity
        detectionDescription = "已重新啟動，等待打字訊號"
        refresh(force: true)
    }

    private func startModifierObservation() {
        modifierObserver.start { [weak self] caps, shift, typing in
            self?.handleKeyboardObservation(caps: caps, shift: shift, typing: typing)
        }
    }

    public func inputSourceDidChange() {
        reader.refreshInputSource()
        lastSourceRefresh = ProcessInfo.processInfo.systemUptime
        refresh(force: true)
    }

    public func refresh(force: Bool = false) {
        guard screenIsAwake else { return }
        let now = ProcessInfo.processInfo.systemUptime
        // Notifications give immediate changes; a periodic recheck also catches IMEs
        // that do not post the usual source-change notification.
        if force || now - lastSourceRefresh >= 1 {
            reader.refreshInputSource()
            lastSourceRefresh = now
            keyboardObservationAllowed = TypingAnchorReader.canFollowCaret
            if keyboardObservationAllowed {
                startModifierObservation()
            } else {
                modifierObserver.stop()
                reader.invalidateKeyboardModifiers()
                typingActivity.reset()
            }
        }
        // Secure Keyboard Entry suppresses event observation. Fall back to
        // hardware state instead of retaining a stale Shift/Caps snapshot.
        let secureInput = KeyboardModifierObserver.isSecureInput
        if secureInput {
            reader.invalidateKeyboardModifiers()
            typingActivity.reset()
        }
        // Keep the same authorization boundary as the normal monitor. This is
        // not a fallback around permission denial or secure keyboard entry.
        if isVisible && keyboardObservationAllowed && !secureInput && !menuIsTracking && !NSApp.isActive {
            let sample = TypingActivitySampler.sample()
            if activityFallback.observe(sample), now - lastObservedTypingTime > 0.15 {
                typingActivity.recordTyping(at: now - sample.secondsSinceKeyDown, pointer: NSEvent.mouseLocation)
                reader.invalidateKeyboardModifiers()
                detectionDescription = "活動備援已接手"
                // A non-nil NSEvent token doesn't prove events are arriving.
                // Recover a stalled monitor, with a cooldown to avoid churn.
                if now - lastMonitorRecovery >= 10 {
                    lastMonitorRecovery = now
                    modifierObserver.stop()
                    startModifierObservation()
                }
            }
        } else {
            activityFallback.reset()
        }
        let detection: String
        if !keyboardObservationAllowed { detection = "尚未取得輔助使用權限" }
        else if secureInput { detection = "安全輸入暫停中" }
        else if !modifierObserver.isActive && detectionDescription != "活動備援已接手" {
            detection = "事件觀察無法啟動；活動備援待命"
        }
        else { detection = detectionDescription }
        if lastReportedDetection != detection {
            lastReportedDetection = detection
            onDetectionChange(detection)
        }
        let status = reader.snapshot()
        let previousSize = view.preferredSize
        if lastStatus != status {
            view.update(status)
            lastStatus = status
            onStatusChange(status)
        }
        // Status polling and keyboard observation must continue while hidden,
        // but no AX location reads or mouse-position polling happen when idle.
        guard isVisible else {
            hide(reason: "已關閉")
            return
        }
        guard keyboardObservationAllowed else {
            hide(reason: "需允許打字偵測與定位")
            return
        }
        guard !secureInput else {
            hide(reason: "安全輸入中，已隱藏")
            return
        }
        guard !menuIsTracking else {
            hide(reason: "選單開啟中，已隱藏")
            return
        }
        guard typingActivity.isActive(at: now) else {
            typingActivity.reset()
            hide(reason: "未打字，已隱藏")
            return
        }
        if force || !panel.isVisible || view.preferredSize != previousSize || now - lastLocationRefresh >= 0.10 {
            updatePosition()
            lastLocationRefresh = now
        }
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    private func handleKeyboardObservation(caps: Bool, shift: Bool, typing: Bool) {
        guard timer != nil, screenIsAwake, keyboardObservationAllowed,
              !KeyboardModifierObserver.isSecureInput else { return }
        reader.observeKeyboardModifiers(capsLock: caps, shift: shift)
        if typing && isVisible && !menuIsTracking && !NSApp.isActive {
            let now = ProcessInfo.processInfo.systemUptime
            lastObservedTypingTime = now
            detectionDescription = "已收到打字訊號"
            typingActivity.recordTyping(at: now, pointer: NSEvent.mouseLocation)
        }
        refresh()
    }

    private func hide(reason: String) {
        if panel.isVisible { panel.orderOut(nil) }
        lastLocationRefresh = -.infinity
        updateLocationDescription(reason)
    }

    private func updateLocationDescription(_ description: String) {
        guard lastLocationDescription != description else { return }
        lastLocationDescription = description
        onLocationChange(description)
    }

    private func updatePosition() {
        let screens = NSScreen.screens
        guard let primary = screens.first, let pointer = typingActivity.fallbackPosition else { return }
        // Never reuse the previous app's caret after focus changes or AX fails.
        let anchor = anchorReader.read(followCaret: followsCaret)
        let convert: (CGRect) -> CGRect = {
            FloatingIndicatorPlacement.appKitRect(from: $0, primaryDisplayTop: primary.frame.maxY)
        }
        let caret = anchor?.caret.map(convert)
        // With no caret, an enormous document surface is not a useful typing
        // location. Prefer the explicitly labelled mouse fallback in that case.
        let field = anchor?.field.flatMap { $0.height <= 400 ? convert($0) : nil }
        // The fallback is captured only on typing, never continuously from the
        // mouse. Even during the 2-second grace period the badge will not chase it.
        let reference = caret ?? field
        let screen = reference.flatMap { rect in
            screens.max { left, right in
                Self.intersectionArea(left.frame, rect) < Self.intersectionArea(right.frame, rect)
            }
        } ?? screens.first(where: { NSMouseInRect(pointer, $0.frame, false) }) ?? primary

        let description: String
        let hint: String?
        if caret != nil {
            description = "文字游標旁"
            hint = nil
        } else if field != nil {
            description = "輸入框旁（App 未提供游標）"
            hint = "輸入框旁"
        } else {
            description = followsCaret ? "App 未提供位置；最後打字時的滑鼠旁" : "最後打字時的滑鼠旁"
            hint = "滑鼠旁"
        }
        if lastLocationDescription != description {
            view.updatePositionHint(hint)
            updateLocationDescription(description)
        }

        let frame = FloatingIndicatorPlacement.frame(
            size: view.preferredSize, caret: caret, field: field,
            pointer: pointer, visibleScreen: screen.visibleFrame
        )
        if panel.frame != frame { panel.setFrame(frame, display: true) }
    }

    private static func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        // A zero-width caret still needs to select its containing display.
        if rhs.width == 0, lhs.contains(rhs.origin) { return .greatestFiniteMagnitude }
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }
}
