import AppKit
import SwiftUI

struct NewAgentSheet: View {
    @EnvironmentObject var store: FleetStore
    @EnvironmentObject var win: WindowState
    @Environment(\.dismiss) private var dismiss

    @State private var filter = ""
    @State private var repo: String?
    @State private var pickedDir: String?
    @State private var task = ""
    @State private var useWorktree = false

    /// Show the repo list only when the user opted in AND set a folder;
    /// otherwise the default flow is picking a folder from macOS.
    private var suggestionMode: Bool { store.suggestRepos && !store.reposFolder.isEmpty }

    private var filteredRepos: [String] {
        filter.isEmpty
            ? store.repos
            : store.repos.filter { $0.localizedCaseInsensitiveContains(filter) }
    }

    private var chosenDirectory: String? {
        suggestionMode ? repo.map { store.reposFolder + "/" + $0 } : pickedDir
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Agent").font(.title2.bold())

            if suggestionMode {
                TextField("Filter repos…", text: $filter)
                    .textFieldStyle(.roundedBorder)
                List(filteredRepos, id: \.self, selection: $repo) { name in
                    Text(name).tag(name)
                }
                .frame(minHeight: 220)
                .border(.separator)
                Text("Repos from \(store.reposFolder) — change in Settings (⌘,)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                folderRow
            }

            TextField("Task name (optional, e.g. fix-auth)", text: $task)
                .textFieldStyle(.roundedBorder)

            Toggle("Run in a separate git worktree (parallel work on the same repo)",
                   isOn: $useWorktree)
                .disabled(task.trimmingCharacters(in: .whitespaces).isEmpty)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Launch Agent") { launch() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(chosenDirectory == nil)
            }
        }
        .padding(20)
        .frame(width: 460)
        // Default flow: open the macOS folder picker right away.
        .onAppear {
            if !suggestionMode {
                DispatchQueue.main.async { chooseFolder() }
            }
        }
        .onChange(of: task) { _, newValue in
            if newValue.trimmingCharacters(in: .whitespaces).isEmpty { useWorktree = false }
        }
    }

    private var folderRow: some View {
        HStack(spacing: 10) {
            Button("Choose Folder…") { chooseFolder() }
            if let pickedDir {
                Text((pickedDir as NSString).abbreviatingWithTildeInPath)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            } else {
                Text("No folder chosen")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func launch() {
        guard let dir = chosenDirectory else { return }
        if let name = store.spawn(directory: dir, task: task, worktree: useWorktree) {
            win.selection = name
        }
        dismiss()
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Use Folder"
        panel.message = "Choose a folder to start an agent in"
        if !store.reposFolder.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: store.reposFolder)
        }
        if panel.runModal() == .OK, let url = panel.url {
            pickedDir = url.path
        }
    }
}
