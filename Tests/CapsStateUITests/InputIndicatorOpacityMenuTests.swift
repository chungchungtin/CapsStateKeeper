import AppKit
import CapsStateCore
import XCTest
@testable import CapsStateUI

final class InputIndicatorOpacityMenuTests: XCTestCase {
    @MainActor
    func testControllerAppliesOpacityWithoutShowingMovingOrReenablingThePanel() throws {
        let app = NSApplication.shared
        let existingWindows = Set(app.windows.map { ObjectIdentifier($0) })
        let suite = "CapsStateKeeperTests.OpacityPanel.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        InputIndicatorOpacity(background: 0.3, text: 0.6).save(to: defaults)
        defaults.set(false, forKey: "FloatingInputIndicatorEnabled")
        defaults.set(false, forKey: "FloatingInputIndicatorFollowsCaret")
        // Construct our own hidden panel only. Do not start keyboard observation.
        let indicator = FloatingInputIndicator(defaults: defaults) { _ in }
        let panel = try XCTUnwrap(app.windows.first {
            !existingWindows.contains(ObjectIdentifier($0)) && $0.title == "輸入狀態提示"
        })
        defer { indicator.stop(); panel.close() }
        let initialFrame = panel.frame
        let view = try XCTUnwrap(panel.contentView as? InputIndicatorView)
        try assertAppearance(view, background: 0.3, text: 0.6)
        let setting = InputIndicatorOpacity(background: 0.8, text: 0.4)
        indicator.setOpacity(setting)
        XCTAssertEqual(panel.alphaValue, 1, "Whole-panel alpha must not multiply the independent values")
        try assertAppearance(view, background: 0.8, text: 0.4)
        XCTAssertEqual(indicator.opacity, setting)
        XCTAssertEqual(InputIndicatorOpacity(defaults: defaults), setting)
        XCTAssertFalse(panel.isVisible)
        XCTAssertFalse(indicator.isVisible)
        XCTAssertFalse(indicator.followsCaret)
        XCTAssertEqual(panel.frame, initialFrame)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertFalse(panel.isOpaque)
        XCTAssertFalse(panel.hasShadow)
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
    }

    @MainActor
    func testMenuReflectsBothSavedValuesWithoutFiringAChange() throws {
        var changes: [InputIndicatorOpacity] = []
        let menu = InputIndicatorOpacityMenu(opacity: InputIndicatorOpacity(background: 0.25, text: 0.6)) { changes.append($0) }
        let view = try XCTUnwrap(menu.item.submenu?.items.first?.view)
        let background = try slider(in: view, identifier: "background-opacity")
        let text = try slider(in: view, identifier: "text-opacity")
        let preview = try XCTUnwrap(view.subviews.compactMap { $0 as? InputIndicatorView }.first)
        XCTAssertEqual(menu.item.title, "浮標不透明度")
        XCTAssertEqual(background.doubleValue, 25)
        XCTAssertEqual(background.minValue, 0)
        XCTAssertEqual(text.doubleValue, 60)
        XCTAssertEqual(text.minValue, 20)
        for slider in [background, text] {
            XCTAssertEqual(slider.maxValue, 100)
            XCTAssertTrue(slider.isContinuous)
            XCTAssertNotNil(slider.accessibilityLabel())
        }
        try assertAppearance(preview, background: 0.25, text: 0.6)
        XCTAssertTrue(changes.isEmpty)
        menu.update(InputIndicatorOpacity(background: 0.5, text: 0.3))
        XCTAssertEqual(background.doubleValue, 50)
        XCTAssertEqual(text.doubleValue, 30)
        try assertAppearance(preview, background: 0.5, text: 0.3)
        XCTAssertTrue(changes.isEmpty)
    }

    @MainActor
    func testEachSliderUpdatesOnlyItsValueInPreviewAndSavedSettings() throws {
        _ = NSApplication.shared
        let suite = "CapsStateKeeperTests.OpacityMenu.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let menu = InputIndicatorOpacityMenu(opacity: InputIndicatorOpacity()) {
            $0.save(to: defaults)
        }
        let view = try XCTUnwrap(menu.item.submenu?.items.first?.view)
        let background = try slider(in: view, identifier: "background-opacity")
        let text = try slider(in: view, identifier: "text-opacity")
        let preview = try XCTUnwrap(view.subviews.compactMap { $0 as? InputIndicatorView }.first)
        background.doubleValue = 45.4
        XCTAssertTrue(background.sendAction(background.action, to: background.target))
        XCTAssertEqual(InputIndicatorOpacity(defaults: defaults), InputIndicatorOpacity(background: 0.45, text: 1))
        try assertAppearance(preview, background: 0.45, text: 1)
        text.doubleValue = 70.6
        XCTAssertTrue(text.sendAction(text.action, to: text.target))
        XCTAssertEqual(InputIndicatorOpacity(defaults: defaults), InputIndicatorOpacity(background: 0.45, text: 0.71))
        try assertAppearance(preview, background: 0.45, text: 0.71)
        background.doubleValue = 0
        XCTAssertTrue(background.sendAction(background.action, to: background.target))
        XCTAssertEqual(InputIndicatorOpacity(defaults: defaults), InputIndicatorOpacity(background: 0, text: 0.71))
        try assertAppearance(preview, background: 0, text: 0.71)
        let labels = view.subviews.compactMap { $0 as? NSTextField }
        XCTAssertTrue(labels.contains { $0.stringValue == "背景不透明度：0%" })
        XCTAssertTrue(labels.contains { $0.stringValue == "文字不透明度：71%" })
        XCTAssertTrue(labels.allSatisfy { $0.frame.width >= ceil($0.intrinsicContentSize.width) })
        XCTAssertNil(view.window, "Menu tests must not open a live menu or indicator")
    }

    @MainActor
    func testResetActionRestoresHollowBackgroundAndFullTextOpacity() throws {
        _ = NSApplication.shared
        var applied: InputIndicatorOpacity?
        let menu = InputIndicatorOpacityMenu(opacity: InputIndicatorOpacity(background: 1, text: 0.2)) { applied = $0 }
        let reset = try XCTUnwrap(menu.item.submenu?.items.last)
        XCTAssertEqual(reset.title, "重設：背景 0%／文字 100%")
        XCTAssertTrue(NSApplication.shared.sendAction(try XCTUnwrap(reset.action), to: reset.target, from: reset))
        XCTAssertEqual(applied, InputIndicatorOpacity())
        let view = try XCTUnwrap(menu.item.submenu?.items.first?.view)
        let preview = try XCTUnwrap(view.subviews.compactMap { $0 as? InputIndicatorView }.first)
        try assertAppearance(preview, background: 0, text: 1)
    }

    @MainActor
    private func slider(in view: NSView, identifier: String) throws -> NSSlider {
        try XCTUnwrap(view.subviews.compactMap { $0 as? NSSlider }.first {
            $0.identifier?.rawValue == identifier
        })
    }

    @MainActor
    private func assertAppearance(_ view: InputIndicatorView, background: Double, text: Double,
                                  file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(view.alphaValue, 1, file: file, line: line)
        XCTAssertEqual(try XCTUnwrap(view.layer?.backgroundColor).alpha, background, accuracy: 0.001, file: file, line: line)
        let labels = view.subviews.compactMap { $0 as? NSTextField }
        XCTAssertEqual(labels.count, 5, file: file, line: line)
        for label in labels {
            XCTAssertEqual(label.alphaValue, text, accuracy: 0.001, file: file, line: line)
        }
    }
}
