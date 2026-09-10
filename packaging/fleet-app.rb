# Homebrew formula for Fleet — place in your tap repo as Formula/fleet-app.rb
# (see packaging/PUBLISHING.md for the step-by-step).
class FleetApp < Formula
  desc "Native macOS manager for parallel Claude Code agents, tmux-backed"
  homepage "https://github.com/REPLACE_OWNER/fleet-app"
  url "https://github.com/REPLACE_OWNER/fleet-app/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "REPLACE_WITH_TARBALL_SHA256"
  license "MIT"

  depends_on :macos
  depends_on xcode: ["15.0", :build]
  depends_on "tmux"
  depends_on "jq"

  def install
    system "./scripts/build-app.sh"
    prefix.install "dist/Fleet.app"
  end

  def post_install
    # Put the app where users expect it. Fleet self-configures its
    # environment (Claude hooks, tmux options) on first launch.
    system "cp", "-R", "#{prefix}/Fleet.app", "/Applications/"
  end

  def caveats
    <<~EOS
      Fleet was copied to /Applications. Open it once — it sets up its
      Claude Code hooks and tmux configuration automatically.

      Optional, for powerlevel10k prompt glyphs:
        brew install --cask font-meslo-lg-nerd-font
    EOS
  end

  test do
    assert_predicate prefix/"Fleet.app/Contents/MacOS/Fleet", :exist?
  end
end
