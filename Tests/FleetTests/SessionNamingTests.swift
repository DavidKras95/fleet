import XCTest
@testable import Fleet

/// Regression: a second session in the same repo used to be named a bare
/// "2", and spawning the same repo twice used to silently jump to the old
/// session instead of creating a new one.
final class SessionNamingTests: XCTestCase {
    func testFirstSessionWithNoTaskUsesBareRepoName() {
        let task = SessionNaming.uniqueTask(repo: "my-app", desired: "", existing: [])
        XCTAssertEqual(task, "")
    }

    func testSecondSessionWithNoTaskIsNamedSessionTwoNotBareNumber() {
        let task = SessionNaming.uniqueTask(repo: "my-app", desired: "", existing: ["my-app"])
        XCTAssertEqual(task, "session-2")
    }

    func testRepeatedBlankSpawnsKeepCounting() {
        let task = SessionNaming.uniqueTask(
            repo: "my-app", desired: "", existing: ["my-app", "my-app/session-2"])
        XCTAssertEqual(task, "session-3")
    }

    func testExplicitTaskIsKeptWhenFree() {
        let task = SessionNaming.uniqueTask(repo: "my-app", desired: "fix-auth", existing: ["my-app"])
        XCTAssertEqual(task, "fix-auth")
    }

    func testExplicitTaskCollisionGetsNumericSuffix() {
        let task = SessionNaming.uniqueTask(
            repo: "my-app", desired: "fix-auth", existing: ["my-app/fix-auth"])
        XCTAssertEqual(task, "fix-auth-2")
    }

    func testRenamingToOwnCurrentNameIsNotACollision() {
        let task = SessionNaming.uniqueTask(
            repo: "my-app", desired: "session-2",
            existing: ["my-app", "my-app/session-2"],
            excluding: "my-app/session-2")
        XCTAssertEqual(task, "session-2")
    }

    func testRenamingOntoAnotherSessionsNameStillDedupes() {
        let task = SessionNaming.uniqueTask(
            repo: "my-app", desired: "session-3",
            existing: ["my-app/session-2", "my-app/session-3"],
            excluding: "my-app/session-2")
        XCTAssertEqual(task, "session-3-2")
    }

    // Regression: spawn() used to pass self.sessions (empty before the first
    // async poll) to uniqueTask, so a pre-existing "Fleet" session was invisible
    // and tmux.new-session would fail with a name collision.  spawn() now does
    // a fresh tmux list-sessions query; this test guards the naming logic that
    // consumes that result.
    func testSpawnDeduplicatesAgainstLiveListWhenCacheIsStale() {
        // Simulate: cached sessions = [], live tmux = ["Fleet"]
        let task = SessionNaming.uniqueTask(repo: "Fleet", desired: "", existing: ["Fleet"])
        XCTAssertEqual(task, "session-2", "must not attempt to create an already-existing session name")
    }

    func testSanitizeStripsTmuxForbiddenCharacters() {
        // tmux forbids ':' and '.' in session names.
        XCTAssertEqual(SessionNaming.sanitize("  fix: v1.2 "), "fix- v1-2")
    }

    // A session can be started in any folder the user picks, so the base name
    // is derived from a path — and must be tmux-safe.
    func testBaseNameFromPath() {
        XCTAssertEqual(SessionNaming.baseName(forDirectory: "/Users/x/git/EE"), "EE")
    }

    func testBaseNameStripsTrailingSlash() {
        XCTAssertEqual(SessionNaming.baseName(forDirectory: "/Users/x/git/EE/"), "EE")
    }

    func testBaseNameSanitizesForbiddenCharacters() {
        // A folder named "my.app" would otherwise make an illegal tmux name.
        XCTAssertEqual(SessionNaming.baseName(forDirectory: "/Users/x/my.app"), "my-app")
    }

    func testBaseNameFallsBackWhenEmptyOrRoot() {
        XCTAssertEqual(SessionNaming.baseName(forDirectory: "/"), "session")
        XCTAssertEqual(SessionNaming.baseName(forDirectory: ""), "session")
    }
}
