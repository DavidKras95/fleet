# Publishing Fleet to Homebrew (one-liner install)

Goal: anyone on the team runs

```bash
brew install <owner>/fleet/fleet-app
```

and gets Fleet in /Applications with everything configured (the app sets up
its own Claude hooks and tmux config on first launch).

## One-time steps

1. **Pick a license** — the formula assumes MIT; add a `LICENSE` file.
2. **Push this repo to GitHub** (e.g. `github.com/<owner>/fleet-app`) and tag:
   ```bash
   git tag v1.0.0 && git push origin main --tags
   ```
3. **Get the tarball checksum**:
   ```bash
   curl -sL https://github.com/<owner>/fleet-app/archive/refs/tags/v1.0.0.tar.gz | shasum -a 256
   ```
4. **Create the tap repo** `github.com/<owner>/homebrew-fleet` containing
   `Formula/fleet-app.rb` — copy `packaging/fleet-app.rb`, replace
   `REPLACE_OWNER` and `REPLACE_WITH_TARBALL_SHA256`.
5. Done. The install line is `brew install <owner>/fleet/fleet-app`
   (Homebrew resolves `<owner>/fleet` to the `homebrew-fleet` repo).

## Releasing updates

Tag a new version, update `url` + `sha256` in the tap's formula, push.
Users get it via `brew upgrade fleet-app`.

## The no-Xcode path (cask — the alt-tab.app experience)

Users install a **pre-built** app, so only CI needs Xcode:

```bash
brew install --cask <owner>/fleet/fleet-app
```

What it takes (one-time):

1. **Apple Developer Program membership** ($99/year, or Optimove's org
   account) → create a **"Developer ID Application"** certificate in the
   Apple Developer portal, export as `.p12`.
2. **App-specific password** for notarization (appleid.apple.com →
   Sign-In & Security → App-Specific Passwords).
3. Add the six secrets listed at the top of
   `.github/workflows/release.yml` to the GitHub repo.
4. Push a tag (`git tag v1.0.0 && git push --tags`) — the workflow builds,
   signs with hardened runtime, notarizes with Apple (takes ~2–10 min),
   staples the ticket, and attaches `Fleet-v1.0.0.zip` to a GitHub Release.
5. Copy `packaging/fleet-app-cask.rb` into the tap as `Casks/fleet-app.rb`,
   fill in the sha256 printed by the workflow. Done.

Releases after that: tag → CI does everything → bump `version`/`sha256`
in the cask.

Why each piece is required: macOS Gatekeeper blocks downloaded apps that
aren't **signed with a Developer ID and notarized**. That's the entire
difference between "double-click and it opens" (alt-tab.app) and
"'Fleet' is damaged and can't be opened". Signing without notarizing is
not enough on modern macOS.

## Notes & trade-offs

- The **formula** (`fleet-app.rb`) builds from source → needs Xcode on the
  user's machine, but requires no Apple account at all. Good for just you.
- The **cask** (`fleet-app-cask.rb`) installs the CI-built zip → no Xcode
  for users, but requires the signing/notarization setup above. This is
  the path for distributing to the team.
- User-machine requirements either way: macOS 14+, `claude` on PATH.
  tmux and jq come in as Homebrew dependencies.
- Org policy note: the tap is a repo under your GitHub account/org —
  vet who can push to it, since its formulae run code at install time.
