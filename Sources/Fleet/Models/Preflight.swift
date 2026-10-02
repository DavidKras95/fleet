import Foundation

struct PreflightIssue: Identifiable, Equatable {
    let id: String
    let title: String
    let fix: String
}

/// Startup dependency checks, so a missing tool produces a clear message
/// instead of a silent, empty app.
enum Preflight {
    static func issues(tmuxAvailable: Bool, jqAvailable: Bool, claudeAvailable: Bool) -> [PreflightIssue] {
        var out: [PreflightIssue] = []
        if !tmuxAvailable {
            out.append(PreflightIssue(
                id: "tmux",
                title: "tmux not found",
                fix: "Fleet runs agents inside tmux. Install it with:  brew install tmux"))
        }
        if !jqAvailable {
            out.append(PreflightIssue(
                id: "jq",
                title: "jq not found",
                fix: "Fleet's status hooks require jq to parse Claude events. Install it with:  brew install jq"))
        }
        if !claudeAvailable {
            out.append(PreflightIssue(
                id: "claude",
                title: "Claude Code (claude) not found on PATH",
                fix: "Fleet manages Claude Code sessions. Install Claude Code and make sure `claude` is on your PATH."))
        }
        return out
    }
}
