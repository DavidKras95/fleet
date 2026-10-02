import XCTest
@testable import Fleet

/// Reopening the app should land back on the session you were looking at.
/// These pin down the restore rule so a stale or vanished selection can
/// never leave you attached to a session that no longer exists.
final class SelectionRestoreTests: XCTestCase {
    func testRestoresStoredSelectionWhenItStillExists() {
        let s = SelectionRestore.resolve(
            current: nil, stored: "my-app",
            existing: ["api-server", "my-app"])
        XCTAssertEqual(s, "my-app")
    }

    func testDropsStoredSelectionWhenSessionIsGone() {
        // A session closed while the app was shut — don't try to attach to it.
        let s = SelectionRestore.resolve(
            current: nil, stored: "old-session", existing: ["my-app"])
        XCTAssertNil(s)
    }

    func testKeepsCurrentSelectionOverStored() {
        // The user already picked something this launch — never yank them off it.
        let s = SelectionRestore.resolve(
            current: "api-server", stored: "my-app",
            existing: ["api-server", "my-app"])
        XCTAssertEqual(s, "api-server")
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
