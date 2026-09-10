# Fleet.app — native macOS Claude Code agent manager

**Date:** 2026-08-11 · **Status:** approved

## Purpose

A tailor-made Mac app for running many Claude Code agents in parallel without
losing track of them. Replaces terminal-side managers (custom tmux hub, Claude
Squad, tmux mosaic) that didn't fit the owner's workflow.

## Anti-requirements (learned from rejected tools)

1. No forced git worktrees — agents run in the repo itself; worktrees strictly opt-in.
2. No preview indirection — the visible terminal IS the live agent.
3. No fragile custom terminal/session machinery — delegate to proven components.
4. One global view across all repos in `~/git`, not per-repo silos.

## Architecture

- **UI**: SwiftUI (macOS 14+), `NavigationSplitView`.
- **Terminal widget**: SwiftTerm (`LocalProcessTerminalView`), one cached view
  per agent so switching sessions never restarts anything.
- **Engine**: tmux. Each agent = one tmux session named `repo` or `repo/task`.
  The app's terminal views run `tmux attach`. Quitting/crashing the app never
  kills agents; relaunching reattaches.
- **Status**: existing Claude Code hooks (`~/.claude/hooks/agent-tmux-status.sh`)
  set the pane option `@fleet_state` (input/busy/done) + pane title + macOS
  notification. The app polls `tmux list-panes -a` every second and renders
  badges. No state files, no daemon.

## UI

- **Sidebar (always visible)**: sessions grouped by repo; each row shows a badge
  — 🔴 needs input (bold, sorted first), ⏳ working, ✅ finished turn. Selecting
  a row shows its terminal.
- **Main area**: the selected agent's live terminal (SwiftTerm attached to tmux).
- **⌘N**: new-agent sheet — repo picker (dirs in `~/git` with `.git`), optional
  task name, worktree checkbox (default OFF). Spawn = `tmux new -d` in the repo
  (or worktree `~/git/.worktrees/<repo>/<task>`, branch `david_kr/<task>`),
  set `@fleet_name`, run `claude`.
- **⌘⏎**: select next waiting (input-state) agent.
- **Context menu → Retire**: kill tmux session; remove worktree if clean, keep
  with a warning if dirty.
- **Dock badge**: count of agents waiting for input.

## Error handling

- tmux binary resolved from brew/system paths at launch; missing → alert.
- Spawn into existing session name → just select it.
- Sessions created outside the app (CLI) appear automatically via polling.
- Session killed externally → row disappears on next poll; cached view dropped.

## Out of scope for v1

Split panes, embedded browser, ADO integration, custom app icon, code signing
for distribution (ad-hoc signed, local use).

## Build & run

Swift Package (no Xcode project): `swift build -c release`;
`scripts/build-app.sh` bundles `dist/Fleet.app`. Repo: `~/git/fleet-app`.
Owner drives git manually (no auto-commits).
