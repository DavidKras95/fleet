import XCTest
@testable import Fleet

/// ⌘W is a smart close (Ghostty/iTerm behavior): it closes the focused pane
/// when a tab is split, and the whole tab only when one pane is left.
final class PaneActionTests: XCTestCase {
    func testSinglePaneClosesTheWholeTab() {
        XCTAssertEqual(PaneAction.close(paneCount: 1), .tab)
    }

    func testMultiplePanesCloseJustTheFocusedPane() {
        XCTAssertEqual(PaneAction.close(paneCount: 2), .pane)
        XCTAssertEqual(PaneAction.close(paneCount: 4), .pane)
    }

    func testZeroOrGarbagePaneCountFallsBackToTab() {
        // A failed/empty tmux query must not orphan a pane; closing the tab is safe.
        XCTAssertEqual(PaneAction.close(paneCount: 0), .tab)
        XCTAssertEqual(PaneAction.close(paneCount: -3), .tab)
    }
}
