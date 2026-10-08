import Foundation

struct ActiveCodexThread: Equatable {
    let id: String
    let title: String
}

enum WidgetTaskState: Equatable {
    case running
    case completed
}

struct WidgetTaskStatus: Equatable {
    let id: String
    let title: String
    let state: WidgetTaskState
    let activeSince: Date
    let completedAt: Date?

    init(id: String, title: String, state: WidgetTaskState,
         activeSince: Date = Date(), completedAt: Date? = nil) {
        self.id = id; self.title = title; self.state = state
        self.activeSince = activeSince; self.completedAt = completedAt
    }

    func elapsed(at now: Date) -> TimeInterval {
        max(0, (completedAt ?? now).timeIntervalSince(activeSince))
    }
}

enum TaskDurationFormatter {
    static func string(for status: WidgetTaskStatus, at now: Date = Date()) -> String {
        let seconds = status.elapsed(at: now)
        let duration: String
        if seconds < 60 {
            duration = "不到 1 分钟"
        } else {
            let minutes = Int(seconds / 60)
            if minutes < 60 {
                duration = "\(minutes) 分钟"
            } else {
                let hours = minutes / 60, remainder = minutes % 60
                duration = remainder == 0 ? "\(hours) 小时" : "\(hours) 小时 \(remainder) 分钟"
            }
        }
        return status.state == .running ? "Running · \(duration)" : "Completed · 用时 \(duration)"
    }
}

final class TaskStatusStore {
    private struct Record {
        var title: String
        var state: WidgetTaskState
        var activeSince: Date
        var completedAt: Date?
    }

    private var records: [String: Record] = [:]
    private var runningOrder: [String] = []

    func update(active: [ActiveCodexThread], at now: Date) -> [WidgetTaskStatus] {
        var activeIDs = Set<String>()
        runningOrder.removeAll(keepingCapacity: true)
        for thread in active where activeIDs.insert(thread.id).inserted {
            let activeSince: Date
            if let record = records[thread.id], record.state == .running {
                activeSince = record.activeSince
            } else {
                activeSince = now
            }
            records[thread.id] = Record(title: thread.title, state: .running,
                                        activeSince: activeSince, completedAt: nil)
            runningOrder.append(thread.id)
        }

        for (id, record) in records where record.state == .running && !activeIDs.contains(id) {
            records[id] = Record(title: record.title, state: .completed,
                                 activeSince: record.activeSince, completedAt: now)
        }
        removeExpired(at: now)
        return visibleStatuses()
    }

    /// Returns a replacement list only when a retained completion has expired.
    func expire(at now: Date) -> [WidgetTaskStatus]? {
        let before = visibleStatuses()
        removeExpired(at: now)
        let after = visibleStatuses()
        return before == after ? nil : after
    }

    private func removeExpired(at now: Date) {
        records = records.filter { _, record in
            guard let completedAt = record.completedAt else { return true }
            return now.timeIntervalSince(completedAt) < 300
        }
    }

    private func visibleStatuses() -> [WidgetTaskStatus] {
        let running = runningOrder.compactMap { id -> WidgetTaskStatus? in
            guard let record = records[id], record.state == .running else { return nil }
            return WidgetTaskStatus(id: id, title: record.title, state: .running,
                                    activeSince: record.activeSince, completedAt: nil)
        }
        let completed = records.compactMap { id, record -> WidgetTaskStatus? in
            guard record.state == .completed else { return nil }
            return WidgetTaskStatus(id: id, title: record.title, state: .completed,
                                    activeSince: record.activeSince, completedAt: record.completedAt)
        }.sorted { lhs, rhs in
            lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
        return running + completed
    }
}
