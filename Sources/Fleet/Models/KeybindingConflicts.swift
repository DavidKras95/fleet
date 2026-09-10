import Foundation

/// Pure conflict checks for keyboard shortcuts.
enum KeybindingConflicts {
    /// Serialized combos that more than one command maps to.
    static func duplicated(in map: [String: KeyCombo]) -> Set<String> {
        var seen: [String: Int] = [:]
        for combo in map.values { seen[combo.serialized, default: 0] += 1 }
        return Set(seen.filter { $0.value > 1 }.keys)
    }

    /// Fallback list of combos macOS commonly reserves — used only when the
    /// real system hotkey table can't be read. Not exhaustive.
    static let fallbackReserved: Set<String> = [
        KeyCombo(key: "space", modifiers: [.command]).serialized,          // Spotlight
        KeyCombo(key: "space", modifiers: [.command, .option]).serialized, // Finder search
        KeyCombo(key: "tab", modifiers: [.command]).serialized,            // App switcher
        KeyCombo(key: "q", modifiers: [.command]).serialized,              // Quit
        KeyCombo(key: "h", modifiers: [.command]).serialized,              // Hide
        KeyCombo(key: "m", modifiers: [.command]).serialized,              // Minimize
    ]

    /// The user's ACTUAL enabled system hotkeys (a disabled Spotlight means
    /// ⌘Space is genuinely free), read once; fallback list if unreadable.
    /// App-menu basics (⌘Q/⌘H/⌘M) aren't in that table but always apply.
    private static let currentReserved: Set<String> = {
        guard let system = SystemHotkeys.loadCurrent() else { return fallbackReserved }
        return system.union([
            KeyCombo(key: "q", modifiers: [.command]).serialized,
            KeyCombo(key: "h", modifiers: [.command]).serialized,
            KeyCombo(key: "m", modifiers: [.command]).serialized,
        ])
    }()

    static func isReserved(_ combo: KeyCombo, in reserved: Set<String>? = nil) -> Bool {
        (reserved ?? currentReserved).contains(combo.serialized)
    }
}
