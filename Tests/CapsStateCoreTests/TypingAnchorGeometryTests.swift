import XCTest
import CoreGraphics
@testable import CapsStateCore

final class TypingAnchorGeometryTests: XCTestCase {
    private let window = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    private let field = CGRect(x: 400, y: 960, width: 700, height: 80)

    func testZeroWidthCaretInsideComposerIsValid() {
        XCTAssertTrue(TypingAnchorGeometry.validCaret(
            CGRect(x: 500, y: 980, width: 0, height: 18), field: field, window: window))
    }

    func testStaleCaretFromOtherWindowIsRejected() {
        XCTAssertFalse(TypingAnchorGeometry.validCaret(
            CGRect(x: 2500, y: 980, width: 0, height: 18), field: field, window: window))
    }

    func testCaretOutsideFocusedFieldIsRejected() {
        XCTAssertFalse(TypingAnchorGeometry.validCaret(
            CGRect(x: 500, y: 100, width: 1, height: 18), field: field, window: window))
    }

    func testInvalidAndNonTextRectanglesAreRejected() {
        for rect in [CGRect.zero, CGRect.infinite,
                     CGRect(x: 500, y: 980, width: 700, height: 900)] {
            XCTAssertFalse(TypingAnchorGeometry.validCaret(rect, field: nil, window: window))
        }
        XCTAssertFalse(TypingAnchorGeometry.validField(.infinite, window: window))
        XCTAssertFalse(TypingAnchorGeometry.validField(.zero, window: window))
    }

    func testCaretOnNegativeCoordinateDisplayIsValid() {
        let secondDisplay = CGRect(x: -1200, y: -900, width: 1200, height: 900)
        XCTAssertTrue(TypingAnchorGeometry.validCaret(
            CGRect(x: -600, y: -100, width: 0, height: 18), field: nil, window: secondDisplay))
    }
}
