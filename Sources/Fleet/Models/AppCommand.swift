import Foundation

/// Every remappable command, its menu title, and its shipped default combo
/// (nil = no default shortcut). Raw value is the stable persistence id.
enum AppCommand: String, CaseIterable, Identifiable {
    case newAgent, newWindow, newTab, closePaneTab
    case prevTab, nextTab, jumpWaiting, prevAgent, nextAgent
    case splitRight, splitDown
    case focusLeft, focusRight, focusUp, focusDown
    case resizeLeft, resizeRight, resizeUp, resizeDown
    case cycleLayout, layoutEvenH, layoutEvenV, layoutTiled
    case zoomTermIn, zoomTermOut, zoomAppIn, zoomAppOut

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newAgent: return "New Agent"
        case .newWindow: return "New Window"
        case .newTab: return "New Tab"
        case .closePaneTab: return "Close Pane / Tab"
        case .prevTab: return "Previous Tab"
        case .nextTab: return "Next Tab"
        case .jumpWaiting: return "Jump to Waiting Agent"
        case .prevAgent: return "Previous Agent"
        case .nextAgent: return "Next Agent"
        case .splitRight: return "Split Right"
        case .splitDown: return "Split Down"
        case .focusLeft: return "Focus Pane Left"
        case .focusRight: return "Focus Pane Right"
        case .focusUp: return "Focus Pane Up"
        case .focusDown: return "Focus Pane Down"
        case .resizeLeft: return "Resize Pane Left"
        case .resizeRight: return "Resize Pane Right"
        case .resizeUp: return "Resize Pane Up"
        case .resizeDown: return "Resize Pane Down"
        case .cycleLayout: return "Cycle Layout"
        case .layoutEvenH: return "Layout: Even Halves (side by side)"
        case .layoutEvenV: return "Layout: Even Halves (stacked)"
        case .layoutTiled: return "Layout: Quadrants (tiled)"
        case .zoomTermIn: return "Zoom Terminal In"
        case .zoomTermOut: return "Zoom Terminal Out"
        case .zoomAppIn: return "Zoom App In"
        case .zoomAppOut: return "Zoom App Out"
        }
    }

    /// Which settings section this command belongs to.
    var group: String {
        switch self {
        case .newAgent, .newWindow, .newTab, .closePaneTab: return "Agents & Tabs"
        case .prevTab, .nextTab, .jumpWaiting, .prevAgent, .nextAgent: return "Navigation"
        case .splitRight, .splitDown, .focusLeft, .focusRight, .focusUp, .focusDown,
             .resizeLeft, .resizeRight, .resizeUp, .resizeDown,
             .cycleLayout, .layoutEvenH, .layoutEvenV, .layoutTiled: return "Splits"
        case .zoomTermIn, .zoomTermOut, .zoomAppIn, .zoomAppOut: return "Zoom"
        }
    }

    var defaultCombo: KeyCombo? {
        switch self {
        case .newAgent: return KeyCombo(key: "n", modifiers: [.command])
        case .newWindow: return KeyCombo(key: "n", modifiers: [.command, .shift])
        case .newTab: return KeyCombo(key: "t", modifiers: [.command])
        case .closePaneTab: return KeyCombo(key: "w", modifiers: [.command])
        case .prevTab: return KeyCombo(key: "left", modifiers: [.command])
        case .nextTab: return KeyCombo(key: "right", modifiers: [.command])
        case .jumpWaiting: return KeyCombo(key: "return", modifiers: [.command])
        case .prevAgent: return KeyCombo(key: "up", modifiers: [.command])
        case .nextAgent: return KeyCombo(key: "down", modifiers: [.command])
        case .splitRight: return KeyCombo(key: "d", modifiers: [.command])
        case .splitDown: return KeyCombo(key: "d", modifiers: [.command, .shift])
        case .focusLeft: return KeyCombo(key: "left", modifiers: [.command, .option])
        case .focusRight: return KeyCombo(key: "right", modifiers: [.command, .option])
        case .focusUp: return KeyCombo(key: "up", modifiers: [.command, .option])
        case .focusDown: return KeyCombo(key: "down", modifiers: [.command, .option])
        case .resizeLeft: return KeyCombo(key: "left", modifiers: [.control, .command])
        case .resizeRight: return KeyCombo(key: "right", modifiers: [.control, .command])
        case .resizeUp: return KeyCombo(key: "up", modifiers: [.control, .command])
        case .resizeDown: return KeyCombo(key: "down", modifiers: [.control, .command])
        case .cycleLayout: return KeyCombo(key: "=", modifiers: [.command, .option])
        case .layoutEvenH, .layoutEvenV, .layoutTiled: return nil
        case .zoomTermIn: return KeyCombo(key: "=", modifiers: [.command])
        case .zoomTermOut: return KeyCombo(key: "-", modifiers: [.command])
        case .zoomAppIn: return KeyCombo(key: "=", modifiers: [.command, .shift])
        case .zoomAppOut: return KeyCombo(key: "-", modifiers: [.command, .shift])
        }
    }
}
