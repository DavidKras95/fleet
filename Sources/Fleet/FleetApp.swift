import SwiftUI

@main
struct FleetApp: App {
    @StateObject private var store = FleetStore()
    @StateObject private var keys = KeybindingStore()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(store)
                .onAppear {
                    EnvironmentSetup.ensure()
                    NotificationManager.shared.configure()
                    NotificationManager.shared.onOpenSession = { session in
                        store.pendingSelection = session
                    }
                    store.startPolling()
                }
                .frame(minWidth: 900, minHeight: 560)
        }
        .commands { FleetCommands(store: store, keys: keys) }

        Settings {
            TabView {
                SettingsView()
                    .environmentObject(store)
                    .tabItem { Label("General", systemImage: "gearshape") }
                ShortcutsSettingsView()
                    .environmentObject(keys)
                    .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            }
        }
    }
}

/// Menu commands act on the frontmost window's state, and read their key
/// equivalents from the KeybindingStore so they can be remapped live.
struct FleetCommands: Commands {
    @ObservedObject var store: FleetStore
    @ObservedObject var keys: KeybindingStore
    @FocusedObject private var win: WindowState?
    @Environment(\.openWindow) private var openWindow

    private func sc(_ cmd: AppCommand) -> KeyboardShortcut? { keys.combo(for: cmd)?.keyboardShortcut }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Agent…") { win?.showNewAgent = true }
                .keyboardShortcut(sc(.newAgent))
                .disabled(win == nil)
            Button("New Window") { openWindow(id: "main") }
                .keyboardShortcut(sc(.newWindow))
            Divider()
            Button("New Tab") {
                if let s = win?.selection { store.addTab(s) }
            }
            .keyboardShortcut(sc(.newTab))
            .disabled(win?.selection == nil)
            Button("Close Pane / Tab") {
                if let s = win?.selection { store.smartClose(s) }
            }
            .keyboardShortcut(sc(.closePaneTab))
            .disabled(win?.selection == nil)
            Button("Previous Tab") {
                if let s = win?.selection { store.stepTab(s, offset: -1) }
            }
            .keyboardShortcut(sc(.prevTab))
            .disabled(win?.selection == nil)
            Button("Next Tab") {
                if let s = win?.selection { store.stepTab(s, offset: +1) }
            }
            .keyboardShortcut(sc(.nextTab))
            .disabled(win?.selection == nil)
            ForEach(1..<10) { i in
                Button("Go to Tab \(i)") {
                    if let s = win?.selection { store.selectTab(s, i) }
                }
                .keyboardShortcut(KeyEquivalent(Character("\(i)")), modifiers: .command)
                .disabled(win?.selection == nil)
            }
            Button("Jump to Waiting Agent") {
                if let win, let next = store.nextWaiting(after: win.selection) { win.selection = next }
            }
            .keyboardShortcut(sc(.jumpWaiting))
            .disabled(win == nil)
            Divider()
            Button("Previous Agent") {
                if let win, let prev = store.neighbor(of: win.selection, offset: -1) { win.selection = prev }
            }
            .keyboardShortcut(sc(.prevAgent))
            .disabled(win == nil)
            Button("Next Agent") {
                if let win, let next = store.neighbor(of: win.selection, offset: +1) { win.selection = next }
            }
            .keyboardShortcut(sc(.nextAgent))
            .disabled(win == nil)
        }
        CommandGroup(after: .toolbar) {
            Divider()
            Menu("Split") {
                Button("Split Right") { if let s = win?.selection { store.split(s, vertical: false) } }
                    .keyboardShortcut(sc(.splitRight))
                Button("Split Down") { if let s = win?.selection { store.split(s, vertical: true) } }
                    .keyboardShortcut(sc(.splitDown))
                Divider()
                Button("Focus Left") { if let s = win?.selection { store.focusPane(s, "L") } }
                    .keyboardShortcut(sc(.focusLeft))
                Button("Focus Right") { if let s = win?.selection { store.focusPane(s, "R") } }
                    .keyboardShortcut(sc(.focusRight))
                Button("Focus Up") { if let s = win?.selection { store.focusPane(s, "U") } }
                    .keyboardShortcut(sc(.focusUp))
                Button("Focus Down") { if let s = win?.selection { store.focusPane(s, "D") } }
                    .keyboardShortcut(sc(.focusDown))
                Divider()
                Button("Resize Left") { if let s = win?.selection { store.resizePane(s, "L") } }
                    .keyboardShortcut(sc(.resizeLeft))
                Button("Resize Right") { if let s = win?.selection { store.resizePane(s, "R") } }
                    .keyboardShortcut(sc(.resizeRight))
                Button("Resize Up") { if let s = win?.selection { store.resizePane(s, "U") } }
                    .keyboardShortcut(sc(.resizeUp))
                Button("Resize Down") { if let s = win?.selection { store.resizePane(s, "D") } }
                    .keyboardShortcut(sc(.resizeDown))
                Divider()
                Button("Even Halves (side by side)") { if let s = win?.selection { store.setLayout(s, "even-horizontal") } }
                    .keyboardShortcut(sc(.layoutEvenH))
                Button("Even Halves (stacked)") { if let s = win?.selection { store.setLayout(s, "even-vertical") } }
                    .keyboardShortcut(sc(.layoutEvenV))
                Button("Quadrants (tiled)") { if let s = win?.selection { store.setLayout(s, "tiled") } }
                    .keyboardShortcut(sc(.layoutTiled))
                Button("Cycle Layout") { if let s = win?.selection { store.cycleLayout(s) } }
                    .keyboardShortcut(sc(.cycleLayout))
            }
            .disabled(win?.selection == nil)
            Divider()
            Button("Zoom Terminal In") { store.zoomTerminal(+1) }
                .keyboardShortcut(sc(.zoomTermIn))
            Button("Zoom Terminal Out") { store.zoomTerminal(-1) }
                .keyboardShortcut(sc(.zoomTermOut))
            Button("Zoom App In") { store.zoomUI(+1) }
                .keyboardShortcut(sc(.zoomAppIn))
            Button("Zoom App Out") { store.zoomUI(-1) }
                .keyboardShortcut(sc(.zoomAppOut))
            Divider()
        }
    }
}
