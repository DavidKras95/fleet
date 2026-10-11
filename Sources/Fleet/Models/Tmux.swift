import Darwin
import Foundation

/// Thin shell-out wrapper around the tmux binary. tmux is the session engine:
/// agents live in tmux sessions so they survive app restarts.
enum Tmux {
    /// Prefers a tmux bundled inside the app, then a system install.
    static let bin: String = Executables.find("tmux") ?? "tmux"

    /// Explicit socket path so every subprocess connects to the same server
    /// regardless of launch environment. macOS sets TMPDIR=/var/folders/… for
    /// GUI apps (different from the shell that started the tmux server), and
    /// tmux uses TMPDIR to locate its socket — so Finder-launched Fleet would
    /// connect to a brand-new empty server without this pin.
    static let socketPath: String = "/private/tmp/tmux-\(getuid())/default"

    @discardableResult
    static func run(_ args: [String]) -> (status: Int32, out: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: bin)
        p.arguments = ["-S", socketPath] + args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do { try p.run() } catch { return (127, "") }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }

    @discardableResult
    static func git(in dir: String, _ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = ["-C", dir] + args
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        do { try p.run() } catch { return 127 }
        p.waitUntilExit()
        return p.terminationStatus
    }
}
