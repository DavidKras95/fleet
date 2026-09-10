import Foundation

/// Decides which session a window should be looking at, so reopening the app
/// lands back where you were — and a stale/killed selection never leaves a
/// window attached to a session that no longer exists. Pure, so it's testable.
enum SelectionRestore {
    /// - current:  the window's live selection (nil on a fresh launch).
    /// - stored:   the last selection persisted to disk.
    /// - existing: session names that actually exist right now.
    static func resolve(current: String?, stored: String?, existing: [String]) -> String? {
        let live = Set(existing)
        // Keep the current selection only while its session still exists.
        if let current, live.contains(current) { return current }
        // Otherwise restore the persisted one, if it's still around.
        if let stored, live.contains(stored) { return stored }
        return nil
    }
}
