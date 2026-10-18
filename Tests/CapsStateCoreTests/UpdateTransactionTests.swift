import Foundation
import XCTest

/// Exercise the real file transaction in unique temporary folders. All process
/// termination, launchctl and signature hooks are replaced; no installed app,
/// real LaunchAgent, keyboard permission or user preference is touched.
final class UpdateTransactionTests: XCTestCase {
    func testSuccessfulUpdateKeepsOldAppSettingsAndLaunchAgent() throws {
        try withFixture { root in
            let originalAgent = try Data(contentsOf: agent(root))
            let result = try run(root)
            XCTAssertEqual(result.status, 0, result.output)
            XCTAssertTrue(exists(root, "Applications/CapsStateKeeper.app/new"))
            XCTAssertFalse(exists(root, "Applications/CapsStateKeeper.app/old"))
            let backup = try onlyBackup(root)
            XCTAssertTrue(FileManager.default.fileExists(atPath: backup.appendingPathComponent("CapsStateKeeper.app/old").path))
            XCTAssertEqual(try Data(contentsOf: agent(root)), originalAgent)
            XCTAssertTrue(exists(root, "running"))
            try assertPreferencesAndLock(root)
        }
    }

    func testCopyFailureLeavesInstalledAppAndServiceUntouched() throws { try assertRecovers("copy") }
    func testStagedVerificationFailureLeavesInstalledAppUntouched() throws { try assertRecovers("stage-verify") }
    func testServiceStopFailureDoesNotReplaceInstalledApp() throws { try assertRecovers("bootout") }
    func testAppStopFailureRestartsPreviousServiceWithoutReplacingApp() throws { try assertRecovers("stop") }
    func testInstalledVerificationFailureRestoresOldApp() throws { try assertRecovers("installed-verify") }
    func testLaunchFailureRestoresAndRestartsOldApp() throws { try assertRecovers("start") }

