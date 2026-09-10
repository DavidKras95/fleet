import AppKit
import SwiftTerm
import SwiftUI

/// Ghostty-style key handling, injected via an event monitor because
/// SwiftTerm's own key methods aren't overridable:
/// ⌘⌫ clears the whole input line, ⇧⏎ inserts a newline (what Claude Code
/// expects for multiline prompts).
@MainActor
enum TerminalKeyBindings {
    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let terminal = event.window?.firstResponder as? LocalProcessTerminalView else {
                return event
            }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == 51, mods.contains(.command) { // ⌘⌫
                terminal.send(txt: "\u{15}") // Ctrl-U: kill input line
                return nil
            }
            if event.keyCode == 36, mods.contains(.shift), !mods.contains(.command) { // ⇧⏎
                terminal.send(txt: "\u{1b}\r") // ESC+CR: newline in Claude Code
                return nil
            }
            if event.keyCode == 6, mods == .command { // ⌘Z
                terminal.send(txt: "\u{1f}") // Ctrl-_: undo in Claude Code / zsh
                return nil
            }
            if event.keyCode == 7, mods == .command { // ⌘X
                terminal.copy(event) // keep the selection, if any
                terminal.send(txt: "\u{15}") // then clear the input line
                return nil
            }
            return event
        }
    }
}

/// Per-window UI state: which agent this window is looking at, plus this
/// window's own terminal views. Two windows can show two different agents —
/// or the same one, mirrored by tmux.
@MainActor
final class WindowState: ObservableObject {
    private static let registry = NSHashTable<WindowState>.weakObjects()

    @Published var selection: String?
    @Published var showNewAgent = false
    let terminals = TerminalCache()

    init() { Self.registry.add(self) }

    /// Keeps every window's selection pointing at a renamed session instead
    /// of a name that no longer exists.
    static func renamed(from: String, to: String) {
        for w in registry.allObjects where w.selection == from {
            w.selection = to
        }
    }
}

/// One live terminal per agent *per window*, kept alive across sidebar
/// switches so nothing restarts when you move between agents. Each terminal
/// runs `tmux attach` — the agent itself lives in tmux, not in this process.
@MainActor
final class TerminalCache {
    private static let registry = NSHashTable<TerminalCache>.weakObjects()
    static var fontSize: CGFloat = 13

    private var views: [String: LocalProcessTerminalView] = [:]

    init() { Self.registry.add(self) }

    /// Prefer the user's powerlevel10k Nerd Font so prompt glyphs render;
    /// fall back to the system monospaced font.
    static func terminalFont(size: CGFloat) -> NSFont {
        for name in ["MesloLGS NF", "MesloLGS-NF-Regular", "JetBrainsMono Nerd Font", "Hack Nerd Font"] {
            if let f = NSFont(name: name, size: size) { return f }
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    /// Live-resize the font of every open terminal in every window (⌘= / ⌘-).
    static func applyFontSizeToAll(_ size: CGFloat) {
        fontSize = size
        let font = terminalFont(size: size)
        for cache in registry.allObjects {
            cache.views.values.forEach { $0.font = font }
        }
    }

    /// Forget a retired session's terminal in every window.
    static func dropEverywhere(_ session: String) {
        registry.allObjects.forEach { $0.drop(session) }
    }

    /// Migrates a live terminal's cache entry to a renamed session. The
    /// underlying tmux client stays attached through a rename (tmux tracks
    /// it by session ID, not name) — only our lookup key needs to move.
    static func renamed(from: String, to: String) {
        for cache in registry.allObjects {
            if let v = cache.views.removeValue(forKey: from) {
                cache.views[to] = v
            }
        }
    }

    func view(for session: String) -> LocalProcessTerminalView {
        if let v = views[session] { return v }
        TerminalKeyBindings.install()
        // No tmux prefix inside the app: Ctrl-A etc. go straight to the
        // program in the terminal; the app itself is the session manager.
        // Covers sessions Fleet didn't spawn itself (FleetStore.spawn sets
        // this already); dispatched off-thread because this method runs
        // from SwiftUI's updateNSView — Process.waitUntilExit() blocks via a
        // nested run loop, and calling it synchronously from inside an
        // in-flight CFRunLoop/AttributeGraph callback is what crashed the
        // app (EXC_BAD_ACCESS in NSConcreteTask waitUntilExit, reported
        // 2026-08-23) the moment a session's terminal view was first built.
        DispatchQueue.global(qos: .userInitiated).async {
            Tmux.run(["set", "-t", "=\(session)", "prefix", "None"])
        }
        let v = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 1200, height: 800))
        v.processDelegate = self
        v.font = Self.terminalFont(size: Self.fontSize)
        v.nativeBackgroundColor = NSColor(srgbRed: 0.117, green: 0.129, blue: 0.157, alpha: 1) // ghostty-like dark
        v.nativeForegroundColor = NSColor(srgbRed: 0.92, green: 0.93, blue: 0.94, alpha: 1)

        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["LANG"] = env["LANG"] ?? "en_US.UTF-8"
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:\(NSHomeDirectory())/.local/bin:"
            + (env["PATH"] ?? "/usr/bin:/bin")
        let envArray = env.map { "\($0.key)=\($0.value)" }

        v.startProcess(
            executable: Tmux.bin,
            args: ["attach", "-t", "=\(session)"],
            environment: envArray,
            execName: nil
        )
        views[session] = v
        return v
    }

    func drop(_ session: String) {
        views.removeValue(forKey: session)
    }

    private func dropView(_ view: TerminalView) {
        views = views.filter { $0.value !== view }
    }
}

/// A terminal whose tmux client died (app relaunch, session killed, tmux
/// restart) must never linger as a frozen ghost — evict it so the next
/// selection reattaches fresh.
extension TerminalCache: LocalProcessTerminalViewDelegate {
    nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    nonisolated func processTerminated(source: TerminalView, exitCode: Int32?) {
        Task { @MainActor in
            self.dropView(source)
        }
    }
}

struct TerminalHostView: NSViewRepresentable {
    let session: String
    let cache: TerminalCache

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ container: NSView, context: Context) {
        let terminal = cache.view(for: session)
        guard terminal.superview !== container else { return }
        container.subviews.forEach { $0.removeFromSuperview() }
        terminal.frame = container.bounds
        terminal.autoresizingMask = [.width, .height]
        container.addSubview(terminal)
        DispatchQueue.main.async {
            container.window?.makeFirstResponder(terminal)
        }
    }
}
