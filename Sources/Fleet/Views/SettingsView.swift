import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: FleetStore
    @EnvironmentObject var updater: UpdaterViewModel
    @ObservedObject private var notifications = NotificationManager.shared
    @ObservedObject private var license = LicenseManager.shared
    @State private var licenseKey = ""
    @State private var licenseEmail = ""
    @State private var activating = false

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $store.appearanceMode) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            }
            Section("Updates") {
                HStack {
                    Button("Check for Updates…") { updater.checkForUpdates() }
                        .disabled(!updater.canCheckForUpdates)
                    Spacer()
                    Text("Fleet auto-checks on launch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("License") {
                licenseStatusRow
                if case .active = license.status {} else {
                    // Activation UI — wired up but waiting for payment provider.
                    // Remove the "disabled" modifier and implement activate() in
                    // LicenseManager when Fleet goes paid.
                    TextField("Email", text: $licenseEmail)
                    TextField("License key", text: $licenseKey)
                    HStack {
                        Button {
                            activating = true
                            Task {
                                await license.activate(key: licenseKey, email: licenseEmail)
                                activating = false
                            }
                        } label: {
                            if activating { ProgressView().scaleEffect(0.7) }
                            else { Text("Activate") }
                        }
                        .disabled(true) // remove when payment provider is wired up
                        Spacer()
                        Text("Fleet is free during the preview period")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
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
            if on, store.reposFolder.isEmpty { store.reposFolder = FleetStore.detectGitHome() }
        }
    }

    @ViewBuilder
    private var licenseStatusRow: some View {
        switch license.status {
        case .free:
            Label("Free preview — all features unlocked", systemImage: "gift.fill")
                .foregroundStyle(.green)
        case .active(let email):
            Label("Licensed to \(email)", systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
            Button("Deactivate", role: .destructive) { license.deactivate() }
        case .invalid:
            Label("Invalid license key", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
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
