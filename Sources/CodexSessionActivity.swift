import Foundation

protocol CodexSessionActivityProviding {
    func activeThreadIDs(at now: Date) -> Set<String>
}

/// Reads local Codex rollout boundaries only. Titles continue to come from `thread/list`.
struct CodexSessionActivity: CodexSessionActivityProviding {
    let sessionsDirectory: URL
    let fileManager: FileManager
    let activeWindow: TimeInterval

    init(sessionsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex/sessions", isDirectory: true),
         fileManager: FileManager = .default, activeWindow: TimeInterval = 15 * 60) {
        self.sessionsDirectory = sessionsDirectory
        self.fileManager = fileManager
        self.activeWindow = activeWindow
    }

    func activeThreadIDs(at now: Date = Date()) -> Set<String> {
        guard let files = fileManager.enumerator(at: sessionsDirectory,
                                                 includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                                                 options: [.skipsHiddenFiles]) else { return [] }
        var result = Set<String>()
        for case let url as URL in files where url.pathExtension == "jsonl" {
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate,
                  modified >= now.addingTimeInterval(-activeWindow),
                  let data = try? Data(contentsOf: url),
                  let threadID = activeThreadID(in: data) else { continue }
            result.insert(threadID)
        }
        return result
    }

    private func activeThreadID(in data: Data) -> String? {
        var threadID: String?
        var lastStarted = -1
        var lastCompleted = -1
        for (index, line) in data.split(separator: 10).enumerated() {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else { continue }
            let payload = object["payload"] as? [String: Any]
            if object["type"] as? String == "session_meta" {
                threadID = payload?["session_id"] as? String
            }
            guard object["type"] as? String == "event_msg" else { continue }
            switch payload?["type"] as? String {
            case "task_started": lastStarted = index
            case "task_complete": lastCompleted = index
            default: break
            }
        }
        return lastStarted > lastCompleted ? threadID : nil
    }
}
