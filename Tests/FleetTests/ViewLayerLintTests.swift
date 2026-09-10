import XCTest

/// Crash guard. On 2026-08-23 the app segfaulted (EXC_BAD_ACCESS in
/// NSConcreteTask.waitUntilExit) because view code called `Tmux.run(...)`
/// synchronously from inside SwiftUI's updateNSView — a blocking nested
/// run loop inside an in-flight run-loop callback. This scans the view
/// layer so that pattern can't come back unnoticed.
final class ViewLayerLintTests: XCTestCase {
    private var viewsDir: URL {
        // Tests/FleetTests/ViewLayerLintTests.swift → repo root
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/Fleet/Views")
    }

    func testViewsDirectoryExists() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: viewsDir.path), viewsDir.path)
    }

    func testNoBlockingTmuxCallsInViewLayer() throws {
        let files = try FileManager.default.contentsOfDirectory(at: viewsDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        XCTAssertFalse(files.isEmpty)

        var violations: [String] = []
        for file in files {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
            for (i, raw) in lines.enumerated() {
                let line = raw.trimmingCharacters(in: .whitespaces)
                guard line.contains("Tmux.run(") || line.contains("Tmux.git("),
                      !line.hasPrefix("//") else { continue }
                // Allowed only when explicitly dispatched off the main thread
                // on the line itself or the line just above.
                let previous = i > 0 ? lines[i - 1] : ""
                let offMain = [line, previous].contains {
                    $0.contains("DispatchQueue.global") || $0.contains("Task.detached")
                }
                if !offMain {
                    violations.append("\(file.lastPathComponent):\(i + 1): \(line)")
                }
            }
        }
        XCTAssertTrue(violations.isEmpty,
                      "Blocking tmux call(s) in view code — these crash inside updateNSView:\n"
                        + violations.joined(separator: "\n"))
    }
}
