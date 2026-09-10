import XCTest
@testable import Fleet

/// Fleet configures its own environment on launch. That must be idempotent
/// and must never clobber hooks the user already has in settings.json.
final class EnvironmentSetupTests: XCTestCase {
    private var dir: URL!
    private var settings: String { dir.appendingPathComponent("settings.json").path }

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fleet-env-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func readHooks() throws -> [String: [[String: Any]]] {
        let data = try Data(contentsOf: URL(fileURLWithPath: settings))
        let root = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        return root["hooks"] as! [String: [[String: Any]]]
    }

    private func commands(_ hooks: [String: [[String: Any]]], _ event: String) -> [String] {
        (hooks[event] ?? []).flatMap { group in
            ((group["hooks"] as? [[String: Any]]) ?? []).compactMap { $0["command"] as? String }
        }
    }

    func testCreatesSettingsWithAllStatusEventsWhenMissing() throws {
        EnvironmentSetup.mergeClaudeHooks(settingsPath: settings)
        let hooks = try readHooks()
        for event in ["Notification", "UserPromptSubmit", "PreToolUse", "PostToolUse",
                      "Stop", "SessionEnd", "SessionStart"] {
            XCTAssertEqual(commands(hooks, event).filter { $0.contains("agent-tmux-status.sh") }.count, 1,
                           "\(event) should have exactly one status hook")
        }
    }

    func testRunningTwiceAddsNothing() throws {
        EnvironmentSetup.mergeClaudeHooks(settingsPath: settings)
        let first = try Data(contentsOf: URL(fileURLWithPath: settings))
        EnvironmentSetup.mergeClaudeHooks(settingsPath: settings)
        let second = try Data(contentsOf: URL(fileURLWithPath: settings))
        XCTAssertEqual(first, second, "second run must be a byte-identical no-op")
    }

    func testPreservesUsersExistingHooksAndSettings() throws {
        let existing: [String: Any] = [
            "model": "claude-fable-5",
            "hooks": [
                "PreToolUse": [[
                    "matcher": "Bash",
                    "hooks": [["type": "command", "command": "python3 ~/.claude/hooks/block-snowflake.py"]],
                ]],
            ],
        ]
        try JSONSerialization.data(withJSONObject: existing).write(to: URL(fileURLWithPath: settings))

        EnvironmentSetup.mergeClaudeHooks(settingsPath: settings)

        let data = try Data(contentsOf: URL(fileURLWithPath: settings))
        let root = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(root["model"] as? String, "claude-fable-5")
        let pre = commands(try readHooks(), "PreToolUse")
        XCTAssertTrue(pre.contains("python3 ~/.claude/hooks/block-snowflake.py"), "user hook was dropped")
        XCTAssertTrue(pre.contains { $0.contains("agent-tmux-status.sh busy") })
    }

    func testInstallsExecutableHookScript() throws {
        let path = dir.appendingPathComponent("hooks/agent-tmux-status.sh").path
        EnvironmentSetup.installHookScript(at: path)
        let attrs = try FileManager.default.attributesOfItem(atPath: path)
        let perms = attrs[.posixPermissions] as! Int
        XCTAssertEqual(perms & 0o111, 0o111, "hook must be executable")
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), EnvironmentSetup.hookScript)
    }

    func testTmuxConfigBlockIsAppendedOnceAndKeepsUserConfig() throws {
        let conf = dir.appendingPathComponent("tmux.conf").path
        try "set -g prefix C-a\n".write(toFile: conf, atomically: true, encoding: .utf8)
        EnvironmentSetup.ensureTmuxConfig(path: conf, reloadTmux: false)
        EnvironmentSetup.ensureTmuxConfig(path: conf, reloadTmux: false)
        let text = try String(contentsOfFile: conf, encoding: .utf8)
        XCTAssertTrue(text.hasPrefix("set -g prefix C-a\n"))
        XCTAssertEqual(text.components(separatedBy: "# >>> fleet >>>").count - 1, 1)
        XCTAssertTrue(text.contains("window-size latest"))
    }
}
