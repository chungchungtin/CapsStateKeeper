import Foundation
import XCTest
@testable import CapsStateCore

final class LocalUpdateCatalogTests: XCTestCase {
    private let oldID = String(repeating: "a", count: 64)
    private let newID = String(repeating: "b", count: 64)

    func testLegacyInstallationCanUpdate() {
        XCTAssertTrue(manifest().isNewer(than: LocalUpdateManifest(identifier: LocalUpdateManifest.bundleID,
                                                                  buildID: "", builtAt: "", version: "舊版")))
        XCTAssertTrue(manifest().isNewer(than: nil))
    }

    func testIdenticalContentDoesNotReinstallEvenWithNewBuildTime() {
        XCTAssertFalse(manifest().isNewer(than: manifest(date: "2026-10-15T01:00:00Z")))
    }

    func testOlderBuildIsNotOfferedAndSameSecondNewContentIsAllowed() {
        XCTAssertFalse(manifest(date: "2026-10-14T01:00:00Z").isNewer(than: manifest(id: oldID)))
        XCTAssertTrue(manifest().isNewer(than: manifest(id: oldID)))
    }

    func testInvalidPackagesAndDifferentAppsCannotUpdate() {
        XCTAssertFalse(manifest(id: "bad").isValidUpdate)
        XCTAssertFalse(manifest(id: String(repeating: "z", count: 64)).isValidUpdate)
        XCTAssertFalse(manifest(date: "bad").isValidUpdate)
        XCTAssertFalse(manifest(identifier: "another.app").isValidUpdate)
        XCTAssertFalse(manifest().isNewer(than: manifest(identifier: "another.app")))
    }

    func testMissingSourceReportsUnavailableWithoutCreatingFiles() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        if case .unavailable = LocalUpdateCatalog.check(projectDirectory: root.path,
                                                        installedApp: root.appendingPathComponent("installed.app")) {} else {
            XCTFail("Missing build must not be offered")
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
    }

    func testCompleteMatchingPairIsOfferedAndUpdatedMetadataIsReadFresh() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("dist/CapsStateKeeper.app")
        let helper = root.appendingPathComponent("dist/更新 CapsStateKeeper.app")
        let installed = root.appendingPathComponent("Applications/CapsStateKeeper.app")
        try write(manifest(), at: source)
        try write(manifest(identifier: LocalUpdateManifest.bundleID + ".Updater"), at: helper, helper: true)
        try write(manifest(id: oldID), at: installed)
        if case .available(let candidate) = LocalUpdateCatalog.check(projectDirectory: root.path, installedApp: installed) {
            XCTAssertEqual(candidate.manifest.buildID, newID)
            XCTAssertEqual(candidate.source.path, source.path)
            XCTAssertEqual(candidate.updater.path, helper.path)
        } else { XCTFail("Matching source and helper should be offered") }
        try write(manifest(), at: installed)
        if case .current = LocalUpdateCatalog.check(projectDirectory: root.path, installedApp: installed) {} else {
            XCTFail("Read the installed metadata again instead of caching Bundle info")
        }
    }

    func testMissingOrMismatchedHelperIsNotOffered() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let installed = root.appendingPathComponent("Applications/CapsStateKeeper.app")
        try write(manifest(), at: root.appendingPathComponent("dist/CapsStateKeeper.app"))
        if case .unavailable = LocalUpdateCatalog.check(projectDirectory: root.path, installedApp: installed) {} else {
            XCTFail("Missing helper should block updating")
        }
        try write(manifest(id: oldID, identifier: LocalUpdateManifest.bundleID + ".Updater"),
                  at: root.appendingPathComponent("dist/更新 CapsStateKeeper.app"), helper: true)
        if case .unavailable = LocalUpdateCatalog.check(projectDirectory: root.path, installedApp: installed) {} else {
            XCTFail("Partially published update must not be offered")
        }
    }

    private func manifest(id: String? = nil, date: String = "2026-10-16T01:00:00Z",
                          identifier: String = LocalUpdateManifest.bundleID) -> LocalUpdateManifest {
        LocalUpdateManifest(identifier: identifier, buildID: id ?? newID, builtAt: date, version: "1.2")
    }

    private func fixtureRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CapsUpdateTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func write(_ manifest: LocalUpdateManifest, at app: URL, helper: Bool = false) throws {
        let executable = helper ? "CapsStateUpdater" : "CapsStateKeeper"
        let macos = app.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: macos, withIntermediateDirectories: true)
        // Test files only; these are never executed or accepted by codesign.
        let binary = macos.appendingPathComponent(executable)
        try Data("fixture".utf8).write(to: binary)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: binary.path)
        let info = ["CFBundleIdentifier": manifest.identifier, "CFBundleExecutable": executable,
                    "CFBundleShortVersionString": manifest.version, "CapsStateKeeperBuildID": manifest.buildID,
                    "CapsStateKeeperBuiltAt": manifest.builtAt]
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: app.appendingPathComponent("Contents/Info.plist"), options: .atomic)
    }
}
