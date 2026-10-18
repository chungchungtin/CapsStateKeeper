import AppKit
import CapsStateCore
import XCTest
@testable import CapsStateUI

final class InputIndicatorViewTests: XCTestCase {
    @MainActor
    func testBackgroundAndTextRenderIndependentlyInBothAppearances() throws {
        for appearanceName: NSAppearance.Name in [.aqua, .darkAqua] {
            let view = InputIndicatorView()
            view.appearance = NSAppearance(named: appearanceName)
            view.update(status(id: "com.apple.inputmethod.TCIM.Zhuyin", name: "Zhuyin - Traditional"))
            view.layoutSubtreeIfNeeded()
            for setting in [InputIndicatorOpacity(background: 0.4, text: 1),
                            InputIndicatorOpacity(background: 0.4, text: 0.2),
                            InputIndicatorOpacity(background: 1, text: 0.2),
                            InputIndicatorOpacity(background: 0, text: 0.2)] {
                view.updateOpacity(setting)
                XCTAssertEqual(view.alphaValue, 1)
                XCTAssertEqual(try XCTUnwrap(view.layer?.backgroundColor).alpha, setting.background, accuracy: 0.001)
                for label in labels(in: view) {
                    XCTAssertEqual(label.alphaValue, setting.text, accuracy: 0.001)
                }
                let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                view.cacheDisplay(in: view.bounds, to: bitmap)
                let x = Int(100 * CGFloat(bitmap.pixelsWide) / view.bounds.width)
                let y = Int(6 * CGFloat(bitmap.pixelsHigh) / view.bounds.height)
                XCTAssertEqual(try XCTUnwrap(bitmap.colorAt(x: x, y: y)).alphaComponent,
                               setting.background, accuracy: 0.02)
            }
        }
    }

    @MainActor
    func testOpacitySurvivesStatusHintAndAppearanceChanges() throws {
        let view = InputIndicatorView()
        view.updateOpacity(InputIndicatorOpacity(background: 0.35, text: 0.65))
        view.update(status(id: "com.apple.inputmethod.TCIM.Zhuyin", name: "Zhuyin - Traditional"))
        view.updatePositionHint("輸入框旁")
        view.appearance = NSAppearance(named: .darkAqua)
        view.viewDidChangeEffectiveAppearance()
        XCTAssertEqual(try XCTUnwrap(view.layer?.backgroundColor).alpha, 0.35, accuracy: 0.001)
        XCTAssertTrue(labels(in: view).allSatisfy { abs($0.alphaValue - 0.65) < 0.001 })
        XCTAssertEqual(try XCTUnwrap(view.layer?.borderColor).alpha, 0.28 * 0.65, accuracy: 0.001)
    }

    @MainActor
    func testHollowBackgroundHasNoFillOrBlurInLightAndDarkAppearances() throws {
        for appearanceName: NSAppearance.Name in [.aqua, .darkAqua] {
            let view = InputIndicatorView()
            view.appearance = NSAppearance(named: appearanceName)
            view.update(status(id: "com.apple.inputmethod.TCIM.Zhuyin", name: "Zhuyin - Traditional"))
            view.layoutSubtreeIfNeeded()
            XCTAssertFalse(view.isOpaque)
            XCTAssertEqual(view.alphaValue, 1)
            XCTAssertEqual(try XCTUnwrap(view.layer?.backgroundColor).alpha, 0)
            XCTAssertFalse(descendants(of: view).contains { $0 is NSVisualEffectView })
            XCTAssertTrue(labels(in: view).allSatisfy { !$0.drawsBackground })

            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            // Empty interior and the language tile must reveal the content
            // underneath, not just replace the old background with a pale fill.
            for point in [CGPoint(x: 100, y: 6), CGPoint(x: 30, y: 13)] {
                let x = Int(point.x * CGFloat(bitmap.pixelsWide) / view.bounds.width)
                let y = Int(point.y * CGFloat(bitmap.pixelsHigh) / view.bounds.height)
                XCTAssertLessThan(try XCTUnwrap(bitmap.colorAt(x: x, y: y)).alphaComponent, 0.02)
            }
        }
    }

