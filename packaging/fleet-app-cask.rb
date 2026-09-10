# Homebrew CASK for Fleet — the no-Xcode install path (like alt-tab.app).
# Place in your tap repo as Casks/fleet-app.rb once releases are signed
# and notarized (see PUBLISHING.md). Users then run:
#   brew install --cask <owner>/fleet/fleet-app
cask "fleet-app" do
  version "1.0.0"
  sha256 "REPLACE_WITH_ZIP_SHA256"

  url "https://github.com/REPLACE_OWNER/fleet-app/releases/download/v#{version}/Fleet-v#{version}.zip"
  name "Fleet"
  desc "Native macOS manager for parallel Claude Code agents, tmux-backed"
  homepage "https://github.com/REPLACE_OWNER/fleet-app"

  depends_on macos: ">= :sonoma"
  depends_on formula: "tmux"
  depends_on formula: "jq"

  app "Fleet.app"

  caveats <<~EOS
    Open Fleet once — it configures its Claude Code hooks and tmux
    settings automatically. Requires the `claude` CLI on your PATH.

    Optional, for powerlevel10k prompt glyphs:
      brew install --cask font-meslo-lg-nerd-font
  EOS

  zap trash: [
    "~/.claude/hooks/agent-tmux-status.sh",
    "~/Library/Preferences/com.davidkr.fleet.plist",
  ]
end
