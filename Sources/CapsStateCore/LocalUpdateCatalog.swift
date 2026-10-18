import Foundation

public struct LocalUpdateManifest: Equatable, Sendable {
    public static let bundleID = "com.zhongyongting.CapsStateKeeper"
    public let identifier: String
    public let buildID: String
    public let builtAt: String
    public let version: String

    public init(identifier: String, buildID: String, builtAt: String, version: String) {
        self.identifier = identifier
        self.buildID = buildID
        self.builtAt = builtAt
        self.version = version
    }

    public init?(appURL: URL) {
        let infoURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let identifier = info["CFBundleIdentifier"] as? String else { return nil }
        self.init(identifier: identifier,
                  buildID: info["CapsStateKeeperBuildID"] as? String ?? "",
                  builtAt: info["CapsStateKeeperBuiltAt"] as? String ?? "",
                  version: info["CFBundleShortVersionString"] as? String ?? "舊版")
    }

    public var displayVersion: String {
        guard let date = ISO8601DateFormatter().date(from: builtAt) else { return version }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return "\(version)（\(formatter.string(from: date))）"
    }

    public var isValidUpdate: Bool {
        identifier == Self.bundleID && buildID.count == 64 &&
        buildID.allSatisfy { $0.isASCII && $0.isHexDigit } && ISO8601DateFormatter().date(from: builtAt) != nil
    }

    public func isNewer(than installed: LocalUpdateManifest?) -> Bool {
        guard isValidUpdate else { return false }
        guard let installed else { return true }
        guard installed.identifier == Self.bundleID, installed.buildID != buildID else { return false }
        // Legacy builds have no metadata. Equal timestamps can occur for two
        // local builds in one second, so the content fingerprint breaks ties.
        guard let previousDate = ISO8601DateFormatter().date(from: installed.builtAt) else { return true }
        return ISO8601DateFormatter().date(from: builtAt)! >= previousDate
    }
}

public struct LocalUpdateCandidate: Sendable {
    public let source: URL
    public let updater: URL
    public let manifest: LocalUpdateManifest
}

public enum LocalUpdateCheck: Sendable {
    case available(LocalUpdateCandidate)
    case current(String)
    case unavailable(String)
}

public enum LocalUpdateCatalog {
    /// Read only the explicitly configured local build. No network or directory scan.
    public static func check(projectDirectory: String?, installedApp: URL) -> LocalUpdateCheck {
        guard let projectDirectory, projectDirectory.hasPrefix("/") else {
            return .unavailable("這個版本沒有設定本機更新位置，請先使用專案中的更新程式。")
        }
        let dist = URL(fileURLWithPath: projectDirectory, isDirectory: true).appendingPathComponent("dist")
        let source = dist.appendingPathComponent("CapsStateKeeper.app")
        let updater = dist.appendingPathComponent("更新 CapsStateKeeper.app")
        guard let candidate = LocalUpdateManifest(appURL: source), candidate.isValidUpdate else {
            return .unavailable("目前沒有準備好的本機新版。請先在專案中建置更新套件，再檢查更新。")
        }
        let installed = LocalUpdateManifest(appURL: installedApp)
        if let installed, installed.identifier != LocalUpdateManifest.bundleID {
            return .unavailable("安裝位置是不同的 App，不會自動覆寫。請確認 CapsStateKeeper 的安裝位置。")
        }
        guard candidate.isNewer(than: installed) else {
            return .current(installed?.displayVersion ?? candidate.displayVersion)
        }
        guard FileManager.default.isExecutableFile(atPath: updater.appendingPathComponent("Contents/MacOS/CapsStateUpdater").path) else {
            return .unavailable("找不到更新程式。請重新建置完整更新套件；目前版本不會被更動。")
        }
        guard let helper = LocalUpdateManifest(appURL: updater),
              helper.identifier == LocalUpdateManifest.bundleID + ".Updater",
              helper.buildID == candidate.buildID else {
            return .unavailable("更新套件尚未完整準備好，請等待建置完成後再試。")
        }
        return .available(LocalUpdateCandidate(source: source, updater: updater, manifest: candidate))
    }
}
