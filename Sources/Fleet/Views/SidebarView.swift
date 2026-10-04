import SwiftUI
import UniformTypeIdentifiers

/// Reference boxes so the middle-click event monitor always sees current
/// values (escaping closures capture view-struct copies otherwise).
@MainActor
private final class SidebarClickContext {
    weak var window: NSWindow?
    var rowFrames: [String: CGRect] = [:]
}

private struct NewAgentButton: View {
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .scaleEffect(hovered ? 1.15 : 1.0)
                Text("New Agent")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(hovered ? Color.white : Color.white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(hovered ? 0.08 : 0))
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hovered)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

struct SidebarView: View {
    @EnvironmentObject var store: FleetStore
    @EnvironmentObject var win: WindowState
    @State private var dragged: String?
    @State private var confirmClose: String?
    @State private var renaming: String?
    @State private var renameText = ""
    @State private var clickContext = SidebarClickContext()
    @State private var clickMonitor: Any?

    var body: some View {
        List {
            if store.sessions.isEmpty {
                Text("No agents yet.\nPress ⌘N to launch one.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            ForEach(store.displaySessions) { session in
                SessionRow(session: session, selected: win.selection == session.name)
                    .environmentObject(store)
                    .environmentObject(win)
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: RowFramesKey.self,
                                               value: [session.name: geo.frame(in: .global)])
                    })
                    .opacity(dragged == session.name ? 0.35 : 1)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                    .contextMenu {
                        Button("Rename…") {
                            renameText = session.task ?? ""
                            renaming = session.name
                        }
                        Button("Retire Agent", role: .destructive) {
                            store.retire(session.name)
                        }
                    }
                    .onDrag {
                        dragged = session.name
                        return NSItemProvider(object: session.name as NSString)
                    }
                    .onDrop(
                        of: [UTType.plainText],
                        delegate: SessionReorderDelegate(
                            target: session.name,
                            dragged: $dragged,
                            store: store
                        )
                    )
            }
            NewAgentButton { win.showNewAgent = true }
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
        }
        .listStyle(.sidebar)
        .onDrop(of: [UTType.plainText], isTargeted: nil) { _ in
            dragged = nil
            return true
        }
        .onPreferenceChange(RowFramesKey.self) { [context = clickContext] frames in
            Task { @MainActor in context.rowFrames = frames }
        }
        .background(WindowAccessor { [context = clickContext] window in
            context.window = window
        })
        .onAppear { installMiddleClickMonitor() }
        .onDisappear {
            if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
            clickMonitor = nil
        }
        .alert(
            "Close \(confirmClose ?? "this agent")?",
            isPresented: Binding(
                get: { confirmClose != nil },
                set: { if !$0 { confirmClose = nil } })
        ) {
            Button("Close Agent", role: .destructive) {
                if let name = confirmClose { store.retire(name) }
                confirmClose = nil
            }
            Button("Cancel", role: .cancel) { confirmClose = nil }
        } message: {
            Text("This ends its tmux session. A running Claude conversation can be resumed later with claude --resume.")
        }
        .alert(
            "Rename Agent",
            isPresented: Binding(
                get: { renaming != nil },
                set: { if !$0 { renaming = nil } })
        ) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                if let old = renaming { store.rename(old, to: renameText) }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        } message: {
            Text("This becomes the agent's new task name.")
        }
        .safeAreaInset(edge: .bottom) {
            if store.waitingCount > 0 {
                Label("\(store.waitingCount) waiting — ⌘⏎ to jump", systemImage: "bell.fill")
                    .font(.system(size: store.uiFontSize - 1).bold())
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(6)
                    .background(.red.opacity(0.15), in: Rectangle())
                    .background(.ultraThinMaterial, in: Rectangle())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 1), value: store.waitingCount > 0)
    }

    /// Middle-click on a cube asks to close that agent. SwiftUI has no
    /// middle-click gesture, so we watch AppKit events and hit-test against
    /// the tracked cube frames (SwiftUI global space matches the flipped
    /// hosting view's coordinates).
    private func installMiddleClickMonitor() {
        guard clickMonitor == nil else { return }
        let context = clickContext
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown) { event in
            guard event.buttonNumber == 2,
                  let window = event.window,
                  window === context.window,
                  let content = window.contentView
            else { return event }
            let point = content.convert(event.locationInWindow, from: nil)
            if let hit = context.rowFrames.first(where: { $0.value.contains(point) }) {
                confirmClose = hit.key
                return nil
            }
            return event
        }
    }
}

