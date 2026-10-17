import XCTest
@testable import Fleet

/// Past-session discovery reads Claude Code's own transcript files, whose
/// format we don't control — these pin down what we extract and what we skip.
final class ClaudeSessionScannerTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_000)

    private func parse(_ lines: [String]) -> PastSession? {
        ClaudeSessionScanner.parse(id: "abc", lines: lines, updatedAt: date)
    }

    func testExtractsCwdAndFirstRealPrompt() {
        let s = parse([
            #"{"type":"mode","sessionId":"abc"}"#,
            #"{"type":"user","cwd":"/Users/me/my-app","message":{"role":"user","content":"fix the login bug"}}"#,
            #"{"type":"user","cwd":"/Users/me/my-app","message":{"role":"user","content":"and add a test"}}"#,
        ])
        XCTAssertEqual(s?.cwd, "/Users/me/my-app")
        XCTAssertEqual(s?.preview, "fix the login bug")
        XCTAssertEqual(s?.promptCount, 2)
        XCTAssertEqual(s?.updatedAt, date)
    }

    func testSkipsInjectedWrappersAndToolResults() {
        // System reminders, slash-command wrappers and tool results are all
        // "user" lines but not something the person typed.
        let s = parse([
            #"{"type":"user","cwd":"/p","message":{"content":"<system-reminder>x</system-reminder>"}}"#,
            #"{"type":"user","cwd":"/p","message":{"content":[{"type":"tool_result","content":"ok"}]}}"#,
            #"{"type":"user","cwd":"/p","message":{"content":[{"type":"text","text":"real question"}]}}"#,
        ])
        XCTAssertEqual(s?.preview, "real question")
        XCTAssertEqual(s?.promptCount, 1)
    }

    func testLastCustomTitleWins() {
        let s = parse([
            #"{"type":"custom-title","customTitle":"first-name","sessionId":"abc"}"#,
            #"{"type":"user","cwd":"/p","message":{"content":"hi"}}"#,
            #"{"type":"custom-title","customTitle":"renamed","sessionId":"abc"}"#,
        ])
        XCTAssertEqual(s?.title, "renamed")
    }

    func testPreviewIsSingleLineAndTruncated() {
        let long = String(repeating: "a", count: 300)
        let s = parse([#"{"type":"user","cwd":"/p","message":{"content":"line one\nline two \#(long)"}}"#])
        XCTAssertFalse(s!.preview.contains("\n"))
        XCTAssertLessThanOrEqual(s!.preview.count, 120)
    }

    func testSessionWithoutPromptsIsNotImportable() {
        // Opened and closed without typing anything — nothing to resume.
        XCTAssertNil(parse([#"{"type":"mode","sessionId":"abc"}"#]))
    }

    func testMalformedLinesAreIgnored() {
        let s = parse([
            "not json at all",
            #"{"type":"user","cwd":"/p","message":{"content":"ok"}}"#,
            #"{"type":"user","#,
        ])
        XCTAssertEqual(s?.preview, "ok")
    }

    func testOnlyUUIDsAreAcceptedAsResumeIds() {
        // The id is typed into a shell, so anything else is rejected outright.
        XCTAssertTrue(ClaudeSessionScanner.isValidId("405dca81-b794-471c-a9f5-ced9ad58ed55"))
        XCTAssertFalse(ClaudeSessionScanner.isValidId("abc; rm -rf ~"))
        XCTAssertFalse(ClaudeSessionScanner.isValidId(""))
    }
}
