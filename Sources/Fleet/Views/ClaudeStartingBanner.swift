import SwiftUI

/// Thin progress bar shown between the tab bar and terminal while Claude Code
/// is starting up. Disappears automatically when the first hook event arrives.
struct ClaudeStartingBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.65)
                .frame(width: 14, height: 14)
            Text("Starting Claude…")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
