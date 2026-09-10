import SwiftUI

struct ShortcutsSettingsView: View {
    @EnvironmentObject var keys: KeybindingStore

    private let groups = ["Agents & Tabs", "Navigation", "Splits", "Zoom"]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(groups, id: \.self) { group in
                        section(group)
                    }
                }
                .padding(16)
            }
            Divider()
            HStack {
                Text("Click a shortcut, press keys to set it · Delete to unbind · Esc to cancel")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Reset All") { keys.resetAll() }
            }
            .padding(12)
        }
        .frame(width: 560, height: 520)
    }

    private func section(_ group: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(group)
                .font(.headline)
                .padding(.bottom, 2)
            ForEach(AppCommand.allCases.filter { $0.group == group }) { cmd in
                row(cmd)
                Divider()
            }
        }
    }

    private func row(_ cmd: AppCommand) -> some View {
        HStack(spacing: 10) {
            Text(cmd.title)
                .frame(maxWidth: .infinity, alignment: .leading)
            if keys.isReserved(cmd) {
                warning("Reserved by macOS — may not work")
            } else if keys.hasConflict(cmd) {
                warning("Also used by another command")
            }
            ShortcutRecorder(
                current: keys.combo(for: cmd),
                conflict: keys.hasConflict(cmd) || keys.isReserved(cmd)
            ) { newCombo in
                keys.set(newCombo, for: cmd)
            }
            Button {
                keys.resetToDefault(cmd)
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(.borderless)
            .help("Reset to default")
            .disabled(!keys.isCustom(cmd))
        }
        .padding(.vertical, 3)
    }

    private func warning(_ text: String) -> some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
            .help(text)
    }
}
