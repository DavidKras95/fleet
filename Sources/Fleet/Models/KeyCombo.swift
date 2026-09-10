import Foundation

/// A keyboard modifier. Raw value is the stable token used for persistence.
enum KeyMod: String, CaseIterable, Comparable {
    case control, option, shift, command

    /// macOS display order: ⌃ ⌥ ⇧ ⌘.
    private var order: Int {
        switch self {
        case .control: return 0
        case .option: return 1
        case .shift: return 2
        case .command: return 3
        }
    }
    var symbol: String {
        switch self {
        case .control: return "⌃"
        case .option: return "⌥"
        case .shift: return "⇧"
        case .command: return "⌘"
        }
    }
    static func < (l: KeyMod, r: KeyMod) -> Bool { l.order < r.order }
}

/// A key + its modifiers. Pure and serializable so shortcuts can be stored,
/// compared for conflicts, and shown to the user.
struct KeyCombo: Equatable {
    /// A single character ("d", "="), or a special-key token
    /// ("left", "right", "up", "down", "return", "space").
    let key: String
    let modifiers: Set<KeyMod>

    init(key: String, modifiers: Set<KeyMod>) {
        self.key = key
        self.modifiers = modifiers
    }

    /// Order-independent string form, e.g. "command+shift+d".
    var serialized: String {
        (modifiers.sorted().map(\.rawValue) + [key]).joined(separator: "+")
    }

    init?(serialized: String) {
        let parts = serialized.split(separator: "+", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 1, let key = parts.last, !key.isEmpty else { return nil }
        var mods: Set<KeyMod> = []
        for token in parts.dropLast() {
            guard let m = KeyMod(rawValue: token) else { return nil }
            mods.insert(m)
        }
        self.key = key
        self.modifiers = mods
    }

    /// Human-readable, e.g. "⇧⌘D" or "⌥⌘←".
    var display: String {
        modifiers.sorted().map(\.symbol).joined() + Self.keySymbol(key)
    }

    private static func keySymbol(_ key: String) -> String {
        switch key {
        case "left": return "←"
        case "right": return "→"
        case "up": return "↑"
        case "down": return "↓"
        case "return": return "↩"
        case "space": return "Space"
        default: return key.count == 1 ? key.uppercased() : key
        }
    }
}