    func testFirstInstallationCreatesExpectedLaunchAgent() throws {
        try withFixture(existing: false) { root in
            let result = try run(root)
            XCTAssertEqual(result.status, 0, result.output)
            let info = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: agent(root)), format: nil) as? [String: Any])
            XCTAssertEqual(info["Label"] as? String, "com.zhongyongting.CapsStateKeeper")
            XCTAssertEqual(info["ProgramArguments"] as? [String], [root.appendingPathComponent("Applications/CapsStateKeeper.app/Contents/MacOS/CapsStateKeeper").path])
            XCTAssertTrue(exists(root, "Applications/CapsStateKeeper.app/new"))
            try assertPreferencesAndLock(root)
        }
    }

    func testFirstInstallLaunchFailureQuarantinesNewAppAndAgent() throws {
        try withFixture(existing: false) { root in
            let result = try run(root, failure: "start")
            XCTAssertNotEqual(result.status, 0)
            XCTAssertFalse(exists(root, "Applications/CapsStateKeeper.app"))
            XCTAssertFalse(FileManager.default.fileExists(atPath: agent(root).path))
            let backup = try onlyBackup(root)
            XCTAssertTrue(FileManager.default.fileExists(atPath: backup.appendingPathComponent("failed-new-CapsStateKeeper.app/new").path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: backup.appendingPathComponent("failed-new-LaunchAgent.plist").path))
            try assertPreferencesAndLock(root)
        }
    }

    func testConcurrentUpdateLockPreventsReplacement() throws {
        try withFixture { root in
            let lock = root.appendingPathComponent("Applications/.CapsStateKeeper-update.lock")
            let holder = Process()
            let input = Pipe()
            let output = Pipe()
            holder.executableURL = URL(fileURLWithPath: "/usr/bin/lockf")
            holder.arguments = ["-k", "-t", "0", lock.path, "/bin/bash", "-c", "printf ready; read -r reply"]
            holder.standardInput = input
            holder.standardOutput = output
            try holder.run()
            defer { try? input.fileHandleForWriting.close(); holder.waitUntilExit() }
            XCTAssertEqual(try output.fileHandleForReading.read(upToCount: 5), Data("ready".utf8))
            let result = try run(root)
            XCTAssertNotEqual(result.status, 0)
            XCTAssertTrue(exists(root, "Applications/CapsStateKeeper.app/old"))
            XCTAssertTrue(FileManager.default.fileExists(atPath: lock.path), "Do not remove another updater's lock")
        }
    }

    func testStaleProcessLockDoesNotBlockRetry() throws {
        try withFixture { root in
            let lock = root.appendingPathComponent("Applications/.CapsStateKeeper-update.lock")
            try Data("2147483647\n".utf8).write(to: lock)
            let result = try run(root)
            XCTAssertEqual(result.status, 0, result.output)
            XCTAssertTrue(exists(root, "Applications/CapsStateKeeper.app/new"))
            try assertPreferencesAndLock(root)
        }
    }

    private func assertRecovers(_ failure: String, file: StaticString = #filePath, line: UInt = #line) throws {
        try withFixture { root in
            let originalAgent = try Data(contentsOf: agent(root))
            let result = try run(root, failure: failure)
            XCTAssertNotEqual(result.status, 0, result.output, file: file, line: line)
            XCTAssertTrue(exists(root, "Applications/CapsStateKeeper.app/old"), result.output, file: file, line: line)
            XCTAssertFalse(exists(root, "Applications/CapsStateKeeper.app/new"), file: file, line: line)
            XCTAssertTrue(exists(root, "running"), result.output, file: file, line: line)
            XCTAssertEqual(try Data(contentsOf: agent(root)), originalAgent, file: file, line: line)
            try assertPreferencesAndLock(root)
        }
    }

    private func assertPreferencesAndLock(_ root: URL) throws {
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("preferences"), encoding: .utf8), "background=0.35;text=0.9")
        let probe = Process()
        probe.executableURL = URL(fileURLWithPath: "/usr/bin/lockf")
        probe.arguments = ["-k", "-t", "0", root.appendingPathComponent("Applications/.CapsStateKeeper-update.lock").path, "/usr/bin/true"]
        try probe.run()
        probe.waitUntilExit()
        XCTAssertEqual(probe.terminationStatus, 0, "An ended update must release its kernel lock")
    }

    private func withFixture(existing: Bool = true, body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CapsInstallTests-\(UUID().uuidString) 空白 & 繁體")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source/CapsStateKeeper.app")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try Data().write(to: source.appendingPathComponent("new"))
        try Data("background=0.35;text=0.9".utf8).write(to: root.appendingPathComponent("preferences"))
        if existing {
            let installed = root.appendingPathComponent("Applications/CapsStateKeeper.app")
            try FileManager.default.createDirectory(at: installed, withIntermediateDirectories: true)
            try Data().write(to: installed.appendingPathComponent("old"))
            try Data().write(to: root.appendingPathComponent("running"))
            try FileManager.default.createDirectory(at: agent(root).deletingLastPathComponent(), withIntermediateDirectories: true)
            let info: [String: Any] = ["Label": "com.zhongyongting.CapsStateKeeper",
                                       "ProgramArguments": [installed.appendingPathComponent("Contents/MacOS/CapsStateKeeper").path],
                                       "PreservedCustomSetting": "keep me"]
            try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: agent(root))
        }
        try body(root)
    }

    private func run(_ root: URL, failure: String = "none") throws -> (status: Int32, output: String) {
        let script = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("script/install-core.sh")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", Self.fixtureScript, "transaction-test", script.path, root.path, failure]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    private func agent(_ root: URL) -> URL { root.appendingPathComponent("agents/com.zhongyongting.CapsStateKeeper.plist") }
    private func exists(_ root: URL, _ path: String) -> Bool { FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path) }
    private func onlyBackup(_ root: URL) throws -> URL {
        let backups = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("backups"), includingPropertiesForKeys: nil)
        XCTAssertEqual(backups.count, 1)
        return try XCTUnwrap(backups.first)
    }

    private static let fixtureScript = #"""
    source "$1"
    caps_fixture="$2"
    caps_failure="$3"
    caps_info() {
      case "$2" in
        CFBundleIdentifier) printf '%s' com.zhongyongting.CapsStateKeeper ;;
        CFBundleExecutable) printf '%s' CapsStateKeeper ;;
      esac
    }
    caps_validate_app() {
      [[ -f "$1/new" ]] || return 1
      if [[ "$caps_failure" == stage-verify && "$1" == *stage.* ]]; then return 1; fi
      if [[ "$caps_failure" == installed-verify && "$1" == "$caps_fixture/Applications/CapsStateKeeper.app" ]]; then return 1; fi
    }
    caps_copy_app() {
      /usr/bin/ditto "$1" "$2" || return 1
      [[ "$caps_failure" != copy ]]
    }
    caps_service_loaded() { [[ -f "$caps_fixture/running" ]]; }
    caps_stop_service() {
      [[ "$caps_failure" != bootout ]] || return 1
      /bin/rm "$caps_fixture/running"
    }
    caps_stop_app() { [[ "$caps_failure" != stop ]]; }
    caps_start_service() {
      if [[ "$caps_failure" == start && -f "$caps_fixture/Applications/CapsStateKeeper.app/new" ]]; then return 1; fi
      /usr/bin/touch "$caps_fixture/running"
    }
    caps_install_update "$caps_fixture/source/CapsStateKeeper.app" "$caps_fixture/Applications/CapsStateKeeper.app" \
      "$caps_fixture/agents/com.zhongyongting.CapsStateKeeper.plist" "$caps_fixture/backups" gui/123
    """#
}
