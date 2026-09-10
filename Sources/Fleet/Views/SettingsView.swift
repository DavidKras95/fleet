import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: FleetStore
    @ObservedObject private var notifications = NotificationManager.shared

    var body: some View {
        Form {
            Section("New Agent") {
                Toggle("Start Claude Code automatically in new sessions", isOn: $store.autoStartClaude)
                Toggle("Suggest repositories from a folder", isOn: $store.suggestRepos)
                Text(store.suggestRepos
                     ? "New Agent lists git repos from the folder below."
                     : "New Agent opens the macOS folder picker (default).")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if store.suggestRepos {
                    HStack {
                        TextField("Repos folder", text: $store.reposFolder)
                        Button("Choose…") { chooseFolder() }
                    }
                    Text(store.reposFolder.isEmpty
                         ? "Pick a folder that contains your git repos."
                         : "\(store.repos.count) git repositories found in this folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Notifications") {
                switch notifications.authorized {
                case .some(true):
                    Label("Notifications allowed — banners come from Fleet", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .some(false):
                    Label("Not authorized — using a fallback banner (via Script Editor)",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Unsigned dev builds can't hold notification permission (the signature changes every build). A Developer-ID-signed build fixes this. The Dock icon still bounces when an agent needs you.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .none:
                    Label("Notification permission not determined yet", systemImage: "questionmark.circle")
                        .foregroundStyle(.secondary)
                }
            }
            Section("Worktrees") {
                TextField("Branch prefix", text: $store.branchPrefix)
                Text("Opt-in worktree agents branch as \(store.branchPrefix)/<task> under \(store.worktreesRoot)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: store.suggestRepos) { _, on in
            // Prefill a sensible folder the first time suggestions are enabled.
            if on, store.reposFolder.isEmpty { store.reposFolder = FleetStore.detectGitHome() }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if !store.reposFolder.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: store.reposFolder)
        }
        panel.prompt = "Use as Repos Folder"
        if panel.runModal() == .OK, let url = panel.url {
            store.reposFolder = url.path
        }
    }
}
