import XCTest
@testable import Fleet

/// A friend's Mac may lack tmux or the claude CLI. Fleet must say so clearly
/// instead of showing an empty, silent sidebar.
final class PreflightTests: XCTestCase {
    func testNoIssuesWhenEverythingPresent() {
        XCTAssertTrue(Preflight.issues(tmuxAvailable: true, jqAvailable: true, claudeAvailable: true, brewAvailable: true).isEmpty)
    }

    func testFlagsMissingTmux() {
        let issues = Preflight.issues(tmuxAvailable: false, jqAvailable: true, claudeAvailable: true, brewAvailable: true)
        XCTAssertEqual(issues.map(\.id), ["tmux"])
    }

    func testFlagsMissingJq() {
        let issues = Preflight.issues(tmuxAvailable: true, jqAvailable: false, claudeAvailable: true, brewAvailable: true)
        XCTAssertEqual(issues.map(\.id), ["jq"])
    }

    func testFlagsMissingClaude() {
        let issues = Preflight.issues(tmuxAvailable: true, jqAvailable: true, claudeAvailable: false, brewAvailable: true)
        XCTAssertEqual(issues.map(\.id), ["claude"])
    }

    func testFlagsBothMissingTmuxFirst() {
        // tmux is the engine — surface it first, then jq, then claude.
        let issues = Preflight.issues(tmuxAvailable: false, jqAvailable: false, claudeAvailable: false, brewAvailable: true)
        XCTAssertEqual(issues.map(\.id), ["tmux", "jq", "claude"])
    }

    func testEachIssueHasAFixHint() {
        for issue in Preflight.issues(tmuxAvailable: false, jqAvailable: false, claudeAvailable: false, brewAvailable: true) {
            XCTAssertFalse(issue.title.isEmpty)
            XCTAssertFalse(issue.fix.isEmpty)
        }
    }

    // Regression: when Homebrew is absent the fix text must guide the user to
    // install it first, not tell them to run `brew install` (which won't work).
    func testNoBrew_missingToolsPointToHomebrewInstall() {
        let issues = Preflight.issues(tmuxAvailable: false, jqAvailable: false, claudeAvailable: true, brewAvailable: false)
        for issue in issues where issue.id != "claude" {
            XCTAssertTrue(
                issue.fix.contains("brew.sh"),
                "fix for '\(issue.id)' must mention brew.sh when Homebrew is absent, got: \(issue.fix)")
        }
    }

    func testBrew_missingToolsDoNotMentionBrewSh() {
        // When brew is present Fleet auto-installs — no need to send the user to brew.sh.
        let issues = Preflight.issues(tmuxAvailable: false, jqAvailable: false, claudeAvailable: true, brewAvailable: true)
        for issue in issues {
            XCTAssertFalse(
                issue.fix.contains("brew.sh"),
                "fix for '\(issue.id)' should not mention brew.sh when Homebrew is present")
        }
    }
}
