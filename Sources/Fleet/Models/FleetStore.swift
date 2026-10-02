import AppKit
import Foundation

@MainActor
final class FleetStore: ObservableObject {
    @Published var sessions: [AgentSession] = []
    @Published var lastError: String?
    /// Sessions that finished a turn and haven't been looked at yet
    /// ("unread message" logic — their ✅ blinks until selected).
    @Published var unseenDone: Set<String> = []
    /// Set when a notification is clicked; a window applies and clears it.
    @Published var pendingSelection: String?
    /// Missing-dependency warnings shown as a banner (empty = all good).
    @Published var preflightIssues: [PreflightIssue] = []
    /// True while Homebrew is installing missing tools in the background.
    @Published var installingTools = false
    /// Sessions whose `claude` process is still starting up (spawned with
    /// autoStartClaude; cleared as soon as the first hook event arrives).
    @Published var initializingSessions: Set<String> = []

    /// Pure helper: given the current initializing set and the latest session
    /// list, returns which names should remain initializing (still idle and
    /// still alive). Exposed for unit testing.
    nonisolated static func pendingInitializing(current: Set<String>, sessions: [AgentSession]) -> Set<String> {
        let idleAlive = Set(sessions.filter { $0.state == .idle }.map(\.name))
        return current.intersection(idleAlive)
    }
    /// Tabs per session = tmux windows of that session.
    @Published var tabs: [String: [SessionTab]] = [:]

    /// Optional folder whose git repos are offered as quick suggestions in
    /// the New Agent sheet. Empty by default — the default flow is picking a
    /// folder from macOS. (Key kept as "gitHome" so existing config migrates.)
    @Published var reposFolder: String {
        didSet { UserDefaults.standard.set(reposFolder, forKey: "gitHome") }
    }
    /// Opt-in: when on (and reposFolder is set), New Agent lists repos to pick
    /// from; when off, it opens the macOS folder picker.
    @Published var suggestRepos: Bool {
        didSet { UserDefaults.standard.set(suggestRepos, forKey: "suggestRepos") }
    }
    /// Run `claude` automatically in a freshly spawned session (tabs and
    /// split panes stay plain shells).
    @Published var autoStartClaude: Bool {
        didSet { UserDefaults.standard.set(autoStartClaude, forKey: "autoStartClaude") }
    }
    @Published var branchPrefix: String {
        didSet { UserDefaults.standard.set(branchPrefix, forKey: "branchPrefix") }
    }
    @Published var terminalFontSize: CGFloat {
        didSet {
            UserDefaults.standard.set(terminalFontSize, forKey: "terminalFontSize")
            TerminalCache.applyFontSizeToAll(terminalFontSize)
        }
    }
    @Published var uiFontSize: CGFloat {
        didSet { UserDefaults.standard.set(uiFontSize, forKey: "uiFontSize") }
    }
    /// User-arranged sidebar order (drag & drop), persisted across launches.
    @Published var order: [String] {
        didSet { UserDefaults.standard.set(order, forKey: "sessionOrder") }
    }

    /// Worktrees live in one global place so a session can be started from
    /// any folder, not just one under a configured repos folder.
    var worktreesRoot: String { NSHomeDirectory() + "/.cache/fleet/worktrees" }
    /// The legacy CLI mosaic session is a container of panes, not one agent.
    private let ignoredSessions: Set<String> = ["fleet", "hub"]
    private var timer: Timer?

    init() {
        let defaults = UserDefaults.standard
        reposFolder = defaults.string(forKey: "gitHome") ?? ""
        suggestRepos = defaults.bool(forKey: "suggestRepos")
        // Default ON; bool(forKey:) would default a missing key to false.
        autoStartClaude = defaults.object(forKey: "autoStartClaude") as? Bool ?? true
        branchPrefix = defaults.string(forKey: "branchPrefix") ?? Self.defaultBranchPrefix()
        let termSize = defaults.double(forKey: "terminalFontSize")
        terminalFontSize = termSize > 0 ? termSize : 13
        let uiSize = defaults.double(forKey: "uiFontSize")
        uiFontSize = uiSize > 0 ? uiSize : 13
        order = defaults.stringArray(forKey: "sessionOrder") ?? []
        TerminalCache.fontSize = terminalFontSize
    }

