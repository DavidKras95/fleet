import SwiftUI

/// Shown in place of the terminal when a required tool is missing, so a
/// fresh install explains itself instead of looking broken.
struct PreflightBanner: View {
    let issues: [PreflightIssue]
    var installing: Bool = false

    var body: some View {
        VStack(spacing: 18) {
            if installing {
                installingView
            } else {
                issuesView
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var installingView: some View {
        VStack(spacing: 18) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Installing missing tools…")
                .font(.title2.bold())
            Text("Fleet is installing tmux and jq via Homebrew in the background.\nThis only happens once.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private var issuesView: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text("Fleet needs a couple of things")
                .font(.title2.bold())
            VStack(alignment: .leading, spacing: 14) {
                ForEach(issues) { issue in
                    VStack(alignment: .leading, spacing: 3) {
                        Label(issue.title, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.headline)
                        Text(issue.fix)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
            Text("Fix these, then relaunch Fleet.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
