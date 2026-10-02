import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: FleetStore
    @StateObject private var win = WindowState()
    @State private var showWelcome = !UserDefaults.standard.bool(forKey: "hasSeenWelcome")

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240)
                .toolbar {
                    ToolbarItem {
                        Button {
                            win.showNewAgent = true
                        } label: {
                            Label("New Agent", systemImage: "plus")
                        }
                        .help("Launch a new agent (⌘N)")
                    }
                }
        } detail: {
            if store.installingTools || !store.preflightIssues.isEmpty {
                PreflightBanner(issues: store.preflightIssues, installing: store.installingTools)
            } else if let selected = win.selection {
                VStack(spacing: 0) {
                    SessionTabBar(session: selected)
                    TerminalHostView(session: selected, cache: win.terminals)
                        .id(selected) // fresh container per session — never reuse across switches
                }
                .ignoresSafeArea(.container, edges: .bottom)
            } else {
                ContentUnavailableView(
                    "No agent selected",
                    systemImage: "sparkles.rectangle.stack",
                    description: Text("Pick an agent in the sidebar or press ⌘N to launch one.")
                )
            }
        }
        .environmentObject(win)
        .focusedSceneObject(win)
        .sheet(isPresented: $win.showNewAgent) {
            NewAgentSheet()
                .environmentObject(win)
        }
        .sheet(isPresented: $showWelcome, onDismiss: {
            UserDefaults.standard.set(true, forKey: "hasSeenWelcome")
        }) {
            WelcomeSheet()
        }
        .alert("Fleet",
               isPresented: Binding(
                   get: { store.lastError != nil },
                   set: { if !$0 { store.lastError = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.lastError ?? "")
        }
        .onChange(of: store.pendingSelection) { _, pending in
            // A clicked notification asked to open this session; the first
            // window to react claims it, then clears the request.
            if let pending {
                win.selection = pending
                store.pendingSelection = nil
            }
        }
        .onChange(of: win.selection) { _, sel in
            store.markSeen(sel)
            // Remember the last thing looked at so reopening lands here again.
            if let sel { UserDefaults.standard.set(sel, forKey: "lastSelection") }
        }
        .onChange(of: store.sessions) { _, updated in
            let names = updated.map(\.name)
            // Reconcile on every session-list change: restores the persisted
            // selection once sessions load at launch, and clears one whose
            // session was retired or killed.
            win.selection = SelectionRestore.resolve(
                current: win.selection,
                stored: UserDefaults.standard.string(forKey: "lastSelection"),
                existing: names)
            store.markSeen(win.selection)
        }
        .navigationTitle(win.selection ?? "Fleet")
    }
}
