import Foundation

/// Turns raw tmux pane data into one status per session. Pure, so the
/// precedence rules are testable:
///   1. a pane's own @fleet_state is authoritative;
///   2. otherwise the session_id-keyed file (precise to that process);
///   3. otherwise the cwd-keyed file (last resort for detached daemons);
///   4. a session's most urgent pane defines the session.
enum StatusResolver {
    /// Each line: session \t @fleet_state \t pane_current_path \t @fleet_sid
    ///
    /// `validSessions`, when supplied, is the authoritative set of session
    /// names from `tmux list-sessions`. Any parsed name not in it is dropped —
    /// so a malformed status line (e.g. one whose tab separators collapsed and
    /// turned the whole row into one bogus "name") can never surface as a fake
    /// session or be attached to. Pass nil to skip filtering.
    static func resolve(paneLines: [String],
                        ignoredSessions: Set<String>,
                        validSessions: Set<String>? = nil,
                        sessionIdState: (String) -> AgentSession.State?,
                        cwdState: (String) -> AgentSession.State?) -> [String: AgentSession.State] {
        var states: [String: AgentSession.State] = [:]
        for line in paneLines {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard let name = parts.first, !name.isEmpty, !ignoredSessions.contains(name) else { continue }
            if let validSessions, !validSessions.contains(name) { continue }
            let rawState = parts.count > 1 ? parts[1] : ""
            var state = AgentSession.State(rawValue: rawState) ?? .idle
            // Fallback files are consulted only when THIS pane has never
            // received a direct hook signal — a live state is never overridden.
            if rawState.isEmpty {
                let sid = parts.count > 3 ? parts[3] : ""
                if !sid.isEmpty, let precise = sessionIdState(sid) {
                    state = precise
                } else if parts.count > 2, !parts[2].isEmpty, let shared = cwdState(parts[2]) {
                    state = shared
                }
            }
            if let prev = states[name], prev.priority <= state.priority { continue }
            states[name] = state
        }
        return states
    }
}
