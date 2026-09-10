import XCTest
@testable import Fleet

/// Runs the REAL embedded hook script (the one Fleet installs into
/// ~/.claude/hooks) against fake Claude Code payloads, with HOME pointed at
/// a temp dir and no tmux pane — the background-agent code path. These pin
/// down every status mis-mapping we've shipped and fixed:
///   • idle reminder painted red   • informational notifications painted red
///   • status keyed by directory colliding between sibling sessions
final class HookScriptTests: XCTestCase {
    private var home: URL!
    private var script: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory
            .appendingPathComponent("fleet-hook-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        script = home.appendingPathComponent("hook.sh")
        try EnvironmentSetup.hookScript.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)

        let bin = home.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let stub = bin.appendingPathComponent("tmux")
        try "#!/bin/bash\nexit 1\n".write(to: stub, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: stub.path)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
    }

    @discardableResult
    private func run(_ event: String, payload: [String: Any],
                     extraEnv: [String: String] = [:]) throws -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [script.path, event]
        var env = ProcessInfo.processInfo.environment
        env["HOME"] = home.path
        env.removeValue(forKey: "TMUX")
        env.removeValue(forKey: "TMUX_PANE")
        // Shadow `tmux` with a failing stub so a fake TMUX_PANE never reaches
        // the real tmux server — tmux calls fail silently, as the script
        // expects; jq/osascript stay resolvable.
        env["PATH"] = home.appendingPathComponent("bin").path + ":" + (env["PATH"] ?? "/usr/bin:/bin")
        for (k, v) in extraEnv { env[k] = v }
        p.environment = env
        let stdin = Pipe()
        p.standardInput = stdin
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        try p.run()
        let data = try JSONSerialization.data(withJSONObject: payload)
        stdin.fileHandleForWriting.write(data)
        stdin.fileHandleForWriting.closeFile()
        p.waitUntilExit()
        return p.terminationStatus
    }

    private func sidState(_ sid: String) -> String? {
        try? String(contentsOf: home.appendingPathComponent(".cache/fleet/session-state/\(sid).state"),
                    encoding: .utf8)
    }

    private func cwdState(_ cwd: String) -> String? {
        let key = cwd.replacingOccurrences(of: "/", with: "_")
        return try? String(contentsOf: home.appendingPathComponent(".cache/fleet/cwd-state/\(key).state"),
                           encoding: .utf8)
    }

    private let base: [String: Any] = ["session_id": "S1", "cwd": "/w/repo"]

    func testBusyEventWritesBusy() throws {
        try run("busy", payload: base)
        XCTAssertEqual(sidState("S1"), "busy")
    }

    func testDoneEventWritesDone() throws {
        try run("done", payload: base)
        XCTAssertEqual(sidState("S1"), "done")
    }

    func testIdleReminderNotificationIsReadyNotRed() throws {
        // Regression: "Claude is waiting for your input" is an idle reminder,
        // it was being shown as a blocking red request.
        var p = base
        p["message"] = "Claude is waiting for your input"
        try run("input", payload: p)
        XCTAssertEqual(sidState("S1"), "done")
    }

    func testPermissionRequestIsRed() throws {
        var p = base
        p["message"] = "Claude needs your permission to use Bash"
        try run("input", payload: p)
        XCTAssertEqual(sidState("S1"), "input")
    }

    func testInformationalNotificationLeavesStateUntouched() throws {
        // Regression: "Background command … completed" flipped a working
        // agent to red.
        try run("busy", payload: base)
        var p = base
        p["message"] = "Background command \"npm test\" completed (exit code 0)"
        try run("input", payload: p)
        XCTAssertEqual(sidState("S1"), "busy")
    }

    func testEndEventClearsState() throws {
        try run("busy", payload: base)
        try run("end", payload: base)
        XCTAssertNil(sidState("S1"))
        XCTAssertNil(cwdState("/w/repo"))
    }

    func testTwoSessionsInSameDirectoryGetSeparateSessionIdFiles() throws {
        // Regression: sibling sessions in one folder shared a status.
        try run("busy", payload: ["session_id": "A", "cwd": "/w/repo"])
        try run("done", payload: ["session_id": "B", "cwd": "/w/repo"])
        XCTAssertEqual(sidState("A"), "busy")
        XCTAssertEqual(sidState("B"), "done")
    }

    func testAlsoWritesDirectoryFallbackForDaemonsWithoutPane() throws {
        try run("busy", payload: base)
        XCTAssertEqual(cwdState("/w/repo"), "busy")
    }

    func testPaneBackedSessionNeverWritesSharedDirectoryFile() throws {
        // Regression: a normal (tmux-pane) session in the same directory as a
        // detached daemon wrote the directory-keyed file too, so the idle
        // daemon's cube showed the sibling's "working" status.
        try run("busy", payload: base, extraEnv: ["TMUX": "/tmp/fake,1,0", "TMUX_PANE": "%99"])
        XCTAssertEqual(sidState("S1"), "busy", "pane sessions still get their precise file")
        XCTAssertNil(cwdState("/w/repo"), "directory file is reserved for no-pane daemons")
    }

    func testExitsCleanlyWithEmptyPayload() throws {
        // A hook that crashes would make Claude Code print errors on every event.
        XCTAssertEqual(try run("busy", payload: [:]), 0)
    }

    func testScriptHasValidBashSyntax() throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = ["-n", script.path]
        p.standardError = Pipe()
        try p.run()
        p.waitUntilExit()
        XCTAssertEqual(p.terminationStatus, 0)
    }
}
