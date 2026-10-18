import Foundation
import XCTest
@testable import CapsStateCore

final class CapsLockSynchronizationPreferenceTests: XCTestCase {
    func testExistingInstallationKeepsSynchronizationEnabledWithoutWritingPreferences() throws {
        let suite = "CapsStateKeeperTests.Synchronization.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertTrue(CapsLockSynchronizationPreference(defaults: defaults).isEnabled)
        XCTAssertNil(defaults.object(forKey: CapsLockSynchronizationPreference.defaultsKey))
    }

    func testDisabledSettingSurvivesReloadWithoutChangingIndicatorPreferences() throws {
        let suite = "CapsStateKeeperTests.Synchronization.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "FloatingInputIndicatorEnabled")
        defaults.set(false, forKey: "FloatingInputIndicatorFollowsCaret")
        let opacity = InputIndicatorOpacity(background: 0.35, text: 0.8)
        opacity.save(to: defaults)

        CapsLockSynchronizationPreference(isEnabled: false).save(to: defaults)
        let reloaded = try XCTUnwrap(UserDefaults(suiteName: suite))

        XCTAssertFalse(CapsLockSynchronizationPreference(defaults: reloaded).isEnabled)
        XCTAssertTrue(reloaded.bool(forKey: "FloatingInputIndicatorEnabled"))
        XCTAssertFalse(reloaded.bool(forKey: "FloatingInputIndicatorFollowsCaret"))
        XCTAssertEqual(InputIndicatorOpacity(defaults: reloaded), opacity)
    }

    func testSynchronizationCanBeReenabledAfterReload() throws {
        let suite = "CapsStateKeeperTests.Synchronization.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        CapsLockSynchronizationPreference(isEnabled: false).save(to: defaults)
        let reloaded = try XCTUnwrap(UserDefaults(suiteName: suite))
        CapsLockSynchronizationPreference(isEnabled: true).save(to: reloaded)

        let nextLaunch = try XCTUnwrap(UserDefaults(suiteName: suite))
        XCTAssertTrue(CapsLockSynchronizationPreference(defaults: nextLaunch).isEnabled)
    }

    func testMalformedSettingUsesExistingDefault() throws {
        let suite = "CapsStateKeeperTests.Synchronization.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("invalid", forKey: CapsLockSynchronizationPreference.defaultsKey)

        XCTAssertTrue(CapsLockSynchronizationPreference(defaults: defaults).isEnabled)
    }
}