    /// Sessions in stable, user-arranged order (drag to rearrange freely).
    var displaySessions: [AgentSession] {
        let index = Dictionary(order.enumerated().map { ($1, $0) },
                               uniquingKeysWith: { first, _ in first })
        return sessions.sorted {
            (index[$0.name] ?? Int.max, $0.name.localizedLowercase)
                < (index[$1.name] ?? Int.max, $1.name.localizedLowercase)
        }
    }

    /// All sessions in the order the sidebar displays them.
    var flatOrder: [String] { displaySessions.map(\.name) }

    /// Live drag-reorder: place `dragged` at `target`'s current position.
    func reorder(dragged: String, over target: String) {
        var names = flatOrder
        guard let from = names.firstIndex(of: dragged),
              let to = names.firstIndex(of: target),
              from != to
        else { return }
        names.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        order = names
    }

    /// The session above/below `current` in display order, wrapping around.
    func neighbor(of current: String?, offset: Int) -> String? {
        let flat = flatOrder
        guard !flat.isEmpty else { return nil }
        guard let cur = current, let i = flat.firstIndex(of: cur) else {
            return offset > 0 ? flat.first : flat.last
        }
        return flat[(i + offset + flat.count) % flat.count]
    }


    func zoomTerminal(_ delta: CGFloat) {
        terminalFontSize = min(28, max(8, terminalFontSize + delta))
    }

    func zoomUI(_ delta: CGFloat) {
        uiFontSize = min(22, max(10, uiFontSize + delta))
    }

