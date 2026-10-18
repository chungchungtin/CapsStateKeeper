import AppKit
import CapsStateCore

@MainActor
final class UpdaterDelegate: NSObject, NSApplicationDelegate {
    private var process: Process?
    private var logHandle: FileHandle?
    private var progressWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let project = Bundle.main.object(forInfoDictionaryKey: "CapsStateKeeperProjectDirectory") as? String
        let installed = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/CapsStateKeeper.app")
        switch LocalUpdateCatalog.check(projectDirectory: project, installedApp: installed) {
        case .available(let candidate):
            let args = CommandLine.arguments
            if let index = args.firstIndex(of: "--expected-build"),
               index + 1 >= args.count || args[index + 1] != candidate.manifest.buildID {
                finish("更新套件已改變", "請重新點選「檢查本機更新」，確認目前準備好的版本。")
                return
            }
            let alert = NSAlert()
            alert.messageText = "更新 CapsStateKeeper？"
            alert.informativeText = "新版：\(candidate.manifest.displayVersion)\n\n會先備份舊版、保留你的設定，更新後自動重新啟動。過程不需要終端機。\n\n本機簽章更新後，macOS 仍可能要求重新允許輔助使用。"
            alert.addButton(withTitle: "更新並重新啟動")
            alert.addButton(withTitle: "取消")
            guard alert.runModal() == .alertFirstButtonReturn, let project else {
                NSApp.terminate(nil)
                return
            }
            install(candidate, project: project)
        case .current(let version):
            finish("已是本機最新版本", "目前版本：\(version)")
        case .unavailable(let message):
            finish("尚無可安裝的更新", message)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        process?.isRunning == true ? .terminateCancel : .terminateNow
    }

    private func install(_ candidate: LocalUpdateCandidate, project: String) {
        do {
            guard let script = Bundle.main.url(forResource: "install", withExtension: "sh") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let logs = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs/CapsStateKeeper")
            try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
            let log = logs.appendingPathComponent("update-\(UUID().uuidString).log")
            guard FileManager.default.createFile(atPath: log.path, contents: nil,
                                                 attributes: [.posixPermissions: 0o600]) else {
                throw CocoaError(.fileWriteUnknown)
            }
            let handle = try FileHandle(forWritingTo: log)
            logHandle = handle
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = [script.path, "--use-built-app", "--expected-build", candidate.manifest.buildID]
            var environment = ProcessInfo.processInfo.environment
            environment["CAPS_STATE_PROJECT_ROOT"] = project
            task.environment = environment
            task.standardOutput = handle
            task.standardError = handle
            task.terminationHandler = { [weak self] process in
                let status = process.terminationStatus
                Task { @MainActor [weak self] in
                    self?.completed(status: status, log: log)
                }
            }
            process = task
            try task.run()
            showProgress()
        } catch {
            try? logHandle?.close()
            logHandle = nil
            process = nil
            finish("無法開始更新", "舊版與設定未被更動。\n\n\(error.localizedDescription)")
        }
    }

    private func showProgress() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 132),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "正在更新 CapsStateKeeper"
        window.isReleasedWhenClosed = false
        let label = NSTextField(wrappingLabelWithString: "正在備份、安裝並重新啟動…\n請稍候，你的浮標設定會保留。")
        label.frame = NSRect(x: 28, y: 58, width: 344, height: 48)
        let progress = NSProgressIndicator(frame: NSRect(x: 28, y: 28, width: 344, height: 14))
        progress.style = .bar
        progress.isIndeterminate = true
        progress.startAnimation(nil)
        window.contentView?.addSubview(label)
        window.contentView?.addSubview(progress)
        window.center()
        window.makeKeyAndOrderFront(nil)
        progressWindow = window
    }

    private func completed(status: Int32, log: URL) {
        try? logHandle?.close()
        logHandle = nil
        process = nil
        progressWindow?.close()
        progressWindow = nil
        if status == 0 {
            finish("更新完成", "CapsStateKeeper 已重新啟動，設定已保留。\n\n以後可直接從選單列選「檢查本機更新…」。若浮標提示缺少權限，再依選單指示重新允許。")
        } else {
            let output = (try? String(contentsOf: log, encoding: .utf8)) ?? "無法讀取更新記錄"
            let detail = String(output.split(separator: "\n").suffix(5).joined(separator: "\n").prefix(600))
            finish("更新未完成", "未確認成功，不會當成已更新。可按「顯示記錄」查看完整原因。\n\n\(detail)", log: log)
        }
    }

    private func finish(_ title: String, _ message: String, log: URL? = nil) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        if log != nil { alert.addButton(withTitle: "顯示記錄") }
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn, let log {
            NSWorkspace.shared.activateFileViewerSelecting([log])
        }
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = UpdaterDelegate()
app.delegate = delegate
app.run()
