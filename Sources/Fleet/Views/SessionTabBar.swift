import SwiftUI

/// VS Code-style terminal tabs — each tab is a tmux window, so tabs
/// persist with the session and survive app restarts.
struct SessionTabBar: View {
    @EnvironmentObject var store: FleetStore
    let session: String
    private let separator = Color.white.opacity(0.1)

    var body: some View {
        let tabs = store.tabs[session] ?? []
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                TabChip(session: session, tab: tab, closable: tabs.count > 1)
                Rectangle()
                    .fill(separator)
                    .frame(width: 1, height: 20)
            }
            NewTabButton { store.addTab(session) }
            Spacer(minLength: 0)
        }
        .frame(height: 34)
        // Translucent chrome over the terminal, matching native macOS
        // toolbars — depth without stealing focus from the terminal itself.
        .background(.ultraThinMaterial)
    }
}

private struct NewTabButton: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(hovering ? Color.primary.opacity(0.08) : .clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("New tab in this session (⌘T)")
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.2, dampingFraction: 1), value: hovering)
    }
}

/// One tab. Its own view (not a helper function) so hover state has
/// stable, per-tab identity instead of being reset by parent redraws.
private struct TabChip: View {
    @EnvironmentObject var store: FleetStore
    let session: String
    let tab: SessionTab
    let closable: Bool
    @State private var hovering = false

    /// Matches the terminal view background so the active tab blends into it.
    private let activeBackground = Color(.sRGB, red: 0.117, green: 0.129, blue: 0.157, opacity: 1)

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "terminal")
                .font(.system(size: 11))
                .opacity(tab.active ? 0.9 : 0.55)
            Text(tab.name)
                .font(.system(size: 13, weight: tab.active ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 6)
            if tab.active, closable {
                Button {
                    store.closeTab(session, tab.index)
                } label: {
                    // Match the sidebar cube's close button exactly.
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: store.uiFontSize))
                        .foregroundStyle(tab.active ? Color.white.opacity(0.8) : Color.secondary.opacity(0.7))
                        .scaleEffect(hovering ? 1.12 : 1)
                }
                .buttonStyle(.plain)
                .help("Close tab (⌘W)")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 34)
        .frame(minWidth: 110, maxWidth: 230, alignment: .leading)
        .background(
            tab.active ? activeBackground
                : (hovering ? Color.primary.opacity(0.06) : .clear)
        )
        .overlay(alignment: .top) {
            if tab.active {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2)
            }
        }
        .foregroundStyle(tab.active ? Color.white : Color.secondary)
        // Response: highlight follows the cursor immediately; a quick
        // critically-damped spring on activation, not an instant hard cut.
        .animation(.spring(response: 0.25, dampingFraction: 1), value: tab.active)
        .animation(.spring(response: 0.2, dampingFraction: 1), value: hovering)
        .contentShape(Rectangle())
        .onTapGesture { store.selectTab(session, tab.index) }
        .onHover { hovering = $0 }
    }
}