    /// A sensible default repos folder to prefill the setting when the user
    /// turns suggestions on without having chosen one.
    static func detectGitHome() -> String {
        let home = NSHomeDirectory()
        let fm = FileManager.default
        for candidate in ["git", "code", "dev", "src", "repos", "Projects", "workspace"] {
            var isDir: ObjCBool = false
            let path = home + "/" + candidate
            if fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                return path
            }
        }
        return home
    }

    static func defaultBranchPrefix() -> String {
        let user = NSUserName().lowercased().replacingOccurrences(of: " ", with: "_")
        return user.isEmpty ? "agent" : user
    }

    /// Git repos under the configured repos folder (empty when unset).
    var repos: [String] {
        guard !reposFolder.isEmpty else { return [] }
        let fm = FileManager.default
        let entries = (try? fm.contentsOfDirectory(atPath: reposFolder)) ?? []
        return entries
            .filter { fm.fileExists(atPath: reposFolder + "/\($0)/.git") }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var waitingCount: Int { sessions.filter { $0.state == .input }.count }

    /// Resolves a name collision by numbering: an empty task becomes
    /// "session-2", "session-3", … on repeat launches; a given task becomes
    /// "task-2", "task-3", … Right-click → Rename lets you replace this.
    private func uniqueTask(repo: String, desired: String, excluding: String? = nil) -> String {
        SessionNaming.uniqueTask(repo: repo, desired: desired,
                                 existing: sessions.map(\.name), excluding: excluding)
    }

    /// Renames a session's task, right-click → Rename. Keeps its repo
    /// prefix (grouping/display derive the repo from that), migrates the
    /// tmux session and every window/cache that references the old name.
    func rename(_ oldName: String, to newTaskRaw: String) {
        guard let session = sessions.first(where: { $0.name == oldName }) else { return }
        let cleaned = SessionNaming.sanitize(newTaskRaw)
        guard !cleaned.isEmpty else { lastError = "Name can't be empty."; return }
        let repo = session.repo
        let task = uniqueTask(repo: repo, desired: cleaned, excluding: oldName)
        let newName = "\(repo)/\(task)"
        guard newName != oldName else { return }

        guard Tmux.run(["rename-session", "-t", "=\(oldName)", newName]).status == 0 else {
            lastError = "Could not rename \(oldName)."
            return
        }
        Tmux.run(["set", "-pq", "-t", "=\(newName):", "@fleet_name", newName])

        if let idx = order.firstIndex(of: oldName) { order[idx] = newName }
        if unseenDone.remove(oldName) != nil { unseenDone.insert(newName) }
        WindowState.renamed(from: oldName, to: newName)
        TerminalCache.renamed(from: oldName, to: newName)
        refresh()
    }

    /// Reads the status file keyed by Claude's own session_id — precise to
    /// this exact process, so two sessions sharing a directory never
    /// collide (unlike the cwd-keyed fallback below).
    nonisolated private static func sessionIdState(_ sid: String) -> AgentSession.State? {
        guard !sid.isEmpty else { return nil }
        let file = NSHomeDirectory() + "/.cache/fleet/session-state/\(sid).state"
        guard let raw = try? String(contentsOfFile: file, encoding: .utf8) else { return nil }
        return AgentSession.State(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Reads the cwd-keyed fallback status file — last resort, only for a
    /// process that has NEVER touched a tmux pane (so no session_id link
    /// was ever recorded). Can be shared by multiple sessions in the same
    /// directory; only consulted when nothing more precise exists.
    nonisolated private static func cwdState(forPath path: String) -> AgentSession.State? {
        guard !path.isEmpty else { return nil }
        let key = path.replacingOccurrences(of: "/", with: "_")
        let file = NSHomeDirectory() + "/.cache/fleet/cwd-state/\(key).state"
        guard let raw = try? String(contentsOfFile: file, encoding: .utf8) else { return nil }
        return AgentSession.State(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func runPreflight() {
        preflightIssues = Preflight.issues(
            tmuxAvailable: Executables.isAvailable("tmux"),
            jqAvailable: Executables.isAvailable("jq"),
            claudeAvailable: Executables.isAvailable("claude"),
            brewAvailable: Executables.isAvailable("brew"))
    }

    func startPolling() {
        guard timer == nil else { return }
        runPreflight()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        // Auto-install tmux/jq via Homebrew if they're missing; re-run preflight
        // after so the banner clears as soon as installation succeeds.
        let needsInstall = !Executables.isAvailable("tmux") || !Executables.isAvailable("jq")
        if needsInstall { installingTools = true }
        EnvironmentSetup.installMissingTools { [weak self] in
            self?.installingTools = false
            self?.runPreflight()
        }
    }

    func refresh() {
        let ignored = ignoredSessions
        Task.detached(priority: .utility) {
            // Authoritative session list — any name the pane query produces
            // that isn't here (e.g. a malformed, separator-collapsed row) is
            // dropped rather than shown as a bogus session.
            let (sStatus, sOut) = Tmux.run(["list-sessions", "-F", "#{session_name}"])
            let validSessions: Set<String>? = sStatus == 0
                ? Set(sOut.split(separator: "\n").map(String.init))
                : nil

            let (status, out) = Tmux.run(["list-panes", "-a", "-F",
                                          "#{session_name}\t#{@fleet_state}\t#{pane_current_path}\t#{@fleet_sid}"])
            let paneLines = status == 0 ? out.split(separator: "\n").map(String.init) : []
            let states = StatusResolver.resolve(
                paneLines: paneLines,
                ignoredSessions: ignored,
                validSessions: validSessions,
                sessionIdState: Self.sessionIdState,
                cwdState: Self.cwdState(forPath:))

            let (wStatus, wOut) = Tmux.run(["list-windows", "-a", "-F",
                                            "#{session_name}\t#{window_index}\t#{window_name}\t#{window_active}"])
            var tabMap: [String: [SessionTab]] = [:]
            if wStatus == 0 {
                for line in wOut.split(separator: "\n") {
                    let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
                    guard parts.count >= 4, !ignored.contains(String(parts[0])),
                          let index = Int(parts[1]) else { continue }
                    tabMap[String(parts[0]), default: []]
                        .append(SessionTab(index: index, name: String(parts[2]), active: parts[3] == "1"))
                }
            }
            let result = states
                .map { AgentSession(name: $0.key, state: $0.value) }
                .sorted {
                    ($0.state.priority, $0.name.localizedLowercase) < ($1.state.priority, $1.name.localizedLowercase)
                }
            await MainActor.run { [result, tabMap] in
                let store = self
                if store.tabs != tabMap { store.tabs = tabMap }
                // Only publish real changes so the 1s poll doesn't disturb
                // row animations or reset in-flight UI.
                if store.sessions != result {
                    let previous = Dictionary(uniqueKeysWithValues: store.sessions.map { ($0.name, $0.state) })
                    for s in result {
                        if s.state == .done, let old = previous[s.name], old != .done {
                            store.unseenDone.insert(s.name)
                        } else if s.state != .done {
                            store.unseenDone.remove(s.name)
                        }
                    }
                    store.unseenDone.formIntersection(result.map(\.name))
                    // Notify once when a session newly needs input — posted by
                    // the app so clicking the banner opens Fleet, not osascript.
                    let current = Dictionary(uniqueKeysWithValues: result.map { ($0.name, $0.state) })
                    let needing = NotificationTrigger.newlyNeedingInput(previous: previous, current: current)
                    for name in needing {
                        NotificationManager.shared.notifyNeedsInput(session: name)
                    }
                    if !needing.isEmpty {
                        // Bounce the Dock icon until Fleet is activated —
                        // no-op while Fleet is already frontmost.
                        NSApp.requestUserAttention(.criticalRequest)
                    }
                    store.sessions = result
                    NSApp.dockTile.badgeLabel = store.waitingCount > 0 ? "\(store.waitingCount)" : ""
                }
                // Always re-evaluate — must not be inside the sessions-changed
                // guard or a constant-result poll will never clear the spinner.
                if !store.initializingSessions.isEmpty {
                    store.initializingSessions = FleetStore.pendingInitializing(
                        current: store.initializingSessions, sessions: result)
                }
            }
        }
    }

    /// Starts a session in any folder. Returns the session name on success.
    @discardableResult
    func spawn(directory: String, task: String, worktree: Bool) -> String? {
        let base = SessionNaming.baseName(forDirectory: directory)
        let requestedTask = SessionNaming.sanitize(task)
        // "New Agent" always creates a NEW session — multiple sessions of the
        // same directory are exactly the point, so a name collision gets an
        // auto-numbered task instead of silently jumping to the old one.
        // Use a fresh tmux query rather than self.sessions: on first launch
        // the async poll may not have run yet, leaving sessions empty and
        // causing a false "name is free" result for sessions that already exist.
        let (lsStatus, lsOut) = Tmux.run(["list-sessions", "-F", "#{session_name}"])
        let liveNames: [String] = lsStatus == 0
            ? lsOut.split(separator: "\n").map(String.init)
            : sessions.map(\.name)
        let task = SessionNaming.uniqueTask(repo: base, desired: requestedTask, existing: liveNames)
        let name = task.isEmpty ? base : "\(base)/\(task)"

        var dir = directory
        if worktree {
            guard !task.isEmpty else {
                lastError = "A worktree needs a task name."
                return nil
            }
            let wt = "\(worktreesRoot)/\(base)/\(task)"
            if !FileManager.default.fileExists(atPath: wt) {
                try? FileManager.default.createDirectory(
                    atPath: (wt as NSString).deletingLastPathComponent,
                    withIntermediateDirectories: true)
                let branch = "\(branchPrefix)/\(task)"
                if Tmux.git(in: directory, ["worktree", "add", "-b", branch, wt]) != 0,
                   Tmux.git(in: directory, ["worktree", "add", wt, branch]) != 0 {
                    lastError = "Could not create worktree for \(name) — is \(base) a git repo?"
                    return nil
                }
            }
            dir = wt
        }

        guard Tmux.run(["new-session", "-d", "-s", name, "-c", dir]).status == 0 else {
            lastError = "tmux could not create session \(name)."
            return nil
        }
        Tmux.run(["set", "-t", "=\(name)", "prefix", "None"])
        Tmux.run(["set", "-pq", "-t", "=\(name):", "@fleet_name", name])
        if worktree {
            Tmux.run(["set", "-pq", "-t", "=\(name):", "@fleet_wt", dir])
            // Source repo dir, so the worktree can be removed on retire.
            Tmux.run(["set", "-pq", "-t", "=\(name):", "@fleet_srcdir", directory])
        }
        if autoStartClaude {
            // Typed into the shell (not exec'd) so the shell survives if
            // claude exits, and the user's PATH/aliases apply.
            Tmux.run(["send-keys", "-t", "=\(name):", "claude", "Enter"])
            initializingSessions.insert(name)
            let sessionName = name
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(30))
                self?.initializingSessions.remove(sessionName)
            }
        }

        refresh()
        return name
    }

    func retire(_ name: String) {
        let wt = Tmux.run(["show", "-pqv", "-t", "=\(name):", "@fleet_wt"]).out
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var src = Tmux.run(["show", "-pqv", "-t", "=\(name):", "@fleet_srcdir"]).out
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Back-compat with sessions created before @fleet_srcdir existed.
        if src.isEmpty {
            let repo = Tmux.run(["show", "-pqv", "-t", "=\(name):", "@fleet_repo"]).out
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !repo.isEmpty, !reposFolder.isEmpty { src = reposFolder + "/\(repo)" }
        }

        Tmux.run(["kill-session", "-t", "=\(name)"])
        TerminalCache.dropEverywhere(name)

        if !wt.isEmpty, !src.isEmpty {
            if Tmux.git(in: src, ["worktree", "remove", wt]) != 0 {
                lastError = "Worktree kept (uncommitted changes): \(wt)"
            }
        }
        refresh()
    }

    /// "Message read": stop the ✅ blink once the user looks at the session.
    func markSeen(_ name: String?) {
        if let name { unseenDone.remove(name) }
    }

    // MARK: Tabs (tmux windows inside a session)

    func addTab(_ session: String) {
        let dir = Tmux.run(["display-message", "-p", "-t", "=\(session):", "#{pane_current_path}"])
            .out.trimmingCharacters(in: .whitespacesAndNewlines)
        var args = ["new-window", "-t", "=\(session):"]
        if !dir.isEmpty { args += ["-c", dir] }
        Tmux.run(args)
        refresh()
    }

    func selectTab(_ session: String, _ index: Int) {
        Tmux.run(["select-window", "-t", "=\(session):\(index)"])
        refresh()
    }

    func closeTab(_ session: String, _ index: Int) {
        Tmux.run(["kill-window", "-t", "=\(session):\(index)"])
        refresh()
    }

    func activeTab(of session: String) -> SessionTab? {
        tabs[session]?.first(where: \.active)
    }

    /// Move to the next/previous tab, wrapping around.
    func stepTab(_ session: String, offset: Int) {
        guard let list = tabs[session], !list.isEmpty else { return }
        let current = list.firstIndex(where: \.active) ?? 0
        let next = list[(current + offset + list.count) % list.count]
        selectTab(session, next.index)
    }

    func nextWaiting(after current: String?) -> String? {
        sessions.first(where: { $0.state == .input && $0.name != current })?.name
            ?? sessions.first(where: { $0.state == .input })?.name
    }

    // MARK: Split panes (tmux panes inside a tab)

    /// Split the focused pane; the new pane opens a shell in the same folder.
    /// `-h` = new pane to the right, `-v` = new pane below.
    func split(_ session: String, vertical: Bool) {
        Tmux.run(["split-window", vertical ? "-v" : "-h",
                  "-t", "=\(session):", "-c", "#{pane_current_path}"])
        refresh()
    }

    /// Move focus to the pane in the given direction (L/R/U/D).
    func focusPane(_ session: String, _ direction: String) {
        Tmux.run(["select-pane", "-t", "=\(session):", "-\(direction)"])
    }

    /// Grow the focused pane toward a direction (keyboard companion to
    /// dragging the pane border with the mouse).
    func resizePane(_ session: String, _ direction: String, by cells: Int = 5) {
        Tmux.run(["resize-pane", "-t", "=\(session):", "-\(direction)", "\(cells)"])
    }

    /// ⌘W: close the focused pane, or the whole tab if it's the last pane.
    func smartClose(_ session: String) {
        let count = Int(Tmux.run(["display-message", "-p", "-t", "=\(session):",
                                  "#{window_panes}"]).out
            .trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        switch PaneAction.close(paneCount: count) {
        case .pane:
            Tmux.run(["kill-pane", "-t", "=\(session):"])
            refresh()
        case .tab:
            if let tab = activeTab(of: session) { closeTab(session, tab.index) }
        }
    }

    /// tmux's named layouts, cycled by ⌘⌥= (halves ↔ stacked ↔ quadrants).
    private static let layouts = ["even-horizontal", "even-vertical", "tiled", "main-vertical"]
    private var layoutIndex: [String: Int] = [:]

    func setLayout(_ session: String, _ layout: String) {
        Tmux.run(["select-layout", "-t", "=\(session):", layout])
    }

    func cycleLayout(_ session: String) {
        let next = ((layoutIndex[session] ?? -1) + 1) % Self.layouts.count
        layoutIndex[session] = next
        setLayout(session, Self.layouts[next])
    }
}
