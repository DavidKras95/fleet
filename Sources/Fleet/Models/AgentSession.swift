import Foundation

/// One agent = one tmux session, named `repo` or `repo/task`.
struct AgentSession: Identifiable, Hashable {
    enum State: String {
        case input, busy, done, idle

        var badge: String {
            switch self {
            case .input: return "🔴"
            case .busy: return "⏳"
            case .done: return "✅"
            case .idle: return "▪️"
            }
        }

        /// Sidebar sort priority — waiting agents first.
        var priority: Int {
            switch self {
            case .input: return 0
            case .busy: return 1
            case .done: return 2
            case .idle: return 3
            }
        }
    }

    let name: String
    var state: State

    var id: String { name }
    var repo: String { name.split(separator: "/").first.map(String.init) ?? name }
    var task: String? {
        guard let i = name.firstIndex(of: "/") else { return nil }
        return String(name[name.index(after: i)...])
    }

    /// Small caption on every sidebar cube — always the project.
    var displayCaption: String { repo }

    /// Bold label: the task, or the repo itself when there is no task.
    /// Never a generic placeholder — every cube must identify itself.
    var displayTitle: String { task ?? repo }
}

/// One tab inside a session = one tmux window of that session.
struct SessionTab: Identifiable, Hashable {
    let index: Int
    let name: String
    let active: Bool

    var id: Int { index }
}
