import SwiftUI

/// One-time first-run orientation: the five things worth knowing, then out
/// of the way forever.
struct WelcomeSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let rows: [(keys: String, what: String)] = [
        ("⌘N", "Start an agent — pick any folder, a terminal opens there, type `claude`"),
        ("⌘⏎", "Jump to the next agent waiting for your input"),
        ("⌘D · ⇧⌘D", "Split the view into panes (halves, quadrants)"),
        ("⌘T · ⌘1–9", "Tabs inside an agent"),
        ("⌘,", "Settings — including remapping every shortcut"),
    ]

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 42))
                .foregroundStyle(Color.accentColor)
            Text("Welcome to Fleet")
                .font(.title.bold())
            Text("Run many Claude Code agents in parallel without losing track.\nAgents live in tmux — quit Fleet anytime, they keep running.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 9) {
                ForEach(rows, id: \.keys) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(row.keys)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .frame(width: 92, alignment: .trailing)
                        Text(row.what)
                            .font(.callout)
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))

            Text("Status dots: 🔴 needs you · 🟠 working · 🟢 done · ⚪ idle")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Get Started") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
        }
        .padding(28)
        .frame(width: 480)
    }
}
