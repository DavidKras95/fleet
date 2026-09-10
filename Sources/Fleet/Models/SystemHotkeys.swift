import Foundation

/// Reads macOS's own hotkey assignments (com.apple.symbolichotkeys.plist) so
/// Fleet warns about combos the system will ACTUALLY intercept on this
/// machine — not a guessed list. A disabled system hotkey is a free combo.
enum SystemHotkeys {
    // NSEvent.ModifierFlags raw values, as stored in the plist's mask.
    private static let shiftMask = 1 << 17
    private static let controlMask = 1 << 18
    private static let optionMask = 1 << 19
    private static let commandMask = 1 << 20

    /// Pure parser over the hotkey table (the plist root, or the dict under
    /// its "AppleSymbolicHotKeys" key). Returns serialized reserved combos.
    static func reservedCombos(fromHotkeyTable root: [String: Any]) -> Set<String> {
        let table = (root["AppleSymbolicHotKeys"] as? [String: Any]) ?? root
        var out: Set<String> = []
        for case let entry as [String: Any] in table.values {
            guard (entry["enabled"] as? Bool) == true,
                  let value = entry["value"] as? [String: Any],
                  let params = value["parameters"] as? [Any], params.count >= 3,
                  let ascii = params[0] as? Int,
                  let keyCode = params[1] as? Int,
                  let mask = params[2] as? Int,
                  let key = keyToken(ascii: ascii, keyCode: keyCode)
            else { continue }

            var mods: Set<KeyMod> = []
            if mask & shiftMask != 0 { mods.insert(.shift) }
            if mask & controlMask != 0 { mods.insert(.control) }
            if mask & optionMask != 0 { mods.insert(.option) }
            if mask & commandMask != 0 { mods.insert(.command) }
            out.insert(KeyCombo(key: key, modifiers: mods).serialized)
        }
        return out
    }

    /// The user's current system hotkeys, or nil if the plist can't be read
    /// (callers fall back to a hardcoded list).
    static func loadCurrent() -> Set<String>? {
        let path = NSHomeDirectory() + "/Library/Preferences/com.apple.symbolichotkeys.plist"
        guard let data = FileManager.default.contents(atPath: path),
              let root = (try? PropertyListSerialization.propertyList(from: data, format: nil))
                as? [String: Any]
        else { return nil }
        return reservedCombos(fromHotkeyTable: root)
    }

    private static func keyToken(ascii: Int, keyCode: Int) -> String? {
        // A printable character wins; 65535 means "no character".
        if ascii != 65535, let scalar = UnicodeScalar(UInt32(exactly: UInt32(max(0, ascii))) ?? 0),
           scalar.isASCII, !Character(scalar).isWhitespace, ascii > 32 {
            return String(Character(scalar)).lowercased()
        }
        switch keyCode {
        case 49: return "space"
        case 36, 76: return "return"
        case 123: return "left"
        case 124: return "right"
        case 125: return "down"
        case 126: return "up"
        default: return nil // F-keys etc. — not recordable in Fleet anyway
        }
    }
}
