import XCTest
@testable import Fleet

/// Reopening the app should land back on the session you were looking at.
/// These pin down the restore rule so a stale or vanished selection can
/// never leave you attached to a session that no longer exists.
final class SelectionRestoreTests: XCTestCase {
    func testRestoresStoredSelectionWhenItStillExists() {
        let s = SelectionRestore.resolve(
            current: nil, stored: "triage-agents",
            existing: ["frequency-cap-migration", "triage-agents"])
        XCTAssertEqual(s, "triage-agents")
    }

    func testDropsStoredSelectionWhenSessionIsGone() {
        // A session closed while the app was shut — don't try to attach to it.
        let s = SelectionRestore.resolve(
            current: nil, stored: "old-session", existing: ["triage-agents"])
        XCTAssertNil(s)
    }

    func testKeepsCurrentSelectionOverStored() {
        // The user already picked something this launch — never yank them off it.
        let s = SelectionRestore.resolve(
            current: "frequency-cap-migration", stored: "triage-agents",
            existing: ["frequency-cap-migration", "triage-agents"])
        XCTAssertEqual(s, "frequency-cap-migration")
    }

    func testNoStoredSelectionLeavesNothingSelected() {
        let s = SelectionRestore.resolve(current: nil, stored: nil, existing: ["a", "b"])
        XCTAssertNil(s)
    }

    func testCurrentSelectionThatVanishedIsCleared() {
        // The selected session was retired/killed — selection must clear.
        let s = SelectionRestore.resolve(current: "gone", stored: nil, existing: ["a"])
        XCTAssertNil(s)
    }
}
