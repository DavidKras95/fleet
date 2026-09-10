import Foundation

/// Locates command-line tools, preferring a copy bundled inside the app
/// (so tmux/jq can ship with Fleet) and falling back to the usual install
/// locations and the user's PATH.
enum Executables {
    private static let searchDirs = [
        "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin",
        NSHomeDirectory() + "/.local/bin",
    ]

    /// Absolute path to `name`, or nil if it can't be found anywhere.
    static func find(_ name: String) -> String? {
        // 1. Bundled with the app (Contents/Resources or Contents/Helpers).
        if let res = Bundle.main.resourceURL {
            for sub in ["", "bin"] {
                let p = res.appendingPathComponent(sub).appendingPathComponent(name).path
                if FileManager.default.isExecutableFile(atPath: p) { return p }
            }
        }
        // 2. Well-known install locations.
        for dir in searchDirs {
            let p = dir + "/" + name
            if FileManager.default.isExecutableFile(atPath: p) { return p }
        }
        // 3. Anything else on the launch environment's PATH.
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for dir in path.split(separator: ":") {
                let p = String(dir) + "/" + name
                if FileManager.default.isExecutableFile(atPath: p) { return p }
            }
        }
        return nil
    }

    static func isAvailable(_ name: String) -> Bool { find(name) != nil }
}
