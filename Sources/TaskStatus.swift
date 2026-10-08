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
}

final class TaskStatusStore {
    private struct Record {
        var title: String
        var state: WidgetTaskState
        var completedAt: Date?
    }

    private var records: [String: Record] = [:]
    private var runningOrder: [String] = []

    func update(active: [ActiveCodexThread], at now: Date) -> [WidgetTaskStatus] {
        var activeIDs = Set<String>()
        runningOrder.removeAll(keepingCapacity: true)
        for thread in active where activeIDs.insert(thread.id).inserted {
            records[thread.id] = Record(title: thread.title, state: .running, completedAt: nil)
            runningOrder.append(thread.id)
        }

        for (id, record) in records where record.state == .running && !activeIDs.contains(id) {
            records[id] = Record(title: record.title, state: .completed, completedAt: now)
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
            return WidgetTaskStatus(id: id, title: record.title, state: .running)
        }
        let completed = records.compactMap { id, record -> WidgetTaskStatus? in
            guard record.state == .completed else { return nil }
            return WidgetTaskStatus(id: id, title: record.title, state: .completed)
        }.sorted { lhs, rhs in
            lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
        return running + completed
    }
}
