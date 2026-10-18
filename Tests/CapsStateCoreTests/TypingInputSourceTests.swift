import XCTest
@testable import CapsStateCore

final class TypingInputSourceTests: XCTestCase {
    func testBuiltInZhuyinUsesChineseDisplayNameAndPreservesOriginalMetadata() {
        let source = TypingInputSource(id: "com.apple.inputmethod.TCIM.Zhuyin",
                                       name: "Zhuyin - Traditional", languageCode: "zh-Hant")
        XCTAssertEqual(source.displayName, "注音")
        XCTAssertEqual(source.name, "Zhuyin - Traditional")
        XCTAssertEqual(source.id, "com.apple.inputmethod.TCIM.Zhuyin")
        let status = TypingStatus(source: source, capsLock: false, shift: false, isUppercase: false)
        XCTAssertTrue(status.accessibilityDescription.contains("注音"))
        XCTAssertFalse(status.accessibilityDescription.contains("Zhuyin"))
    }

    func testUnknownSourcesKeepTheirCompleteNames() {
        for (id, name) in [("com.apple.keylayout.ABC", "ABC"),
                           ("third.party.Zhuyin", "My Custom Zhuyin Input Method")] {
            let source = TypingInputSource(id: id, name: name, languageCode: "zh-Hant")
            XCTAssertEqual(source.displayName, name)
        }
    }
}
