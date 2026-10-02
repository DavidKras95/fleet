import Foundation

/// Zero-step onboarding: Fleet configures its own environment on every
/// launch (idempotent, fast no-op when already set up). This is what makes
/// `brew install` + open the app a complete installation:
/// 1. the Claude Code status-hook script (powers the sidebar dots),
/// 2. the hook entries in ~/.claude/settings.json,
/// 3. the tmux options Fleet relies on, in a guarded ~/.tmux.conf block.
enum EnvironmentSetup {
    static func ensure() {
        installHookScript(at: NSString(string: "~/.claude/hooks/agent-tmux-status.sh").expandingTildeInPath)
        mergeClaudeHooks(settingsPath: NSString(string: "~/.claude/settings.json").expandingTildeInPath)
        ensureTmuxConfig(path: NSString(string: "~/.tmux.conf").expandingTildeInPath, reloadTmux: true)
    }

    /// Installs missing CLI tools (tmux, jq) via Homebrew if brew is available.
    /// Runs in the background; calls `completion` on the main actor when done
    /// so the caller can re-run preflight.
    static func installMissingTools(completion: @escaping @MainActor () -> Void) {
        let missing = ["tmux", "jq"].filter { !Executables.isAvailable($0) }
        guard !missing.isEmpty else {
            Task { @MainActor in completion() }
            return
        }
        guard let brew = Executables.find("brew") else {
            Task { @MainActor in completion() }
            return
        }
        Task.detached(priority: .utility) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: brew)
            p.arguments = ["install"] + missing
            p.standardOutput = Pipe()
            p.standardError = Pipe()
            try? p.run()
            p.waitUntilExit()
            await MainActor.run { completion() }
        }
    }

    // MARK: 1. Hook script

    static func installHookScript(at hookScriptPath: String) {
        let fm = FileManager.default
        let existing = (try? String(contentsOfFile: hookScriptPath, encoding: .utf8))
        guard existing != hookScript else { return }
        try? fm.createDirectory(
            atPath: (hookScriptPath as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true)
        try? hookScript.write(toFile: hookScriptPath, atomically: true, encoding: .utf8)
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookScriptPath)
    }

    // MARK: 2. settings.json hook entries

    static func mergeClaudeHooks(settingsPath path: String) {
        let command = "bash ~/.claude/hooks/agent-tmux-status.sh"
        let wanted: [(event: String, arg: String)] = [
            ("Notification", "input"),
            ("UserPromptSubmit", "busy"),
            // Tool activity proves the agent is working — this self-clears a
            // stale red state after a permission prompt is approved (approval
            // itself fires no hook event).
            ("PreToolUse", "busy"),
            ("PostToolUse", "busy"),
            ("Stop", "done"),
            ("SessionEnd", "end"),
            ("SessionStart", "done"),
        ]

        var root: [String: Any] = [:]
        if let data = FileManager.default.contents(atPath: path),
           let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            root = parsed
        }
        var hooks = root["hooks"] as? [String: Any] ?? [:]

        var changed = false
        for (event, arg) in wanted {
            let full = "\(command) \(arg)"
            var groups = hooks[event] as? [[String: Any]] ?? []
            let present = groups.contains { group in
                ((group["hooks"] as? [[String: Any]]) ?? [])
                    .contains { ($0["command"] as? String) == full }
            }
            if !present {
                groups.append(["hooks": [["type": "command", "command": full]]])
                hooks[event] = groups
                changed = true
            }
        }
        guard changed else { return }

        root["hooks"] = hooks
        try? FileManager.default.createDirectory(
            atPath: (path as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(
            withJSONObject: root, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }

    // MARK: 3. tmux config

    static func ensureTmuxConfig(path: String, reloadTmux: Bool) {
        let marker = "# >>> fleet >>>"
        let existing = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        guard !existing.contains(marker) else { return }
        let block = "\n\(marker)\n\(tmuxSnippet)# <<< fleet <<<\n"
        try? (existing + block).write(toFile: path, atomically: true, encoding: .utf8)
        if reloadTmux { Tmux.run(["source-file", path]) }
    }

    // MARK: Embedded resources

    private static let tmuxSnippet = #"""
    # Fleet — tmux settings the app relies on (installed automatically).
    set -g default-terminal "tmux-256color"
    set -as terminal-features ",xterm-256color:RGB"
    set -g window-size latest
    set -g history-limit 50000
    set -g mouse on
    set -g focus-events on

    """#

    static let hookScript = #"""
    #!/bin/bash
    # Claude Code hook: reflect this agent's state so the Fleet app sidebar
    # can show it. Called with one arg: input | busy | done | end
    # Installed automatically by Fleet.app — edits will be overwritten.
    #
    # Three channels, because Claude Code's own "background agent" (bg)
    # feature runs the real process as a detached daemon with NO tmux
    # pane at all (`claude agents` just attaches a viewer to it) — a plain
    # tmux-pane-based hook silently never fires for those sessions:
    #   1. tmux pane option @fleet_state — when this hook runs inside a
    #      tmux pane (the common case: `claude` started directly in Fleet).
    #      Authoritative whenever present.
    #   2. a state file keyed by Claude's session_id (stable and unique for
    #      the life of that process) — works with no tmux pane at all, and
    #      unlike keying by directory, never collides with a sibling agent
    #      running in the same folder. The first time this hook sees a given
    #      session_id on a tmux pane, it durably tags the pane with it, so
    #      the pane can look its OWN status up here even before it has its
    #      own @fleet_state.
    #   3. a state file keyed by cwd — last resort only, for the rare
    #      process that never touches a tmux pane at all (no session_id
    #      link is possible), so directory is all we have.
    event="$1"
    payload="$(cat)"
    cwd="$(jq -r '.cwd // empty' <<<"$payload" 2>/dev/null)"
    sid="$(jq -r '.session_id // empty' <<<"$payload" 2>/dev/null)"
    msg="$(jq -r '.message // empty' <<<"$payload" 2>/dev/null | head -c 200)"
    msg="${msg//\"/}"

    cwd_state_dir="$HOME/.cache/fleet/cwd-state"
    cwd_key=""
    if [ -n "$cwd" ]; then
      mkdir -p "$cwd_state_dir"
      cwd_key="$cwd_state_dir/$(printf '%s' "$cwd" | tr '/' '_').state"
    fi

    sid_state_dir="$HOME/.cache/fleet/session-state"
    sid_key=""
    if [ -n "$sid" ]; then
      mkdir -p "$sid_state_dir"
      sid_key="$sid_state_dir/$sid.state"
    fi

    write_state() {
      [ -n "$sid_key" ] && printf '%s' "$1" > "$sid_key"
      # The directory-keyed file is for detached daemons only (no pane means
      # no session_id link can be made). A pane-backed session must never
      # write it, or an idle daemon in the same folder would show this
      # session's status.
      if [ -z "${TMUX_PANE:-}" ] && [ -n "$cwd_key" ]; then
        printf '%s' "$1" > "$cwd_key"
      fi
      return 0
    }

    name=""
    if [ -n "${TMUX_PANE:-}" ]; then
      name="$(tmux show -pqv -t "$TMUX_PANE" @fleet_name 2>/dev/null)"
      [ -n "$name" ] || name="$(basename "$(tmux display-message -p -t "$TMUX_PANE" '#{pane_current_path}' 2>/dev/null)")"
      # Tag this pane with its owning session_id once, so it can find its
      # own precise status file even before @fleet_state is ever set.
      if [ -n "$sid" ] && [ -z "$(tmux show -pqv -t "$TMUX_PANE" @fleet_sid 2>/dev/null)" ]; then
        tmux set -pq -t "$TMUX_PANE" @fleet_sid "$sid"
      fi
    fi

    case "$event" in
      input)
        case "$msg" in
          *"waiting for your input"*)
            # Idle reminder, not a blocking question — the agent is simply ready.
            write_state done
            if [ -n "${TMUX_PANE:-}" ]; then
              tmux set -pq -t "$TMUX_PANE" @fleet_state done
              tmux select-pane -t "$TMUX_PANE" -T "✅ $name" 2>/dev/null
            fi
            ;;
          *[Pp]ermission*|*"needs your"*|*"wants to"*)
            # A genuinely blocking request — mark red and notify.
            write_state input
            if [ -n "${TMUX_PANE:-}" ]; then
              tmux set -pq -t "$TMUX_PANE" @fleet_state input
              tmux select-pane -t "$TMUX_PANE" -T "🔔 $name" 2>/dev/null
            fi
            # The Fleet app posts the macOS notification itself (so clicking it
            # opens Fleet, not the AppleScript runner) — nothing to do here.
            ;;
          *)
            # Informational (background task finished, etc.) — never flip
            # a working agent to red over these; leave the state alone.
            ;;
        esac
        [ -n "${TMUX_PANE:-}" ] && tmux refresh-client -S 2>/dev/null
        ;;
      busy)
        write_state busy
        if [ -n "${TMUX_PANE:-}" ]; then
          tmux set -pq -t "$TMUX_PANE" @fleet_state busy
          tmux select-pane -t "$TMUX_PANE" -T "⏳ $name" 2>/dev/null
        fi
        ;;
      done)
        write_state done
        if [ -n "${TMUX_PANE:-}" ]; then
          tmux set -pq -t "$TMUX_PANE" @fleet_state done
          tmux select-pane -t "$TMUX_PANE" -T "✅ $name" 2>/dev/null
          tmux refresh-client -S 2>/dev/null
        fi
        ;;
      end)
        [ -n "$sid_key" ] && rm -f "$sid_key"
        # Same rule as write_state: only a daemon may clear the directory file.
        [ -z "${TMUX_PANE:-}" ] && [ -n "$cwd_key" ] && rm -f "$cwd_key"
        if [ -n "${TMUX_PANE:-}" ]; then
          tmux set -pqu -t "$TMUX_PANE" @fleet_state 2>/dev/null
          tmux select-pane -t "$TMUX_PANE" -T "$name" 2>/dev/null
        fi
        ;;
    esac
    exit 0
    """#
}
