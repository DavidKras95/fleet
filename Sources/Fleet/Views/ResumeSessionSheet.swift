import SwiftUI

struct ResumeSessionSheet: View {
    @EnvironmentObject var store: FleetStore
    @EnvironmentObject var win: WindowState
    @Environment(\.dismiss) private var dismiss

    @State private var sessions: [PastSession]?
    @State private var filter = ""
    @State private var selection: String?
    @State private var name = ""
    @State private var nameEdited = false

    private var filtered: [PastSession] {
        guard let sessions else { return [] }
        guard !filter.isEmpty else { return sessions }
        return sessions.filter {
            $0.preview.localizedCaseInsensitiveContains(filter)
                || $0.cwd.localizedCaseInsensitiveContains(filter)
                || ($0.title?.localizedCaseInsensitiveContains(filter) ?? false)
        }
    }

    private var selected: PastSession? {
        sessions?.first { $0.id == selection }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.secondary)
                Text("Resume Session")
                    .font(.title2.bold())
                Text("Reopen a past Claude conversation as an agent")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 28)
            .padding(.bottom, 24)

            Divider()

            VStack(spacing: 14) {
                field("Search conversations, folders…", text: $filter)
                list
                VStack(alignment: .leading, spacing: 5) {
                    Text("Session name")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    field("fix-auth, refactor-api, … (optional)", text: Binding(
                        get: { name },
                        set: { name = $0; nameEdited = true }))
                }
            }
            .padding(20)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Resume Agent") { resume() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selected == nil)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 520)
        .task {
            let found = await Task.detached(priority: .userInitiated) {
                ClaudeSessionScanner.scan(excluding: ClaudeSessionScanner.liveSessionIds())
            }.value
            sessions = found
        }
        .onChange(of: selection) { _, _ in
            // Suggest the conversation's own title until the user types a name.
            if !nameEdited { name = selected?.title ?? "" }
        }
    }

    @ViewBuilder
    private var list: some View {
        Group {
            if sessions == nil {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filtered.isEmpty {
                Text(filter.isEmpty ? "No past conversations found." : "No matches.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filtered, selection: $selection) { s in
                    row(s).tag(s.id)
                }
            }
        }
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.1)))
    }

    private func row(_ s: PastSession) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(s.title ?? s.preview)
                .lineLimit(1)
            if s.title != nil {
                Text(s.preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text("\(s.projectName) · \(s.updatedAt.formatted(.relative(presentation: .named))) · \(s.promptCount) prompt\(s.promptCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
        .help(s.cwd)
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.1)))
            )
    }

    private func resume() {
        guard let s = selected else { return }
        if let created = store.spawn(directory: s.cwd, task: name, worktree: false, resumeId: s.id) {
            win.selection = created
        }
        dismiss()
    }
}
