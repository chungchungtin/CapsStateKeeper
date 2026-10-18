import XCTest
import CoreGraphics
@testable import CapsStateCore

final class FloatingIndicatorPlacementTests: XCTestCase {
    private let size = CGSize(width: 184, height: 56)
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    func testIndicatorStaysBesideBottomComposerNotWindowCorner() {
        let field = CGRect(x: 300, y: 45, width: 500, height: 60)
        let caret = CGRect(x: 390, y: 76, width: 0, height: 18)
        let result = FloatingIndicatorPlacement.frame(size: size, caret: caret, field: field,
                                                      pointer: CGPoint(x: 1300, y: 850), visibleScreen: screen)
        XCTAssertTrue(screen.contains(result))
        XCTAssertEqual(result.minX, caret.maxX + 12)
        XCTAssertEqual(result.minY, caret.maxY + 12)
        XCTAssertLessThan(result.maxY, 200)
    }

    func testMissingCaretFallsBackToInputBoxNotWholeWindow() {
        let field = CGRect(x: 300, y: 45, width: 500, height: 60)
        let result = FloatingIndicatorPlacement.frame(size: size, caret: nil, field: field,
                                                      pointer: CGPoint(x: 1300, y: 850), visibleScreen: screen)
        XCTAssertEqual(result.minX, field.minX + 12)
        XCTAssertEqual(result.minY, field.maxY + 10)
        XCTAssertTrue(screen.contains(result))
    }

    func testFullScreenWindowAndCaretNearEdgesStayVisible() {
        for caret in [CGRect(x: 1438, y: 880, width: 1, height: 18), CGRect(x: 0, y: 0, width: 1, height: 18)] {
            let result = FloatingIndicatorPlacement.frame(size: size, caret: caret, field: nil,
                                                          pointer: .zero, visibleScreen: screen)
            XCTAssertTrue(screen.contains(result))
            XCTAssertFalse(result.intersects(caret))
        }
    }

    func testQuartzConversionHandlesDisplayBelowAndLeftOfPrimary() {
        let quartz = CGRect(x: -900, y: 900, width: 800, height: 500)
        let appKit = FloatingIndicatorPlacement.appKitRect(from: quartz, primaryDisplayTop: 900)
        XCTAssertEqual(appKit, CGRect(x: -900, y: -500, width: 800, height: 500))
        let secondScreen = CGRect(x: -1000, y: -900, width: 1000, height: 900)
        let result = FloatingIndicatorPlacement.frame(size: size, caret: nil, field: appKit,
                                                      pointer: .zero, visibleScreen: secondScreen)
        XCTAssertTrue(secondScreen.contains(result))
    }

    func testUnknownFocusUsesPointerAndClampsOversizedIndicator() {
        let pointer = CGPoint(x: 400, y: 60)
        let result = FloatingIndicatorPlacement.frame(size: size, caret: nil, field: nil,
                                                      pointer: pointer, visibleScreen: screen)
        XCTAssertEqual(result.origin, CGPoint(x: 416, y: 76))
        let tiny = CGRect(x: 2000, y: 1500, width: 160, height: 70)
        let tinyResult = FloatingIndicatorPlacement.frame(size: size, caret: nil, field: nil,
                                                          pointer: .zero, visibleScreen: tiny)
        XCTAssertTrue(tiny.contains(tinyResult))
    }

    func testFieldAtTopUsesSpaceBelow() {
        let field = CGRect(x: 400, y: 800, width: 300, height: 50)
        let result = FloatingIndicatorPlacement.frame(size: size, caret: nil, field: field,
                                                      pointer: .zero, visibleScreen: screen)
        XCTAssertEqual(result.maxY, field.minY - 10)
        XCTAssertFalse(result.intersects(field))
    }

    func testPointerNearTopRightRemainsVisibleAndDoesNotCoverPointer() {
        let pointer = CGPoint(x: 1435, y: 895)
        let result = FloatingIndicatorPlacement.frame(size: size, caret: nil, field: nil,
                                                      pointer: pointer, visibleScreen: screen)
        XCTAssertTrue(screen.contains(result))
        XCTAssertFalse(result.contains(pointer))
    }
}
