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
    @State private var folderHovered = false

    private var suggestionMode: Bool { store.suggestRepos && !store.reposFolder.isEmpty }

    private var filteredRepos: [String] {
        filter.isEmpty
            ? store.repos
            : store.repos.filter { $0.localizedCaseInsensitiveContains(filter) }
    }

    private var chosenDirectory: String? {
        suggestionMode ? repo.map { store.reposFolder + "/" + $0 } : pickedDir
    }

    private var displayPath: String? {
        chosenDirectory.map { ($0 as NSString).abbreviatingWithTildeInPath }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.secondary)
                Text("New Agent")
                    .font(.title2.bold())
                Text("Pick a folder and optionally name the task")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 28)
            .padding(.bottom, 24)

            Divider()

            VStack(spacing: 14) {
                // Folder picker
                if suggestionMode {
                    repoListSection
                } else {
                    folderCard
                }

                // Task name
                VStack(alignment: .leading, spacing: 5) {
                    Text("Task")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextField("fix-auth, refactor-api, … (optional)", text: $task)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(.white.opacity(0.1))
                                )
                        )
                }

                // Worktree toggle
                Toggle(isOn: $useWorktree) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Separate git worktree")
                            .font(.callout)
                        Text("Run in parallel without switching branches")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .disabled(task.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.04))
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)

            Divider()

            // Footer
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Launch Agent") { launch() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(chosenDirectory == nil)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 440)
        .onAppear {
            if !suggestionMode {
                DispatchQueue.main.async { chooseFolder() }
            }
        }
        .onChange(of: task) { _, newValue in
            if newValue.trimmingCharacters(in: .whitespaces).isEmpty { useWorktree = false }
        }
    }

    // MARK: - Folder card

    private var folderCard: some View {
        Button(action: chooseFolder) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.08))
                        .frame(width: 36, height: 36)
                    Image(systemName: chosenDirectory != nil ? "folder.fill" : "folder.badge.plus")
                        .font(.system(size: 16))
                        .foregroundStyle(chosenDirectory != nil ? .white : .secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let path = displayPath {
                        Text(path)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.head)
                        Text("Click to change folder")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("Choose a folder")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.primary)
                        Text("The agent will start here")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white.opacity(folderHovered ? 0.08 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                chosenDirectory != nil
                                    ? Color.white.opacity(0.12)
                                    : Color.white.opacity(0.08)
                            )
                    )
            )
            .animation(.easeOut(duration: 0.15), value: folderHovered)
        }
        .buttonStyle(.plain)
        .onHover { folderHovered = $0 }
    }

    // MARK: - Repo list (suggestion mode)

    private var repoListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Repository")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            TextField("Filter repos…", text: $filter)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.1)))
                )
            List(filteredRepos, id: \.self, selection: $repo) { name in
                Text(name).tag(name)
            }
            .frame(minHeight: 180)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.08)))
            Text("Repos from \(store.reposFolder) · change in Settings (⌘,)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Actions

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
