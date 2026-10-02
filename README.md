# Fleet

A native macOS app for running **many Claude Code agents in parallel** without
losing track of them. Sidebar of live-status agent cubes on the left, the real
terminal on the right, tmux underneath so nothing ever dies with the app.

```
┌─────────────────────┬──────────────────────────────────┐
│ 🔴 my-app/fix-auth  │                                  │
│ ⏳ api-server       │   the selected agent's live      │
│ 🟢 frontend/demo    │   terminal (SwiftTerm + tmux)    │
│ ⚪ infra            │                                  │
└─────────────────────┴──────────────────────────────────┘
```

## Why it exists

Terminal tabs don't scale past a few agents: you can't see who needs input,
sessions die with their window, and worktree-first tools force ceremony on
quick tasks. Fleet's rules, learned the hard way:

- **The terminal you see is the real agent** — no previews, no indirection.
- **Agents survive everything** — they live in tmux sessions; quit or crash
  the app and reattach later.
- **Worktrees are opt-in** — agents run in the repo itself unless you ask.
- **You can't miss an agent that needs you** — pulsing red dot, red ring,
  macOS notification, dock badge, and ⌘⏎ jumps to it.

## Install

### Homebrew (when published — see packaging/PUBLISHING.md)

```bash
brew install --cask <owner>/fleet/fleet-app   # pre-built, no Xcode needed
brew install <owner>/fleet/fleet-app          # or: build from source (needs Xcode)
```

### From source

```bash
git clone <this repo> && cd fleet-app
./scripts/build-app.sh --install   # builds and copies to /Applications
```

Requirements: macOS 14+, Xcode 15+, [Claude Code](https://claude.com/claude-code)
on your PATH, tmux (`brew install tmux`; the formula installs it for you).

**There is no setup step.** On first launch Fleet installs everything it
needs, idempotently: the Claude Code status hooks (`~/.claude/hooks/` plus
entries in `~/.claude/settings.json`) and a guarded block of tmux options in
`~/.tmux.conf`. Upgrades re-sync these automatically.

## Using it

| | |
|---|---|
| **⌘N** | new session — pick a folder (or repo suggestions, Settings ⌘,), optional task name, optional worktree; starts `claude` automatically (toggle in Settings) |
| **⌘⏎** | jump to the next agent waiting for input |
| **⌘↑ / ⌘↓** | previous / next agent |
| **⌘⇧N** | new window (watch different agents side by side) |
| **⌘T / ⌘1-9** | new tab / go to tab — tabs are tmux windows, so they persist with the session |
| **⌘D / ⇧⌘D** | split the current pane right / down (halves or quadrants); each new pane is a shell in the same folder |
| **⌘⌥←/→/↑/↓** | move focus between split panes · View→Split has layout presets (halves, quadrants, cycle) |
| **⌘W** | close the focused pane; closes the whole tab when it's the last pane |
| **⌘= / ⌘-** | terminal zoom · **⇧⌘= / ⇧⌘-** app zoom |
| **⇧⏎** | newline in Claude's input · **⌘⌫** clear line · **⌘Z** undo · **⌘X** copy selection + clear line |
| **drag** | reorder session cubes (order persists) |
| **middle-click** | close an agent (with confirmation) · **✕** closes instantly |

Status dots: **red pulsing** = needs you now · **⏳ rocking** = working ·
**green blinking** = finished, unread · **green solid** = finished, seen ·
**gray** = no Claude running in that session.

Sessions created outside the app (`tmux new -s name`) appear automatically;
retiring an agent kills its tmux session and removes its worktree if clean.
After a reboot (the only thing that kills the tmux server), relaunch an agent
in the same repo and run `claude --resume` to pick up the conversation.

## Tests

```bash
swift test                       # ~2s, no tmux/app required
./scripts/build-app.sh --install # runs the suite first; refuses to build red
```

`Tests/FleetTests/` is a regression suite — every test pins down a bug that
actually shipped, so it can't come back silently:

| Suite | Guards against |
|---|---|
| `SessionNamingTests` | bare `2` names, spawn jumping to an existing session, rename collisions |
| `SessionLabelTests` | every cube reading `main` instead of its own name |
| `StatusResolverTests` | two sessions in one directory sharing a status; fallback precedence |
| `HookScriptTests` | runs the real embedded hook: idle reminder → red, informational → red, sibling cross-talk |
| `EnvironmentSetupTests` | self-setup clobbering your existing hooks; non-idempotent merges |
| `ViewLayerLintTests` | the 2026-08-23 crash: blocking tmux calls inside SwiftUI view updates |

CI (`.github/workflows/ci.yml`) runs the same suite on every push.

## Architecture

Three layers, each doing what it's best at:

- **SwiftUI** — the shell: sidebar, windows, commands, settings.
- **[SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)** — the terminal
  emulator view, one per agent per window.
- **tmux** — the session engine. Every agent is a tmux session; the app's
  terminals just `tmux attach`. App state lives in tmux pane options
  (`@fleet_name`, `@fleet_state`) — no database, no daemon.

Status flows from Claude Code hook events (Notification / UserPromptSubmit /
Stop / SessionStart / SessionEnd) → a small shell script → tmux pane options →
polled by the app once a second.

Design history and decisions: `docs/superpowers/specs/`.

## Repo layout

```
Sources/Fleet/
  FleetApp.swift            app entry, menu commands
  Models/                   FleetStore (state), Tmux (shell-outs),
                            EnvironmentSetup (self-configuration), AgentSession
  Views/                    Sidebar, terminal host, spawn sheet, settings
scripts/build-app.sh        build + bundle (+ --install to /Applications)
packaging/                  Homebrew formula template + publishing guide
```
