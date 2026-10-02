import XCTest
@testable import Fleet

/// The sidebar dot is computed from tmux pane data plus two fallback files.
/// These pin down the precedence rules — especially the regression where
/// two sessions in the same directory showed one shared status.
final class StatusResolverTests: XCTestCase {
    typealias State = AgentSession.State

    /// A tmux `list-panes` line: session \t @fleet_state \t cwd \t @fleet_sid
    private func line(_ session: String, state: String = "", cwd: String = "/r", sid: String = "") -> String {
        [session, state, cwd, sid].joined(separator: "\t")
    }

    private func resolve(_ lines: [String],
                         sid: [String: State] = [:],
                         cwd: [String: State] = [:],
                         ignored: Set<String> = [],
                         valid: Set<String>? = nil) -> [String: State] {
        StatusResolver.resolve(
            paneLines: lines,
            ignoredSessions: ignored,
            validSessions: valid,
            sessionIdState: { sid[$0] },
            cwdState: { cwd[$0] })
    }

    func testPaneStateIsUsedDirectly() {
        let r = resolve([line("a", state: "busy")])
        XCTAssertEqual(r["a"], .busy)
    }

    func testEmptyPaneStateWithNoFallbacksIsIdle() {
        XCTAssertEqual(resolve([line("a")])["a"], .idle)
    }

    func testPaneStateBeatsEveryFallback() {
        let r = resolve([line("a", state: "done", cwd: "/r", sid: "S")],
                        sid: ["S": .input], cwd: ["/r": .input])
        XCTAssertEqual(r["a"], .done, "a live pane state must never be overridden by a fallback file")
    }

    func testSessionIdFallbackUsedWhenPaneStateIsEmpty() {
        let r = resolve([line("a", cwd: "/r", sid: "S")], sid: ["S": .busy], cwd: ["/r": .input])
        XCTAssertEqual(r["a"], .busy, "session_id file is more precise than the directory file")
    }

    func testCwdFallbackOnlyWhenNoSessionIdLink() {
        let r = resolve([line("a", cwd: "/r")], cwd: ["/r": .input])
        XCTAssertEqual(r["a"], .input)
    }

    func testTwoSessionsInSameDirectoryKeepIndependentStatus() {
        // Regression: "the two sessions of the same directory share the same status".
        let r = resolve([
            line("repo", state: "", cwd: "/r", sid: "S1"),
            line("repo/session-2", state: "", cwd: "/r", sid: "S2"),
        ], sid: ["S1": .input, "S2": .busy], cwd: ["/r": .input])
        XCTAssertEqual(r["repo"], .input)
        XCTAssertEqual(r["repo/session-2"], .busy)
    }

    func testFreshSessionWithOwnPaneStateIgnoresSiblingsDirectoryFile() {
        let r = resolve([
            line("repo/session-2", state: "done", cwd: "/r"),
        ], cwd: ["/r": .input])
        XCTAssertEqual(r["repo/session-2"], .done)
    }

    func testMostUrgentPaneDefinesSessionState() {
        // Tabs: claude waiting in one window, plain shell in another.
        let r = resolve([
            line("a", state: "done"),
            line("a", state: "input"),
            line("a", state: ""),
        ])
        XCTAssertEqual(r["a"], .input)
    }

    func testIgnoredSessionsAreDropped() {
        let r = resolve([line("fleet", state: "busy"), line("a", state: "busy")], ignored: ["fleet"])
        XCTAssertNil(r["fleet"])
        XCTAssertEqual(r["a"], .busy)
    }

    func testUnknownStateStringIsTreatedAsIdle() {
        XCTAssertEqual(resolve([line("a", state: "garbage")])["a"], .idle)
    }

    func testGarbageMegaLineIsDroppedWhenNotAKnownSession() {
        // Regression (2026-09-02): after Cmd-Q the status query came back with
        // its tab separators collapsed, so a whole "name state path sid" line
        // became one bogus session name that then failed to attach. Cross-
        // checking against the real session list must reject it.
        let garbage = "fleet_busy_/Users/testuser/git/.worktrees/myapp/testMyApp_"
        let r = resolve([garbage, line("api-server", state: "done")],
                        valid: ["fleet", "api-server"])
        XCTAssertNil(r[garbage], "a name tmux doesn't actually have must never appear")
        XCTAssertEqual(r["api-server"], .done)
    }

    func testValidSessionsFiltersUnknownNames() {
        let r = resolve([line("a", state: "busy"), line("ghost", state: "busy")],
                        valid: ["a"])
        XCTAssertEqual(r["a"], .busy)
        XCTAssertNil(r["ghost"])
    }

    func testNilValidSessionsKeepsEveryName() {
        // Backward-compatible: no session list supplied → no filtering.
        let r = resolve([line("a", state: "busy")], valid: nil)
        XCTAssertEqual(r["a"], .busy)
    }

    func testStatePriorityOrderIsInputBusyDoneIdle() {
        XCTAssertLessThan(State.input.priority, State.busy.priority)
        XCTAssertLessThan(State.busy.priority, State.done.priority)
        XCTAssertLessThan(State.done.priority, State.idle.priority)
    }
}
