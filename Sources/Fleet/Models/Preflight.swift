import Foundation

struct PreflightIssue: Identifiable, Equatable {
    let id: String
    let title: String
    let fix: String
}

/// Startup dependency checks, so a missing tool produces a clear message
/// instead of a silent, empty app.
enum Preflight {
    static func issues(tmuxAvailable: Bool, jqAvailable: Bool, claudeAvailable: Bool,
                       brewAvailable: Bool) -> [PreflightIssue] {
        var out: [PreflightIssue] = []
        if !tmuxAvailable {
            let fix = brewAvailable
                ? "Fleet is installing tmux via Homebrew automatically."
                : "Fleet auto-installs tmux via Homebrew — install Homebrew first (brew.sh), then relaunch Fleet."
            out.append(PreflightIssue(id: "tmux", title: "tmux not found", fix: fix))
        }
        if !jqAvailable {
            let fix = brewAvailable
                ? "Fleet is installing jq via Homebrew automatically."
                : "Fleet auto-installs jq via Homebrew — install Homebrew first (brew.sh), then relaunch Fleet."
            out.append(PreflightIssue(id: "jq", title: "jq not found", fix: fix))
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
