import Foundation

/// Pure naming rules for sessions — kept free of tmux/UI so they're testable.
enum SessionNaming {
    /// tmux forbids ':' and '.' in session names.
    static func sanitize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: ".", with: "-")
    }

    /// tmux-safe base name for a session started in an arbitrary folder:
    /// the folder's last path component, sanitized, with a fallback so a
    /// root/empty path never yields an empty name.
    static func baseName(forDirectory path: String) -> String {
        let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
        let last = (trimmed as NSString).lastPathComponent
        let clean = sanitize(last)
        return clean.isEmpty || clean == "/" ? "session" : clean
    }

    /// Resolves a name collision by numbering: an empty task becomes
    /// "session-2", "session-3", … on repeat launches; a given task becomes
    /// "task-2", "task-3", … `excluding` is the session being renamed, so it
    /// never collides with itself.
    static func uniqueTask(repo: String, desired: String,
                           existing: [String], excluding: String? = nil) -> String {
        func taken(_ task: String) -> Bool {
            let name = task.isEmpty ? repo : "\(repo)/\(task)"
            return existing.contains { $0 == name && $0 != excluding }
        }
        guard taken(desired) else { return desired }
        var n = 2
        while true {
            let candidate = desired.isEmpty ? "session-\(n)" : "\(desired)-\(n)"
            if !taken(candidate) { return candidate }
            n += 1
        }
    }
}
