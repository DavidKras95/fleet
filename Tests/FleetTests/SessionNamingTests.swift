import XCTest
@testable import Fleet

/// Regression: a second session in the same repo used to be named a bare
/// "2", and spawning the same repo twice used to silently jump to the old
/// session instead of creating a new one.
final class SessionNamingTests: XCTestCase {
    func testFirstSessionWithNoTaskUsesBareRepoName() {
        let task = SessionNaming.uniqueTask(repo: "kraken", desired: "", existing: [])
        XCTAssertEqual(task, "")
    }

    func testSecondSessionWithNoTaskIsNamedSessionTwoNotBareNumber() {
        let task = SessionNaming.uniqueTask(repo: "kraken", desired: "", existing: ["kraken"])
        XCTAssertEqual(task, "session-2")
    }

    func testRepeatedBlankSpawnsKeepCounting() {
        let task = SessionNaming.uniqueTask(
            repo: "kraken", desired: "", existing: ["kraken", "kraken/session-2"])
        XCTAssertEqual(task, "session-3")
    }

    func testExplicitTaskIsKeptWhenFree() {
        let task = SessionNaming.uniqueTask(repo: "kraken", desired: "fix-auth", existing: ["kraken"])
        XCTAssertEqual(task, "fix-auth")
    }

    func testExplicitTaskCollisionGetsNumericSuffix() {
        let task = SessionNaming.uniqueTask(
            repo: "kraken", desired: "fix-auth", existing: ["kraken/fix-auth"])
        XCTAssertEqual(task, "fix-auth-2")
    }

    func testRenamingToOwnCurrentNameIsNotACollision() {
        let task = SessionNaming.uniqueTask(
            repo: "kraken", desired: "session-2",
            existing: ["kraken", "kraken/session-2"],
            excluding: "kraken/session-2")
        XCTAssertEqual(task, "session-2")
    }

    func testRenamingOntoAnotherSessionsNameStillDedupes() {
        let task = SessionNaming.uniqueTask(
            repo: "kraken", desired: "session-3",
            existing: ["kraken/session-2", "kraken/session-3"],
            excluding: "kraken/session-2")
        XCTAssertEqual(task, "session-3-2")
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
