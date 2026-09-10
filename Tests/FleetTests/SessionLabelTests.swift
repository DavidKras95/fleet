import XCTest
@testable import Fleet

/// Regression: every task-less session once rendered the same bold label
/// "main", making the sidebar unscannable. The bold title must always be
/// something that identifies THIS session.
final class SessionLabelTests: XCTestCase {
    func testSessionWithoutTaskUsesRepoAsTitle() {
        let s = AgentSession(name: "triage-agents", state: .idle)
        XCTAssertEqual(s.displayTitle, "triage-agents")
    }

    func testSessionWithoutTaskNeverShowsGenericPlaceholder() {
        for name in ["triage-agents", "EE", "frequency-cap-migration"] {
            let s = AgentSession(name: name, state: .idle)
            XCTAssertNotEqual(s.displayTitle, "main", "\(name) rendered as a generic label")
            XCTAssertFalse(s.displayTitle.isEmpty)
        }
    }

    func testSessionWithTaskUsesTaskAsTitle() {
        let s = AgentSession(name: "realtime-cdp-ingest/dlq-fix", state: .busy)
        XCTAssertEqual(s.displayTitle, "dlq-fix")
    }

    func testCaptionIsAlwaysTheRepo() {
        XCTAssertEqual(AgentSession(name: "EE", state: .idle).displayCaption, "EE")
        XCTAssertEqual(AgentSession(name: "EE/demo", state: .idle).displayCaption, "EE")
    }

    func testTwoTasklessSessionsInDifferentReposHaveDistinctTitles() {
        let a = AgentSession(name: "triage-agents", state: .idle)
        let b = AgentSession(name: "frequency-cap-migration", state: .idle)
        XCTAssertNotEqual(a.displayTitle, b.displayTitle)
    }
}
