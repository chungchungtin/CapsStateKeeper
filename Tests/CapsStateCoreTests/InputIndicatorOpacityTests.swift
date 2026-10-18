import Foundation
import XCTest
@testable import CapsStateCore

final class InputIndicatorOpacityTests: XCTestCase {
    func testDefaultPreservesCurrentAppearance() {
        XCTAssertEqual(InputIndicatorOpacity().background, 0)
        XCTAssertEqual(InputIndicatorOpacity().backgroundPercent, 0)
        XCTAssertEqual(InputIndicatorOpacity().text, 1)
        XCTAssertEqual(InputIndicatorOpacity().textPercent, 100)
    }

    func testBackgroundValuesAllowHollowAndClampToWholePercentages() {
        for (input, expected) in [(-1.0, 0), (0.0, 0), (0.1, 10), (0.456, 46), (0.8, 80), (2.0, 100)] {
            let opacity = InputIndicatorOpacity(background: input, text: 0.6)
            XCTAssertEqual(opacity.backgroundPercent, expected)
            XCTAssertEqual(opacity.textPercent, 60)
        }
    }

    func testTextValuesRemainReadableAndClampWithoutChangingBackground() {
        for (input, expected) in [(-1.0, 20), (0.0, 20), (0.2, 20), (0.456, 46), (0.8, 80), (2.0, 100)] {
            let opacity = InputIndicatorOpacity(background: 0.35, text: input)
            XCTAssertEqual(opacity.textPercent, expected)
            XCTAssertEqual(opacity.backgroundPercent, 35)
        }
    }

    func testNonfiniteValuesRecoverToVisibleDefault() {
        for value: Double in [.nan, .infinity, -.infinity] {
            XCTAssertEqual(InputIndicatorOpacity(background: value, text: value), InputIndicatorOpacity())
        }
    }

    func testSettingSurvivesReloadWithoutChangingOtherPreferences() throws {
        let suite = "CapsStateKeeperTests.Opacity.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: "FloatingInputIndicatorEnabled")
        defaults.set(true, forKey: "FloatingInputIndicatorFollowsCaret")
        XCTAssertEqual(InputIndicatorOpacity(defaults: defaults), InputIndicatorOpacity())
        let setting = InputIndicatorOpacity(background: 0.35, text: 0.8)
        setting.save(to: defaults)
        let reloaded = try XCTUnwrap(UserDefaults(suiteName: suite))
        XCTAssertEqual(InputIndicatorOpacity(defaults: reloaded), setting)
        XCTAssertFalse(reloaded.bool(forKey: "FloatingInputIndicatorEnabled"))
        XCTAssertTrue(reloaded.bool(forKey: "FloatingInputIndicatorFollowsCaret"))
    }

    func testLegacySettingBecomesTextOpacityWithoutAddingBackgroundOrOverwritingHistory() throws {
        let suite = "CapsStateKeeperTests.Opacity.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(0.45, forKey: InputIndicatorOpacity.legacyDefaultsKey)
        XCTAssertEqual(InputIndicatorOpacity(defaults: defaults), InputIndicatorOpacity(background: 0, text: 0.45))
        let updated = InputIndicatorOpacity(background: 0.3, text: 0.8)
        updated.save(to: defaults)
        XCTAssertEqual(InputIndicatorOpacity(defaults: defaults), updated)
        XCTAssertEqual(defaults.double(forKey: InputIndicatorOpacity.legacyDefaultsKey), 0.45)
    }

    func testBackgroundOnlySettingStillUsesLegacyTextOpacity() throws {
        let suite = "CapsStateKeeperTests.Opacity.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(0.6, forKey: InputIndicatorOpacity.legacyDefaultsKey)
        defaults.set(0.25, forKey: InputIndicatorOpacity.backgroundDefaultsKey)
        XCTAssertEqual(InputIndicatorOpacity(defaults: defaults), InputIndicatorOpacity(background: 0.25, text: 0.6))
    }

    func testMalformedAndOutOfRangeStoredValuesRecoverSafely() throws {
        let suite = "CapsStateKeeperTests.Opacity.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        for key in [InputIndicatorOpacity.legacyDefaultsKey, InputIndicatorOpacity.backgroundDefaultsKey,
                    InputIndicatorOpacity.textDefaultsKey] {
            defaults.set("invalid", forKey: key)
        }
        XCTAssertEqual(InputIndicatorOpacity(defaults: defaults), InputIndicatorOpacity())
        defaults.set(-1, forKey: InputIndicatorOpacity.backgroundDefaultsKey)
        defaults.set(0, forKey: InputIndicatorOpacity.textDefaultsKey)
        XCTAssertEqual(InputIndicatorOpacity(defaults: defaults), InputIndicatorOpacity(background: 0, text: 0.2))
        defaults.set(4, forKey: InputIndicatorOpacity.backgroundDefaultsKey)
        defaults.set(4, forKey: InputIndicatorOpacity.textDefaultsKey)
        XCTAssertEqual(InputIndicatorOpacity(defaults: defaults), InputIndicatorOpacity(background: 1, text: 1))
    }
}