    @MainActor
    func testTextKeepsItsFillAndContrastOutlineAfterStatusAndHintChanges() throws {
        let view = InputIndicatorView()
        view.update(status(id: "com.apple.inputmethod.TCIM.Zhuyin", name: "Zhuyin - Traditional"))
        view.updatePositionHint("輸入框旁")
        for label in labels(in: view) {
            let attributes = label.attributedStringValue.attributes(at: 0, effectiveRange: nil)
            XCTAssertLessThan(try XCTUnwrap(attributes[.strokeWidth] as? Double), 0)
            XCTAssertNotNil(attributes[.strokeColor])
            XCTAssertNotNil(attributes[.foregroundColor])
            XCTAssertNotNil(attributes[.font])
        }
    }

    @MainActor
    func testZhuyinIsCompleteAtTheOriginalCompactSize() throws {
        let view = InputIndicatorView()
        view.update(status(id: "com.apple.inputmethod.TCIM.Zhuyin", name: "Zhuyin - Traditional"))
        view.layoutSubtreeIfNeeded()
        let name = try XCTUnwrap(labels(in: view).first { $0.stringValue == "注音" })
        XCTAssertGreaterThanOrEqual(name.frame.width, ceil(name.intrinsicContentSize.width))
        XCTAssertEqual(view.preferredSize, InputIndicatorView.indicatorSize)
        XCTAssertFalse(labels(in: view).contains { $0.stringValue.contains("Zhuyin") })
    }

    @MainActor
    func testLongSourceExpandsWithoutShrinkingTextOrOverlappingCase() throws {
        let view = InputIndicatorView()
        let fullName = "My Custom Zhuyin Input Method"
        view.update(status(id: "third.party.Zhuyin", name: fullName))
        view.layoutSubtreeIfNeeded()
        let name = try XCTUnwrap(labels(in: view).first { $0.stringValue == fullName })
        let letterCase = try XCTUnwrap(labels(in: view).first { $0.stringValue == "abc" })
        XCTAssertGreaterThan(view.preferredSize.width, InputIndicatorView.indicatorSize.width)
        XCTAssertEqual(view.frame.size, view.preferredSize)
        XCTAssertEqual(view.intrinsicContentSize, view.preferredSize)
        XCTAssertGreaterThanOrEqual(name.frame.width, ceil(name.intrinsicContentSize.width))
        XCTAssertEqual(name.font?.pointSize, 13)
        XCTAssertGreaterThan(letterCase.frame.minX, name.frame.maxX)
        XCTAssertLessThanOrEqual(letterCase.frame.maxX, view.bounds.maxX - 8)
    }

    @MainActor
    func testSwitchingBackToABCRecoversCompactSize() {
        let view = InputIndicatorView()
        view.update(status(id: "custom", name: "A Very Long Input Method Name"))
        XCTAssertGreaterThan(view.preferredSize.width, InputIndicatorView.indicatorSize.width)
        view.update(status(id: "com.apple.keylayout.ABC", name: "ABC", languageCode: "en"))
        view.layoutSubtreeIfNeeded()
        XCTAssertEqual(view.preferredSize, InputIndicatorView.indicatorSize)
        XCTAssertEqual(view.frame.size, InputIndicatorView.indicatorSize)
    }

    @MainActor
    func testPositionHintAlsoFitsWithoutClipping() throws {
        let view = InputIndicatorView()
        view.update(status(id: "com.apple.keylayout.ABC", name: "ABC", languageCode: "en"))
        let hint = "需要允許輔助使用以取得游標位置"
        view.updatePositionHint(hint)
        view.layoutSubtreeIfNeeded()
        let label = try XCTUnwrap(labels(in: view).first { $0.stringValue == hint })
        XCTAssertGreaterThanOrEqual(label.frame.width, ceil(label.intrinsicContentSize.width))
        view.updatePositionHint(nil)
        XCTAssertEqual(view.preferredSize, InputIndicatorView.indicatorSize)
    }

    @MainActor
    private func descendants(of view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }

    @MainActor
    private func labels(in view: NSView) -> [NSTextField] {
        view.subviews.flatMap { child in
            (child as? NSTextField).map { [$0] } ?? labels(in: child)
        }
    }

    private func status(id: String, name: String, languageCode: String = "zh-Hant") -> TypingStatus {
        TypingStatus(source: TypingInputSource(id: id, name: name, languageCode: languageCode),
                     capsLock: false, shift: false, isUppercase: false)
    }
}
