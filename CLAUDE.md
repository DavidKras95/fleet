# Fleet — project context for Claude Code

Native macOS app for running many Claude Code agents in parallel. SwiftUI +
SwiftTerm over a tmux engine. Built iteratively with Claude Code (Aug–Sep 2026)
on the owner's work Mac; development continues on their personal Mac.

## What it is (30 seconds)

- **Sidebar of "session cubes"** with live status dots; the detail pane is the
  **real terminal** (SwiftTerm running `tmux attach`) — never a preview.
- **Session = tmux session** (survives app quit/crash). **Tab = tmux window.**
  **Split pane = tmux pane** (⌘D/⇧⌘D; tmux renders the split).
- Status dots: 🔴 needs input (pulsing) · 🟠 working (spinning ring) ·
  🟢 done (blinks until viewed — "unread" logic) · ⚪ idle/no claude.
- Driven by Claude Code hooks → tmux pane options + state files → 1s poll.

## Architecture map

| File | Role |
|---|---|
| `Sources/Fleet/FleetApp.swift` | app entry, menu commands (data-driven shortcuts) |
| `Models/FleetStore.swift` | central state: poll/refresh, spawn/retire/rename, tabs, splits |
| `Models/StatusResolver.swift` | pure status precedence (see "Status system") |
| `Models/SessionNaming.swift` | tmux-safe names, collision numbering |
| `Models/SelectionRestore.swift` | reopen lands on the last-viewed session |
| `Models/NotificationTrigger.swift` | fire-once-on-entry to needs-input |
| `Models/NotificationManager.swift` | app-owned notifications + osascript fallback |
| `Models/KeyCombo/AppCommand/KeybindingStore/KeybindingConflicts/SystemHotkeys` | remappable shortcuts + real-macOS conflict detection |
| `Models/EnvironmentSetup.swift` | **self-setup on every launch** (embedded hook script, settings.json merge, tmux.conf block) — idempotent |
| `Models/Preflight.swift` + `Views/PreflightBanner.swift` | missing tmux/claude → clear banner |
| `Views/TerminalHostView.swift` | terminal cache (per window), WindowState, key monitor (⌘⌫/⇧⏎/⌘Z/⌘X) |
| `Views/SidebarView.swift` | cubes, StatusBadge animations, middle-click close, drag reorder |
| `scripts/build-app.sh` | **test-gated** build → dist/Fleet.app (`--install` → /Applications) |

## Status system (three channels, in precedence order)

1. **tmux pane option `@fleet_state`** — set by the hook when it runs inside a
   pane. Authoritative; never overridden by fallbacks.
2. **`~/.cache/fleet/session-state/<claude session_id>.state`** — precise per
   Claude process; pane linked via `@fleet_sid` tag. Used when (1) is empty.
3. **`~/.cache/fleet/cwd-state/<dir>.state`** — written ONLY by no-pane
   processes (Claude's detached bg-agent daemons); last resort. Shared per
   directory, so it's ambiguous when several no-pane processes share a folder.

Hook = `~/.claude/hooks/agent-tmux-status.sh`, whose SOURCE OF TRUTH is the
embedded string in `EnvironmentSetup.swift` (the app overwrites the installed
copy on launch — edit the Swift, never just the installed file).
Notification-event parsing: "waiting for your input" = idle→done;
permission/"needs your"/"wants to" = red; anything else = leave state alone.

## Non-negotiable conventions

- **TDD.** Every bug fix starts with a failing test; regression guards get
  mutation-tested (re-break the code, watch the test fail, restore).
  `swift test` ~3s, no tmux/app needed. `build-app.sh` refuses to build red.
- **Owner drives git.** Never commit or push proactively; leave changes for
  their review. (Repo currently has NO commits — first commit happens on the
  personal Mac.)
- **Owner's UX anti-requirements** (learned from rejecting Claude Squad):
  no forced worktrees (opt-in only), no preview indirection (the terminal you
  see is real), no per-repo silos, boring/reliable over clever.
- Every sidebar cube shows project caption + a distinct title (never a generic
  label like "main" — that shipped once and was hated).

## Hard-won gotchas (do not relearn these)

- **Never call `Tmux.run` (blocking `Process.waitUntilExit`) from SwiftUI view
  code** — crashed the app inside `updateNSView` (nested run loop). A lint
  test (`ViewLayerLintTests`) enforces it; off-main dispatch is the escape.
- **SourceKit shows false "cannot find X in scope" errors cross-file** in this
  SPM setup — `swift build`/`swift test` are the authority.
- **macOS 26 (Tahoe) reads app icons from `Assets.car`/`CFBundleIconName`**;
  older macOS uses `.icns`/`CFBundleIconFile`. Ship BOTH (build script does).
  Icon master: `Resources/icon-master.png`; pipeline in `scripts/make-icon.swift`
  header comment (actool needs `xcodebuild -runFirstLaunch` once).
- **Icon cache keys on bundle version** — build script stamps a timestamp
  `CFBundleVersion` per build; don't revert to a constant.
- **Ad-hoc signing breaks notification permission** (signature changes every
  build → macOS never durably authorizes). Current behavior: try app-owned
  notification, fall back to osascript banner on refusal. A Developer-ID
  signed build fixes it properly. Dock bounce (`requestUserAttention`) is the
  permission-free attention signal.
- Claude Code **snapshots hook config at process start** — long-running
  sessions don't see newly added hook events until restarted (hook *script*
  content is read fresh each event, though).
- tmux exact-match targets: sessions `=name`, but `send-keys` needs `=name:`.

## Current state & the publishing task (next up)

Everything through beta-prep is DONE on the work Mac: features, 82-test suite,
icon (AI artwork), welcome sheet, preflight, BETA.md, LICENSE (MIT),
CI (`.github/workflows/ci.yml`, macos-15) and release pipeline
(`release.yml`: sign → notarize → staple → GitHub release; secrets listed at
top of the file), Homebrew formula + cask templates in `packaging/`.

**Remaining, in order (details in `packaging/PUBLISHING.md`):**
1. First git commit + push to a private GitHub repo (owner does this).
2. Apple Developer account → "Developer ID Application" cert → export .p12.
3. Add the 6 secrets from `release.yml` to the GitHub repo.
4. `git tag v1.0.0 && git push --tags` → CI produces the signed, notarized zip.
5. Create the `homebrew-fleet` tap with `packaging/fleet-app-cask.rb`
   (fill sha256) → friend installs via one brew command.
6. Deferred by choice: bundling tmux/jq inside the app (`Executables.find`
   already checks `Contents/Resources` first, so it's a drop-in later);
   `claude` itself can never be bundled (it's the user's own auth).

Tester-facing instructions live in `BETA.md`. On any new machine the app
self-installs its environment on first launch — no manual setup steps.
