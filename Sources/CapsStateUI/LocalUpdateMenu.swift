import AppKit
import CapsStateCore

/// The menu launches a separate, user-confirmed updater app. It never stops or
/// replaces its own executable, and does not install anything on a timer.
@MainActor
public final class LocalUpdateMenu: NSObject {
    public let item = NSMenuItem(title: "檢查本機更新…", action: nil, keyEquivalent: "")
    private let projectDirectory: String?
    private let currentApp: URL

    public init(bundle: Bundle = .main) {
        projectDirectory = bundle.object(forInfoDictionaryKey: "CapsStateKeeperProjectDirectory") as? String
        currentApp = bundle.bundleURL
        super.init()
        item.target = self
        item.action = #selector(checkForUpdate)
        item.toolTip = "檢查這台 Mac 上已建置的更新套件"
        item.isHidden = projectDirectory?.hasPrefix("/") != true
    }

    @objc private func checkForUpdate() {
        switch LocalUpdateCatalog.check(projectDirectory: projectDirectory, installedApp: currentApp) {
        case .available(let candidate):
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.arguments = ["--expected-build", candidate.manifest.buildID]
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: candidate.updater, configuration: configuration) { _, error in
                guard let error else { return }
                let description = error.localizedDescription
                Task { @MainActor in Self.show("無法開啟更新程式", description) }
            }
        case .current(let version):
            Self.show("已是本機最新版本", "目前版本：\(version)\n\n已與這台 Mac 上的更新套件比對完成。")
        case .unavailable(let reason):
            Self.show("尚無可安裝的更新", reason)
        }
    }

    private static func show(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
