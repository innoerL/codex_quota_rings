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

    func update(active: [ActiveCodexThread], at now: Date) -> [WidgetTaskStatus] {
        var activeIDs = Set<String>()
        var running: [WidgetTaskStatus] = []
        for thread in active where activeIDs.insert(thread.id).inserted {
            records[thread.id] = Record(title: thread.title, state: .running, completedAt: nil)
            running.append(WidgetTaskStatus(id: thread.id, title: thread.title, state: .running))
        }

        for (id, record) in records where record.state == .running && !activeIDs.contains(id) {
            records[id] = Record(title: record.title, state: .completed, completedAt: now)
        }
        records = records.filter { _, record in
            guard let completedAt = record.completedAt else { return true }
            return now.timeIntervalSince(completedAt) < 300
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
