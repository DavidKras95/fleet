import XCTest
@testable import Fleet

final class KeyComboTests: XCTestCase {
    func testSerializeRoundTrip() {
        let c = KeyCombo(key: "d", modifiers: [.command, .shift])
        XCTAssertEqual(KeyCombo(serialized: c.serialized), c)
    }

    func testSerializedIsStableRegardlessOfModifierOrder() {
        let a = KeyCombo(key: "d", modifiers: [.command, .shift])
        let b = KeyCombo(key: "d", modifiers: [.shift, .command])
        XCTAssertEqual(a.serialized, b.serialized)
    }

    func testDisplayUsesMacOrderControlOptionShiftCommand() {
        let c = KeyCombo(key: "d", modifiers: [.command, .control, .shift, .option])
        XCTAssertEqual(c.display, "⌃⌥⇧⌘D")
    }

    func testDisplaySymbolizesArrowsAndReturn() {
        XCTAssertEqual(KeyCombo(key: "left", modifiers: [.command, .option]).display, "⌥⌘←")
        XCTAssertEqual(KeyCombo(key: "return", modifiers: [.command]).display, "⌘↩")
        XCTAssertEqual(KeyCombo(key: "=", modifiers: [.command]).display, "⌘=")
    }

    func testParseRejectsGarbage() {
        XCTAssertNil(KeyCombo(serialized: ""))
        XCTAssertNil(KeyCombo(serialized: "command+"))
        XCTAssertNil(KeyCombo(serialized: "bogusmod+d"))
    }
}
