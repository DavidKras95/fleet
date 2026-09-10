import AppKit
import UserNotifications

/// Posts "needs input" notifications AS Fleet (not as the AppleScript runner),
/// so they show Fleet's name and — crucially — clicking one brings Fleet to
/// the front and opens that session, instead of launching Script Editor.
///
/// Reality check: macOS keys notification permission to the code signature,
/// and an AD-HOC signature changes every build — so unsigned dev builds
/// never get durably authorized and their posts are refused. Until the app
/// is Developer-ID signed, each refused post falls back to an osascript
/// banner (attributed to Script Editor, but at least visible).
@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    static let shared = NotificationManager()

    /// Called on the main actor when the user clicks a notification.
    var onOpenSession: ((String) -> Void)?
    /// nil = not determined yet; shown in Settings.
    @Published var authorized: Bool?
    private var configured = false

    func configure() {
        guard !configured else { return }
        configured = true
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            Task { @MainActor in NotificationManager.shared.authorized = granted }
        }
    }

    func notifyNeedsInput(session: String) {
        let content = UNMutableNotificationContent()
        content.title = "🔔 \(session)"
        content.body = "Needs your input"
        content.sound = .default
        content.userInfo = ["session": session]
        // Coalesce repeats for the same session into one banner.
        let req = UNNotificationRequest(identifier: "needs-input.\(session)",
                                        content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req) { error in
            if error != nil {
                Task { @MainActor in
                    NotificationManager.shared.authorized = false
                    Self.fallbackBanner(session: session)
                }
            }
        }
    }

    /// osascript-based banner for unauthorized (ad-hoc signed) builds.
    private static func fallbackBanner(session: String) {
        let safe = session.replacingOccurrences(of: "\"", with: "")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e",
            "display notification \"Needs your input\" with title \"🔔 \(safe)\" sound name \"Glass\""]
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        try? p.run()
    }

    // Also show the banner while Fleet is frontmost (a split pane may need you
    // while you're looking at another one).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let session = response.notification.request.content.userInfo["session"] as? String
        Task { @MainActor in
            NSApp.activate(ignoringOtherApps: true)
            if let session { NotificationManager.shared.onOpenSession?(session) }
        }
        completionHandler()
    }
}
