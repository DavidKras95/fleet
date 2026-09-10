import AppKit
import SwiftUI

/// A click-to-record shortcut field: click it, press a combo, it captures.
/// Esc cancels, Delete/Backspace clears the binding.
struct ShortcutRecorder: View {
    let current: KeyCombo?
    let conflict: Bool
    let onChange: (KeyCombo?) -> Void

    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            recording ? stop() : start()
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .frame(minWidth: 96)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(recording ? Color.accentColor.opacity(0.25)
                              : Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(recording ? Color.accentColor
                                : (conflict ? Color.red.opacity(0.7) : Color.clear),
                                lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onDisappear { stop() }
    }

    private var label: String {
        if recording { return "Press keys…" }
        return current?.display ?? "—"
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil // swallow while recording
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func handle(_ event: NSEvent) {
        switch event.keyCode {
        case 53: stop(); return                       // Esc → cancel
        case 51, 117: onChange(nil); stop(); return   // Delete/Fwd-Delete → unbind
        default: break
        }
        var mods: Set<KeyMod> = []
        let f = event.modifierFlags
        if f.contains(.command) { mods.insert(.command) }
        if f.contains(.shift) { mods.insert(.shift) }
        if f.contains(.option) { mods.insert(.option) }
        if f.contains(.control) { mods.insert(.control) }
        // Require at least one modifier so a plain key can't shadow typing.
        guard !mods.isEmpty else { return }
        guard let key = Self.keyToken(for: event) else { return }
        onChange(KeyCombo(key: key, modifiers: mods))
        stop()
    }

    private static func keyToken(for event: NSEvent) -> String? {
        switch event.keyCode {
        case 123: return "left"
        case 124: return "right"
        case 125: return "down"
        case 126: return "up"
        case 36, 76: return "return"
        case 49: return "space"
        default:
            guard let ch = event.charactersIgnoringModifiers?.lowercased(), ch.count == 1,
                  ch != "\u{1b}", ch.first?.isWhitespace == false else { return nil }
            return ch
        }
    }
}
