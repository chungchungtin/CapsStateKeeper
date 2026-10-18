import AppKit
import CapsStateCore
import CapsStateSystem
import CapsStateUI
import Carbon.HIToolbox
import OSLog

@MainActor
final class CapsStateKeeperDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let logger = Logger(
        subsystem: "com.zhongyongting.CapsStateKeeper",
        category: "Synchronization"
    )
    private let policy = CapsStatePolicy(
        latinSourceIDs: ["com.apple.keylayout.ABC"]
    )
    private let reader = SystemCapsStateReader()
    private var controller: HIDCapsLockController?
    private var keyboardMonitor: KeyboardDeviceMonitor?
    private var statusItem: NSStatusItem?
    private var capsStateMenuItem: NSMenuItem?
    private var statusMenuItem: NSMenuItem?
    private var inputMonitoringMenuItem: NSMenuItem?
    private var caretAccessMenuItem: NSMenuItem?
    private var synchronizationMenuItem: NSMenuItem?
    private var synchronizeNowMenuItem: NSMenuItem?
    private var floatingIndicator: FloatingInputIndicator?
    private var floatingIndicatorMenuItem: NSMenuItem?
    private var opacityMenu: InputIndicatorOpacityMenu?
    private var updateMenu: LocalUpdateMenu?
    private var caretFollowingMenuItem: NSMenuItem?
    private var locationStatusMenuItem: NSMenuItem?
    private var detectionStatusMenuItem: NSMenuItem?
    private var pendingCapsStateRefreshes: [DispatchWorkItem] = []
    private var pendingSynchronizations: [DispatchWorkItem] = []
    private var displayedCapsState: Bool?
    private var isEnabled = CapsLockSynchronizationPreference(defaults: .standard).isEnabled

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        var startupError: String?
        do {
            controller = try HIDCapsLockController()
        } catch {
            logger.error("Unable to open IOHIDSystem: \(String(describing: error), privacy: .public)")
            startupError = "無法開啟鍵盤系統"
        }

        presentStatusItem(error: startupError)
        let indicator = FloatingInputIndicator(onLocationChange: { [weak self] location in
            self?.locationStatusMenuItem?.title = "浮標：\(location)"
        }, onDetectionChange: { [weak self] detection in
            self?.detectionStatusMenuItem?.title = "打字偵測：\(detection)"
        }) { [weak self] status in
            self?.updateCapsStateIndicator(isOn: status.capsLock)
            self?.statusItem?.button?.toolTip = status.accessibilityDescription
        }
        floatingIndicator = indicator
        floatingIndicatorMenuItem?.state = indicator.isVisible ? .on : .off
        caretFollowingMenuItem?.state = indicator.followsCaret ? .on : .off
        opacityMenu?.update(indicator.opacity)
        indicator.start()
        if indicator.isVisible && !TypingAnchorReader.canFollowCaret,
           !UserDefaults.standard.bool(forKey: "CaretPermissionRequested") {
            requestCaretAccess()
        }
        configureKeyboardMonitoring(requestIfNeeded: false)
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceDidChange),
            name: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            workspace.addObserver(self, selector: #selector(focusedApplicationDidChange), name: name, object: nil)
        }
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            workspace.addObserver(self, selector: #selector(screenDidSleep), name: name, object: nil)
        }
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            workspace.addObserver(self, selector: #selector(screenDidWake), name: name, object: nil)
        }
        scheduleSynchronizationAttempts(after: [0, 0.05, 0.25, 0.50])
    }

    func applicationWillTerminate(_ notification: Notification) {
        floatingIndicator?.stop()
        cancelPendingCapsStateRefreshes()
        cancelPendingSynchronizations()
        keyboardMonitor = nil
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    private func presentStatusItem(error: String?) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        let capsState = NSMenuItem(
            title: "Caps Lock：讀取中",
            action: nil,
            keyEquivalent: ""
        )
        capsState.isEnabled = false
        menu.addItem(capsState)
        capsStateMenuItem = capsState

        menu.addItem(.separator())
        let floating = actionItem("打字時顯示浮標", action: #selector(toggleFloatingIndicator))
        menu.addItem(floating)
        floatingIndicatorMenuItem = floating

        let settings = NSMenu(title: "浮標設定")
        settings.autoenablesItems = false
        let caret = actionItem("跟隨文字游標", action: #selector(toggleCaretFollowing))
        caret.toolTip = "關閉時，浮標會停在最後一次打字時的滑鼠旁"
        settings.addItem(caret)
        caretFollowingMenuItem = caret
        let opacity = InputIndicatorOpacityMenu(opacity: InputIndicatorOpacity(defaults: .standard)) { [weak self] value in
            self?.floatingIndicator?.setOpacity(value)
        }
        opacityMenu = opacity
        settings.addItem(opacity.item)
        let settingsItem = NSMenuItem(title: settings.title, action: nil, keyEquivalent: "")
        settingsItem.submenu = settings
        menu.addItem(settingsItem)

        let synchronization = actionItem("自動同步 Caps Lock", action: #selector(toggleSynchronization))
        menu.addItem(synchronization)
        synchronizationMenuItem = synchronization
        menu.addItem(.separator())

        let diagnostics = NSMenu(title: "診斷與權限")
        diagnostics.autoenablesItems = false
        let status = NSMenuItem(
            title: error ?? (isEnabled ? "同步：待命" : "同步：已暫停"),
            action: nil,
            keyEquivalent: ""
        )
        status.isEnabled = false
        diagnostics.addItem(status)
        statusMenuItem = status
        let location = NSMenuItem(title: "浮標：未打字，已隱藏", action: nil, keyEquivalent: "")
        location.isEnabled = false
        diagnostics.addItem(location)
        locationStatusMenuItem = location
        let detection = NSMenuItem(title: "打字偵測：尚未收到打字訊號", action: nil, keyEquivalent: "")
        detection.isEnabled = false
        diagnostics.addItem(detection)
        detectionStatusMenuItem = detection
        diagnostics.addItem(.separator())

        let synchronizeNow = actionItem("立即同步", action: #selector(synchronizeNow))
        diagnostics.addItem(synchronizeNow)
        synchronizeNowMenuItem = synchronizeNow
        diagnostics.addItem(actionItem("重新啟動打字偵測", action: #selector(restartTypingDetection)))
        let permission = actionItem("允許輔助使用…", action: #selector(requestCaretAccess))
        permission.toolTip = "讓浮標偵測打字活動並跟隨文字游標"
        permission.isHidden = TypingAnchorReader.canFollowCaret
        diagnostics.addItem(permission)
        caretAccessMenuItem = permission
        let inputMonitoring = actionItem("允許輸入監控…", action: #selector(requestInputMonitoring))
        inputMonitoring.toolTip = "辨識切換輸入法的鍵盤，供多鍵盤 Caps Lock 同步使用"
        diagnostics.addItem(inputMonitoring)
        inputMonitoringMenuItem = inputMonitoring
        let diagnosticsItem = NSMenuItem(title: diagnostics.title, action: nil, keyEquivalent: "")
        diagnosticsItem.submenu = diagnostics
        menu.addItem(diagnosticsItem)
        updateSynchronizationControls()

        let update = LocalUpdateMenu()
        updateMenu = update
        menu.addItem(update.item)
        menu.addItem(actionItem("關於 CapsStateKeeper", action: #selector(showAbout)))
        menu.addItem(.separator())

        let quit = actionItem("結束 CapsStateKeeper", action: #selector(quitApplication))
        quit.keyEquivalent = "q"
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
        refreshCapsStateIndicator()
    }

    private func actionItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func updateSynchronizationControls() {
        synchronizationMenuItem?.state = isEnabled && controller != nil ? .on : .off
        synchronizationMenuItem?.isEnabled = controller != nil
        synchronizeNowMenuItem?.isEnabled = isEnabled && controller != nil
    }

    private func refreshCapsStateIndicator() {
        // One filtered reader owns both indicators. Synchronization snapshots
        // and immediate HID callbacks must never write raw flags into the UI.
        floatingIndicator?.refresh()
    }

    private func updateCapsStateIndicator(isOn: Bool) {
        guard displayedCapsState != isOn else { return }
        displayedCapsState = isOn
        let stateText = isOn ? "開啟" : "關閉"
        let symbolName = isOn ? "capslock.fill" : "capslock"
        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: "Caps Lock：\(stateText)"
            )
            button.image?.isTemplate = true
            button.toolTip = "Caps Lock：\(stateText)"
        }
        capsStateMenuItem?.title = "Caps Lock：\(stateText)"
        logger.info("Caps indicator updated: \(stateText, privacy: .public)")
    }

    private func scheduleCapsStateRefreshes() {
        cancelPendingCapsStateRefreshes()
        for delay in [0.0, 0.02, 0.10] {
            let work = DispatchWorkItem { [weak self] in
                self?.refreshCapsStateIndicator()
            }
            pendingCapsStateRefreshes.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    private func cancelPendingCapsStateRefreshes() {
        pendingCapsStateRefreshes.forEach { $0.cancel() }
        pendingCapsStateRefreshes.removeAll()
    }

    @objc private func toggleFloatingIndicator(_ sender: NSMenuItem) {
        guard let floatingIndicator else { return }
        floatingIndicator.setVisible(!floatingIndicator.isVisible)
        sender.state = floatingIndicator.isVisible ? .on : .off
        if floatingIndicator.isVisible && !TypingAnchorReader.canFollowCaret {
            requestCaretAccess()
        }
    }

    @objc private func toggleCaretFollowing(_ sender: NSMenuItem) {
        guard let floatingIndicator else { return }
        let enabled = !floatingIndicator.followsCaret
        floatingIndicator.setFollowsCaret(enabled)
        sender.state = enabled ? .on : .off
        if enabled && !TypingAnchorReader.canFollowCaret {
            requestCaretAccess()
        }
    }

    @objc private func requestCaretAccess() {
        UserDefaults.standard.set(true, forKey: "CaretPermissionRequested")
        TypingAnchorReader.requestCaretAccess()
        if !TypingAnchorReader.canFollowCaret {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        floatingIndicator?.setMenuTracking(true)
        caretAccessMenuItem?.isHidden = TypingAnchorReader.canFollowCaret
        if KeyboardDeviceMonitor.hasInputMonitoringAccess() != (keyboardMonitor != nil) {
            configureKeyboardMonitoring(requestIfNeeded: false)
        }
    }
    func menuDidClose(_ menu: NSMenu) { floatingIndicator?.setMenuTracking(false) }
    @objc private func restartTypingDetection() { floatingIndicator?.restartTypingDetection() }

    @objc private func inputSourceDidChange() {
        floatingIndicator?.inputSourceDidChange()
        scheduleSynchronizationAttempts(after: [0, 0.05, 0.25, 0.50])
    }

    @objc private func focusedApplicationDidChange() {
        floatingIndicator?.focusedApplicationDidChange()
    }

    @objc private func screenDidSleep() { floatingIndicator?.setScreenAwake(false) }
    @objc private func screenDidWake() { floatingIndicator?.setScreenAwake(true) }

    private func scheduleSynchronizationAttempts(after delays: [TimeInterval]) {
        guard isEnabled else { return }
        cancelPendingSynchronizations()
        for delay in delays {
            let work = DispatchWorkItem { [weak self] in
                self?.synchronizeCapsState()
            }
            pendingSynchronizations.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    private func cancelPendingSynchronizations() {
        pendingSynchronizations.forEach { $0.cancel() }
        pendingSynchronizations.removeAll()
    }

    private func synchronizeCapsState() {
        guard isEnabled, let controller else { return }
        defer { floatingIndicator?.refresh() }
        do {
            let preferredKeyboard = keyboardMonitor?.recentSwitchKeyboard()
            let snapshot = try reader.snapshot(
                preferredKeyboard: preferredKeyboard
            )
            if snapshot.sourceID == "com.apple.keylayout.ABC" {
                let keyboard = preferredKeyboard?.product ?? "unidentified"
                let desired = snapshot.hidCapsLock
                    .map(String.init) ?? "ambiguous"
                logger.info(
                    "ABC transition keyboard=\(keyboard, privacy: .public) desired=\(desired, privacy: .public) event=\(snapshot.eventCapsLock, privacy: .public)"
                )
            }
            if snapshot.sourceID == "com.apple.keylayout.ABC",
               snapshot.hidCapsLock == nil {
                statusMenuItem?.title = "鍵盤 Caps 狀態不同；未猜測"
                return
            }
            guard case let .setCapsLock(enabled)? = policy.action(for: snapshot) else {
                statusMenuItem?.title = "同步：待命"
                return
            }

            guard enabled else { return }

            if try controller.restoreOnState() {
                floatingIndicator?.resetModifierObservation()
                statusMenuItem?.title = "最近同步：Caps ON"
                logger.notice(
                    "Restored Caps Lock to true for \(snapshot.sourceID, privacy: .public)"
                )
            }
        } catch {
            statusMenuItem?.title = "同步失敗；請查看紀錄"
            logger.error("Synchronization failed: \(String(describing: error), privacy: .public)")
        }
    }

    @objc private func toggleSynchronization(_ sender: NSMenuItem) {
        isEnabled.toggle()
        CapsLockSynchronizationPreference(isEnabled: isEnabled).save(to: .standard)
        updateSynchronizationControls()
        statusMenuItem?.title = isEnabled
            ? "同步：待命"
            : "同步：已暫停"
        if isEnabled {
            scheduleSynchronizationAttempts(after: [0, 0.05, 0.25, 0.50])
        } else {
            cancelPendingSynchronizations()
        }
    }

    @objc private func synchronizeNow() {
        scheduleSynchronizationAttempts(after: [0])
    }

    private func configureKeyboardMonitoring(requestIfNeeded: Bool) {
        if KeyboardDeviceMonitor.hasInputMonitoringAccess() {
            do {
                keyboardMonitor = try KeyboardDeviceMonitor { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.scheduleCapsStateRefreshes()
                    }
                }
                inputMonitoringMenuItem?.isHidden = true
                logger.notice("Keyboard device identification enabled")
            } catch {
                keyboardMonitor = nil
                inputMonitoringMenuItem?.title = "重新啟動鍵盤辨識"
                inputMonitoringMenuItem?.isHidden = false
                logger.error(
                    "Keyboard monitoring failed: \(String(describing: error), privacy: .public)"
                )
            }
            return
        }

        keyboardMonitor = nil
        inputMonitoringMenuItem?.title = "允許輸入監控…"
        inputMonitoringMenuItem?.isHidden = false
        guard requestIfNeeded else { return }

        if KeyboardDeviceMonitor.requestInputMonitoringAccess() {
            configureKeyboardMonitoring(requestIfNeeded: false)
        } else {
            statusMenuItem?.title = "請允許「輸入監控」後重新開啟"
        }
    }

    @objc private func requestInputMonitoring() {
        configureKeyboardMonitoring(requestIfNeeded: true)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "CapsStateKeeper",
            .credits: NSAttributedString(string: "顯示輸入狀態，並在切回 ABC 時同步 Caps Lock。")
        ])
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }
}

let application = NSApplication.shared
let delegate = CapsStateKeeperDelegate()
application.delegate = delegate
application.run()
