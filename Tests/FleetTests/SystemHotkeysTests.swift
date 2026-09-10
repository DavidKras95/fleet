import XCTest
@testable import Fleet

/// Parses macOS's own hotkey table (com.apple.symbolichotkeys.plist) so
/// "reserved by macOS" warnings reflect the user's REAL settings — e.g. a
/// disabled Spotlight means ⌘Space is actually free on that machine.
final class SystemHotkeysTests: XCTestCase {
    /// parameters: [asciiChar (65535 = none), keyCode, modifierMask]
    private func entry(enabled: Bool, ascii: Int, keyCode: Int, mods: Int) -> [String: Any] {
        ["enabled": enabled, "value": ["parameters": [ascii, keyCode, mods], "type": "standard"]]
    }

    func testEnabledHotkeyIsReserved() {
        // ⌘Space via keyCode 49 (space has no ascii in the table).
        let root = ["64": entry(enabled: true, ascii: 65535, keyCode: 49, mods: 1_048_576)]
        let reserved = SystemHotkeys.reservedCombos(fromHotkeyTable: root)
        XCTAssertTrue(reserved.contains(KeyCombo(key: "space", modifiers: [.command]).serialized))
    }

    func testDisabledHotkeyIsNotReserved() {
        // The whole point: Spotlight turned off means ⌘Space is free.
        let root = ["64": entry(enabled: false, ascii: 65535, keyCode: 49, mods: 1_048_576)]
        XCTAssertTrue(SystemHotkeys.reservedCombos(fromHotkeyTable: root).isEmpty)
    }

    func testCharacterKeyComesFromAsciiParameter() {
        // Screenshot ⇧⌘4: ascii 52 = "4", modifier mask = shift+command.
        let root = ["30": entry(enabled: true, ascii: 52, keyCode: 21, mods: 1_179_648)]
        let reserved = SystemHotkeys.reservedCombos(fromHotkeyTable: root)
        XCTAssertTrue(reserved.contains(KeyCombo(key: "4", modifiers: [.shift, .command]).serialized))
    }

    func testArrowKeyComesFromKeyCode() {
        // Mission Control "move left a space": ⌃← (keyCode 123, control mask).
        let root = ["79": entry(enabled: true, ascii: 65535, keyCode: 123, mods: 262_144)]
        let reserved = SystemHotkeys.reservedCombos(fromHotkeyTable: root)
        XCTAssertTrue(reserved.contains(KeyCombo(key: "left", modifiers: [.control]).serialized))
    }

    func testUnrepresentableKeysAreSkippedNotCrashed() {
        // F11 (keyCode 103) can't be recorded in Fleet anyway — skip quietly.
        let root = ["52": entry(enabled: true, ascii: 65535, keyCode: 103, mods: 0)]
        XCTAssertTrue(SystemHotkeys.reservedCombos(fromHotkeyTable: root).isEmpty)
    }

    func testAcceptsPlistRootWrappedInAppleSymbolicHotKeys() {
        // The real file nests the table under "AppleSymbolicHotKeys".
        let wrapped: [String: Any] =
            ["AppleSymbolicHotKeys": ["64": entry(enabled: true, ascii: 65535, keyCode: 49, mods: 1_048_576)]]
        let reserved = SystemHotkeys.reservedCombos(fromHotkeyTable: wrapped)
        XCTAssertTrue(reserved.contains(KeyCombo(key: "space", modifiers: [.command]).serialized))
    }

    func testGarbageEntriesAreIgnored() {
        let root: [String: Any] = ["64": "not a dict", "65": ["enabled": true]]
        XCTAssertTrue(SystemHotkeys.reservedCombos(fromHotkeyTable: root).isEmpty)
    }
}
