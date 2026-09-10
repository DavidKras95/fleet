import XCTest
@testable import Fleet

/// A friend's Mac may lack tmux or the claude CLI. Fleet must say so clearly
/// instead of showing an empty, silent sidebar.
final class PreflightTests: XCTestCase {
    func testNoIssuesWhenEverythingPresent() {
        XCTAssertTrue(Preflight.issues(tmuxAvailable: true, claudeAvailable: true).isEmpty)
    }

    func testFlagsMissingTmux() {
        let issues = Preflight.issues(tmuxAvailable: false, claudeAvailable: true)
        XCTAssertEqual(issues.map(\.id), ["tmux"])
    }

    func testFlagsMissingClaude() {
        let issues = Preflight.issues(tmuxAvailable: true, claudeAvailable: false)
        XCTAssertEqual(issues.map(\.id), ["claude"])
    }

    func testFlagsBothMissingTmuxFirst() {
        // tmux is the engine — surface it first.
        let issues = Preflight.issues(tmuxAvailable: false, claudeAvailable: false)
        XCTAssertEqual(issues.map(\.id), ["tmux", "claude"])
    }

    func testEachIssueHasAFixHint() {
        for issue in Preflight.issues(tmuxAvailable: false, claudeAvailable: false) {
            XCTAssertFalse(issue.title.isEmpty)
            XCTAssertFalse(issue.fix.isEmpty)
        }
    }
}