/// One sidebar cube. Its own view (not a helper function) so hover state
/// has stable, per-row identity instead of being reset by parent redraws.
private struct SessionRow: View {
    @EnvironmentObject var store: FleetStore
    @EnvironmentObject var win: WindowState
    let session: AgentSession
    let selected: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 9) {
            StatusBadge(state: session.state,
                        size: store.uiFontSize + 2,
                        unseen: store.unseenDone.contains(session.name))
            VStack(alignment: .leading, spacing: 1) {
                // Every cube shows its project — consistent shape whether or
                // not this session has a task name of its own.
                Text(session.displayCaption)
                    .font(.system(size: max(9, store.uiFontSize - 4), weight: .medium))
                    .foregroundStyle(selected ? Color.white.opacity(0.75) : Color.secondary)
                    .lineLimit(1)
                Text(session.displayTitle)
                    .font(.system(size: store.uiFontSize + 1,
                                  weight: selected || session.state == .input ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.white : Color.primary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Button {
                store.retire(session.name)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: store.uiFontSize))
                    .foregroundStyle(selected ? Color.white.opacity(0.8) : Color.secondary.opacity(0.7))
                    .scaleEffect(hovering ? 1.12 : 1)
            }
            .buttonStyle(.plain)
            .help("Close this agent (kills its session)")
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(selected ? Color.accentColor : Color.primary.opacity(hovering ? 0.09 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(
                    selected
                        ? Color.accentColor
                        : (session.state == .input ? Color.red.opacity(0.75) : Color.primary.opacity(0.08)),
                    lineWidth: session.state == .input && !selected ? 1.5 : 1
                )
        )
        // Response: instant feedback under the cursor, no debounce; a quick
        // critically-damped spring on state/selection changes instead of a
        // hard cut (Apple's "default UI spring" — damping 1.0, response ~0.3).
        .scaleEffect(hovering && !selected ? 1.01 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 1), value: selected)
        .animation(.spring(response: 0.2, dampingFraction: 1), value: hovering)
        .contentShape(RoundedRectangle(cornerRadius: 9))
        .onTapGesture { win.selection = session.name }
        .onHover { hovering = $0 }
    }
}

private struct RowFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// Hands the hosting NSWindow to SwiftUI code that needs it.
private struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { onWindow(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { onWindow(nsView.window) }
    }
}

/// Live drag-reorder: as the dragged cube passes over another cube, the
/// list reorders immediately, anywhere in the sidebar.
struct SessionReorderDelegate: DropDelegate {
    let target: String
    @Binding var dragged: String?
    let store: FleetStore

    func dropEntered(info: DropInfo) {
        guard let dragged, dragged != target else { return }
        MainActor.assumeIsolated {
            store.reorder(dragged: dragged, over: target)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragged = nil
        return true
    }
}

/// Animated status indicator: pulsing red light for "needs input",
/// spinning ring while working, static marks otherwise. Every animated
/// variant has a still equivalent for Reduce Motion — status stays legible
/// (color, ring vs. dot) without any motion.
struct StatusBadge: View {
    let state: AgentSession.State
    let size: CGFloat
    var unseen: Bool = false
    @State private var animating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch state {
            case .input:
                Circle()
                    .fill(Color.red)
                    .frame(width: size * 0.7, height: size * 0.7)
                    .shadow(color: .red.opacity(0.9), radius: pulseOn ? 5 : 0.5)
                    .opacity(pulseOn ? 1 : 0.25)
                    .animation(
                        reduceMotion ? nil
                            : .easeInOut(duration: 0.45).repeatForever(autoreverses: true),
                        value: pulseOn)
            case .busy:
                if reduceMotion {
                    // Static equivalent: a ring instead of a full dot reads
                    // as "different from idle" without relying on motion.
                    Circle()
                        .trim(from: 0, to: 0.72)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: max(2, size * 0.16), lineCap: .round))
                        .frame(width: size * 0.7, height: size * 0.7)
                        .rotationEffect(.degrees(-90))
                } else {
                    // Angle comes straight from the wall clock (not a toggled
                    // @State) so redraws from the 1s status poll can never
                    // restart or stutter the spin — it just keeps going.
                    TimelineView(.animation) { timeline in
                        let seconds = timeline.date.timeIntervalSinceReferenceDate
                        let angle = (seconds.truncatingRemainder(dividingBy: 1)) * 360
                        Circle()
                            .trim(from: 0, to: 0.72)
                            .stroke(Color.orange, style: StrokeStyle(lineWidth: max(2, size * 0.16), lineCap: .round))
                            .frame(width: size * 0.7, height: size * 0.7)
                            .rotationEffect(.degrees(angle))
                    }
                }
            case .done:
                if unseen {
                    Circle()
                        .fill(Color.green)
                        .frame(width: size * 0.7, height: size * 0.7)
                        .shadow(color: .green.opacity(0.9), radius: pulseOn ? 5 : 0.5)
                        .opacity(pulseOn ? 1 : 0.25)
                        .animation(
                            reduceMotion ? nil
                                : .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                            value: pulseOn)
                } else {
                    Circle()
                        .fill(Color.green)
                        .frame(width: size * 0.7, height: size * 0.7)
                        .shadow(color: .green.opacity(0.5), radius: 1)
                }
            case .idle:
                Circle()
                    .fill(Color.secondary.opacity(0.45))
                    .frame(width: size * 0.7, height: size * 0.7)
            }
        }
        .frame(width: size + 6, height: size + 6)
        .onAppear { animating = true }
        .onChange(of: state) { _, _ in restartAnimation() }
        .onChange(of: unseen) { _, _ in restartAnimation() }
    }

    /// Reduce Motion still needs full opacity for the "unseen" pulse states
    /// so their color reads correctly — only the looping motion is dropped.
    private var pulseOn: Bool { reduceMotion ? true : animating }

    private func restartAnimation() {
        guard !reduceMotion else { return }
        animating = false
        DispatchQueue.main.async { animating = true }
    }
}
