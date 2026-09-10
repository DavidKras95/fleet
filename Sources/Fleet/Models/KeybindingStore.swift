import SwiftUI

/// Live, user-editable keyboard shortcuts. Persists overrides; commands with
/// no override fall back to their shipped default. Menu shortcuts observe
/// this, so a remap takes effect immediately.
@MainActor
final class KeybindingStore: ObservableObject {
    /// id -> serialized combo. "" means explicitly unbound.
    @Published private var overrides: [String: String] {
        didSet { UserDefaults.standard.set(overrides, forKey: "keybindings") }
    }

    init() {
        overrides = (UserDefaults.standard.dictionary(forKey: "keybindings") as? [String: String]) ?? [:]
    }

    func combo(for cmd: AppCommand) -> KeyCombo? {
        if let s = overrides[cmd.rawValue] {
            return s.isEmpty ? nil : KeyCombo(serialized: s)
        }
        return cmd.defaultCombo
    }

    func set(_ combo: KeyCombo?, for cmd: AppCommand) {
        overrides[cmd.rawValue] = combo?.serialized ?? ""
    }

    func resetToDefault(_ cmd: AppCommand) {
        overrides.removeValue(forKey: cmd.rawValue)
    }

    func resetAll() { overrides = [:] }

    func isCustom(_ cmd: AppCommand) -> Bool { overrides[cmd.rawValue] != nil }

    private var effectiveMap: [String: KeyCombo] {
        var m: [String: KeyCombo] = [:]
        for cmd in AppCommand.allCases where combo(for: cmd) != nil {
            m[cmd.rawValue] = combo(for: cmd)
        }
        return m
    }

    func hasConflict(_ cmd: AppCommand) -> Bool {
        guard let c = combo(for: cmd) else { return false }
        return KeybindingConflicts.duplicated(in: effectiveMap).contains(c.serialized)
    }

    func isReserved(_ cmd: AppCommand) -> Bool {
        guard let c = combo(for: cmd) else { return false }
        return KeybindingConflicts.isReserved(c)
    }
}

extension KeyCombo {
    var keyboardShortcut: KeyboardShortcut {
        KeyboardShortcut(keyEquivalent, modifiers: eventModifiers)
    }

    var keyEquivalent: KeyEquivalent {
        switch key {
        case "left": return .leftArrow
        case "right": return .rightArrow
        case "up": return .upArrow
        case "down": return .downArrow
        case "return": return .return
        case "space": return .space
        default: return KeyEquivalent(key.first ?? " ")
        }
    }

    var eventModifiers: EventModifiers {
        var m: EventModifiers = []
        if modifiers.contains(.command) { m.insert(.command) }
        if modifiers.contains(.shift) { m.insert(.shift) }
        if modifiers.contains(.option) { m.insert(.option) }
        if modifiers.contains(.control) { m.insert(.control) }
        return m
    }
}
