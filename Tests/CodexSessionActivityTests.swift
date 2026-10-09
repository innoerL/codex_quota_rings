import Foundation

@main struct CodexSessionActivityTests {
    static func main() throws {
        let fileManager = FileManager.default
        let now = Date(timeIntervalSince1970: 2_000_000)
        let directory = fileManager.temporaryDirectory.appendingPathComponent("quota-session-activity-\(UUID().uuidString)")
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        func write(_ name: String, _ id: String, completed: Bool, modified: Date = now) throws {
            var lines = [
                "{\"type\":\"session_meta\",\"payload\":{\"session_id\":\"\(id)\"}}",
                "{\"type\":\"event_msg\",\"payload\":{\"type\":\"task_started\"}}"
            ]
            if completed { lines.append("{\"type\":\"event_msg\",\"payload\":{\"type\":\"task_complete\"}}") }
            let file = directory.appendingPathComponent(name + ".jsonl")
            try lines.joined(separator: "\n").data(using: .utf8)!.write(to: file)
            try fileManager.setAttributes([.modificationDate: modified], ofItemAtPath: file.path)
        }

        try write("active", "current", completed: false)
        try write("completed", "old", completed: true)
        try write("stale", "stale", completed: false, modified: now.addingTimeInterval(-61))
        let scanner = CodexSessionActivity(sessionsDirectory: directory, fileManager: fileManager, activeWindow: 60)
        precondition(scanner.activeThreadIDs(at: now) == ["current"],
                     "only a recent session with an unmatched task_started is active")
        print("PASS: local Codex session activity distinguishes active, complete, and stale sessions")
    }
}
