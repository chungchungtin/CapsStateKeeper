import AppKit
import XCTest
@testable import CapsStateSystem

final class KeyboardModifierObserverTests: XCTestCase {
    func testRegularTypingIncludingShiftAndOptionWakesIndicator() {
        for flags: NSEvent.ModifierFlags in [[], .shift, .capsLock, .option,
                                             [.shift, .option], .numericPad] {
            XCTAssertTrue(KeyboardModifierObserver.countsAsTyping(type: .keyDown, modifiers: flags))
        }
    }

    func testCommandControlAndFunctionShortcutsDoNotWakeIndicator() {
        for flags: NSEvent.ModifierFlags in [.command, .control, .function,
                                             [.command, .shift], [.control, .option]] {
            XCTAssertFalse(KeyboardModifierObserver.countsAsTyping(type: .keyDown, modifiers: flags))
        }
    }

    func testModifierChangesAndKeyReleasesDoNotExtendActivity() {
        for type: NSEvent.EventType in [.flagsChanged, .keyUp] {
            XCTAssertFalse(KeyboardModifierObserver.countsAsTyping(type: type, modifiers: []))
            XCTAssertFalse(KeyboardModifierObserver.countsAsTyping(type: type, modifiers: .capsLock))
            XCTAssertFalse(KeyboardModifierObserver.countsAsTyping(type: type, modifiers: .shift))
        }
    }

    func testMouseMovementClickAndScrollCannotWakeIndicator() {
        for type: NSEvent.EventType in [.mouseMoved, .leftMouseDown, .leftMouseUp,
                                        .rightMouseDown, .scrollWheel, .leftMouseDragged] {
            XCTAssertFalse(KeyboardModifierObserver.countsAsTyping(type: type, modifiers: []))
        }
    }
}
