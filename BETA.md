# Fleet — Beta Guide

Thanks for trying Fleet! It's a native macOS app for running several Claude
Code agents at once without losing track of them.

---

## For the tester — install & first run

### Prerequisites (one-time)
Fleet manages Claude Code sessions inside tmux, so you need these first:

1. **Claude Code** — install it and make sure `claude` runs in your terminal
   (`which claude` should print a path). Fleet can't bundle this: it's *your*
   Claude login.
2. **tmux** — `brew install tmux`  *(a future build will bundle this)*
3. **jq** — `brew install jq`
4. *Optional, for nicer prompts:* `brew install --cask font-meslo-lg-nerd-font`

If any are missing, Fleet opens with a banner telling you exactly what to fix.

### Install Fleet

**If you got a Homebrew link:**
```bash
brew install --cask <owner>/fleet/fleet-app
```

**If you got a `.zip` (unsigned beta build):**
1. Unzip and drag `Fleet.app` to `/Applications`.
2. First launch: **right-click Fleet → Open → Open** (a plain double-click is
   blocked because this beta isn't notarized yet).
   - If macOS still refuses with "damaged / can't be opened", run once:
     ```bash
     xattr -dr com.apple.quarantine /Applications/Fleet.app
     ```
3. Open Fleet again normally.

### First run
- Fleet sets itself up automatically (Claude Code status hooks + a tmux config
  block). Nothing to configure.
- Allow **notifications** when prompted (System Settings → Notifications →
  Fleet) so you get pinged when an agent needs you.
- Press **⌘N** → pick a folder → a terminal opens there → type `claude`.

### The 60-second tour
| Do this | To |
|---|---|
| **⌘N** | start an agent in a folder you pick |
| click a cube in the sidebar | switch to that agent |
| **⌘D / ⇧⌘D** | split the view into panes (halves / quadrants) |
| **⌘T**, **⌘1–9** | tabs within an agent |
| **⌘⏎** | jump to the next agent that needs input |
| **⌘, → Shortcuts** | remap any keyboard shortcut |

Status dots: 🔴 needs you · 🟠 working · 🟢 done (blinks until you look) · ⚪ idle.
Quit and reopen anytime — agents keep running (they live in tmux).

---

## What to tell me (feedback)

Please note anything, but especially:
- **Install friction** — where did it get confusing or scary?
- **Did notifications work?** Did clicking one bring Fleet forward?
- **Anything that looked broken/empty** with no explanation.
- **Status dots wrong** — a screenshot of the sidebar + what the agent was
  actually doing is gold (that's caught every status bug so far).
- **Missing shortcuts / clashes** with your other apps.
- What felt **great** — so I don't break it.

Your macOS version and chip (Apple Silicon / Intel) help too.

---

## Known beta limitations (so you don't report these)

- **Not notarized yet** — hence the right-click-Open dance. A signed build
  (clean install, reliable notifications) is coming.
- **tmux/jq are separate installs** for now — will be bundled later.
- **Requires Claude Code** — Fleet is a manager for it, not a replacement.
- Tested primarily on the developer's Mac; fresh-machine rough edges are
  exactly what this beta is for.

---

## For the developer — cutting a beta build

Until signing is set up (see `packaging/PUBLISHING.md`), the quickest tester
build is an unsigned zip:

```bash
./scripts/build-app.sh              # builds dist/Fleet.app (runs tests first)
cd dist && ditto -c -k --keepParent Fleet.app Fleet-beta.zip
```

Send `Fleet-beta.zip` + the "If you got a `.zip`" steps above. Once you have an
Apple Developer account, switch to the signed + notarized cask flow in
`packaging/PUBLISHING.md` — that removes the right-click-Open step and fixes
notification permissions.
