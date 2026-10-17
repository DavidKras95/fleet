import Foundation

/// A finished Claude Code conversation that can be reopened with `claude --resume`.
struct PastSession: Identifiable, Equatable {
    let id: String
    let cwd: String
    let title: String?
    let preview: String
    let promptCount: Int
    let updatedAt: Date

    var projectName: String { (cwd as NSString).lastPathComponent }
}

/// Finds past conversations in Claude Code's transcript store
/// (`~/.claude/projects/<encoded-cwd>/<session-id>.jsonl`).
enum ClaudeSessionScanner {
    static let projectsRoot = NSHomeDirectory() + "/.claude/projects"
    static let liveSessionsDir = NSHomeDirectory() + "/.claude/sessions"

    /// Newest first. `excluding` holds session ids that must not be offered
    /// (already open in Fleet, or still running somewhere else).
    static func scan(root: String = projectsRoot, excluding: Set<String>, limit: Int = 200) -> [PastSession] {
        let fm = FileManager.default
        var files: [(id: String, path: String, mtime: Date)] = []
        for project in (try? fm.contentsOfDirectory(atPath: root)) ?? [] {
            let dir = root + "/" + project
            for file in (try? fm.contentsOfDirectory(atPath: dir)) ?? [] where file.hasSuffix(".jsonl") {
                let id = String(file.dropLast(6))
                guard isValidId(id), !excluding.contains(id) else { continue }
                let path = dir + "/" + file
                let mtime = (try? fm.attributesOfItem(atPath: path))?[.modificationDate] as? Date ?? .distantPast
                files.append((id, path, mtime))
            }
        }
        files.sort { $0.mtime > $1.mtime }
        return files.prefix(limit).compactMap { f in
            guard let text = try? String(contentsOfFile: f.path, encoding: .utf8) else { return nil }
            return parse(id: f.id, lines: text.split(separator: "\n").lazy.map(String.init), updatedAt: f.mtime)
        }
    }

    /// Session ids of Claude processes that are still alive — resuming one of
    /// those would fork a running conversation.
    static func liveSessionIds(dir: String = liveSessionsDir) -> Set<String> {
        var ids = Set<String>()
        for file in (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? [] where file.hasSuffix(".json") {
            guard let data = FileManager.default.contents(atPath: dir + "/" + file),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sid = obj["sessionId"] as? String,
                  let pid = obj["pid"] as? Int32,
                  kill(pid, 0) == 0 else { continue }
            ids.insert(sid)
        }
        return ids
    }

    static func parse<S: Sequence>(id: String, lines: S, updatedAt: Date) -> PastSession? where S.Element == String {
        var cwd: String?
        var title: String?
        var preview: String?
        var prompts = 0
        for line in lines {
            // Cheap substring gate before JSON decoding — transcripts run to MBs.
            let isUser = line.contains(#""type":"user""#)
            let isTitle = line.contains(#""type":"custom-title""#)
            guard isUser || isTitle,
                  let obj = (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any]
            else { continue }
            if obj["type"] as? String == "custom-title" {
                if let t = obj["customTitle"] as? String, !t.isEmpty { title = t }
                continue
            }
            guard obj["type"] as? String == "user" else { continue }
            if cwd == nil, let c = obj["cwd"] as? String, !c.isEmpty { cwd = c }
            guard let text = promptText(obj["message"]) else { continue }
            prompts += 1
            if preview == nil { preview = text }
        }
        guard let cwd, let preview else { return nil }
        return PastSession(id: id, cwd: cwd, title: title, preview: preview,
                           promptCount: prompts, updatedAt: updatedAt)
    }

    static func isValidId(_ id: String) -> Bool {
        UUID(uuidString: id) != nil
    }

    /// Text the person actually typed, or nil for tool results and injected
    /// wrappers (system reminders, slash-command envelopes all start with `<`).
    private static func promptText(_ message: Any?) -> String? {
        guard let message = message as? [String: Any] else { return nil }
        var raw: String?
        if let s = message["content"] as? String {
            raw = s
        } else if let parts = message["content"] as? [[String: Any]] {
            raw = parts.first { $0["type"] as? String == "text" }?["text"] as? String
        }
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty, !trimmed.hasPrefix("<") else { return nil }
        let oneLine = trimmed.components(separatedBy: .newlines).joined(separator: " ")
        return oneLine.count > 120 ? String(oneLine.prefix(119)) + "…" : oneLine
    }
}
