import Foundation

/// Which sessions just transitioned into needing input (so a notification
/// fires once on entry, not on every poll while it waits).
enum NotificationTrigger {
    static func newlyNeedingInput(previous: [String: AgentSession.State],
                                  current: [String: AgentSession.State]) -> [String] {
        current.compactMap { name, state in
            (state == .input && previous[name] != .input) ? name : nil
        }
    }
}
