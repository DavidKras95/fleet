import XCTest
@testable import Fleet

/// Two commands must never quietly share a shortcut. The store surfaces
/// conflicts so the settings UI can warn instead of one command silently
/// shadowing another.
final class KeybindingConflictTests: XCTestCase {
    private func combo(_ key: String, _ mods: Set<KeyMod>) -> KeyCombo {
        KeyCombo(key: key, modifiers: mods)
    }

    func testNoConflictWhenAllUnique() {
        let map: [String: KeyCombo] = [
            "a": combo("d", [.command]),
            "b": combo("d", [.command, .shift]),
        ]
        XCTAssertTrue(KeybindingConflicts.duplicated(in: map).isEmpty)
    }

    func testDetectsSharedCombo() {
        let shared = combo("d", [.command])
        let map: [String: KeyCombo] = ["a": shared, "b": shared, "c": combo("t", [.command])]
        let dupes = KeybindingConflicts.duplicated(in: map)
        XCTAssertEqual(dupes, [shared.serialized])
    }

    func testDefaultsHaveNoConflicts() {
        // The shipped defaults must be internally consistent.
        var map: [String: KeyCombo] = [:]
        for cmd in AppCommand.allCases {
            if let c = cmd.defaultCombo { map[cmd.rawValue] = c }
        }
        XCTAssertTrue(KeybindingConflicts.duplicated(in: map).isEmpty,
                      "shipped default shortcuts conflict: \(KeybindingConflicts.duplicated(in: map))")
    }

    func testFlagsKnownReservedSystemCombo() {
        // Pinned to the fallback set: the default (no set) reads the LIVE
        // machine's hotkey table, which differs per machine by design.
        let fallback = KeybindingConflicts.fallbackReserved
        XCTAssertTrue(KeybindingConflicts.isReserved(combo("space", [.command]), in: fallback))
        XCTAssertFalse(KeybindingConflicts.isReserved(combo("d", [.command]), in: fallback))
    }
}
