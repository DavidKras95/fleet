# Fleet — Beta Guide

Thanks for trying Fleet! It's a native macOS app for running several Claude
Code agents at once without losing track of them.

---

## Install

### Option A — Homebrew (easiest, no manual steps)

```bash
brew install --cask davidkras95/fleet/fleet-app
```

This installs Fleet, tmux, and jq in one shot. The only thing you need
beforehand is [Claude Code](https://claude.com/claude-code) on your PATH
(`which claude` should print a path).

### Option B — zip (unsigned beta build)

1. Unzip and drag `Fleet.app` to `/Applications`.
2. First launch: **right-click Fleet → Open → Open** (plain double-click is
   blocked because this beta isn't notarized yet).
   - If macOS still refuses with "damaged / can't be opened":
     ```bash
     xattr -dr com.apple.quarantine /Applications/Fleet.app
     ```
3. Install tmux and jq if you don't have them: `brew install tmux jq`
4. Open Fleet — it handles the rest automatically.

---

## First run

- Fleet self-configures on every launch: it installs Claude Code status hooks
  and a tmux config block. Nothing to set up manually.
- Allow **notifications** when prompted so you get pinged when an agent needs
  input (System Settings → Notifications → Fleet).
- Press **⌘N** → pick a project folder → a terminal opens there → type `claude`.

---

## The 60-second tour

| Shortcut | What it does |
|---|---|
| **⌘N** | Start a new agent — pick a folder, optionally name the task |
| Click a cube | Switch to that agent's terminal |
| **⌘⏎** | Jump to the next agent waiting for your input |
| **⌘↑ / ⌘↓** | Previous / next agent |
| **⌘D / ⇧⌘D** | Split the terminal pane right / down |
| **⌘T, ⌘1–9** | New tab / switch tabs within an agent |
| **⌘,** → Shortcuts | Remap any keyboard shortcut |

Status dots: **🔴 pulsing** = needs you now · **⏳ rocking** = working ·
**🟢 blinking** = done, unread · **🟢 solid** = done, seen · **⚫ gray** = idle.

Quit and reopen anytime — agents keep running in tmux.

---

## What to tell me

Anything is useful, but especially:

- **Install friction** — where did it get confusing or scary?
- **Notifications** — did they arrive? Did clicking one bring Fleet forward?
- **Status dots wrong** — screenshot of sidebar + what Claude was actually doing.
- **Crashes or blank UI** — macOS version + chip (Apple Silicon / Intel) helps.
- **Shortcut clashes** with other apps.
- What felt **great** — so I don't accidentally break it.

---

## Known beta limitations

- **Notarization pending** (Option B only) — hence the right-click-Open step.
  Homebrew builds are signed and notarized, so this only affects zip installs.
- **Requires Claude Code** — Fleet manages it, not replaces it.
- **No in-app update UI yet for unsigned builds** — use the Homebrew path or
  watch the GitHub releases page.
