import Foundation

/// What ⌘W should do, given how many panes the focused tab has.
enum PaneAction: Equatable {
    case pane   // more than one pane → close just the focused one
    case tab    // last pane → close the whole tab (tmux window)

    static func close(paneCount: Int) -> PaneAction {
        paneCount > 1 ? .pane : .tab
    }
}
