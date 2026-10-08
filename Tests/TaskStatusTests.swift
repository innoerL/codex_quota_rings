import Foundation

@main struct TaskStatusTests {
    static func main() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let store = TaskStatusStore()
        let active = [
            ActiveCodexThread(id: "first", title: "迁移目录编写"),
            ActiveCodexThread(id: "second", title: "新增礼物赠送记录表")
        ]

        let running = store.update(active: active, at: start)
        precondition(running.map(\.title) == ["迁移目录编写", "新增礼物赠送记录表"], "FAIL: all active task titles must be shown")
        precondition(running.allSatisfy { $0.state == .running }, "FAIL: active tasks must be running")
        precondition(running.allSatisfy { $0.activeSince == start && $0.completedAt == nil })

        let continuous = store.update(active: active, at: start.addingTimeInterval(125))
        precondition(continuous.allSatisfy { $0.activeSince == start }, "continuous polling must preserve the first observation")
        precondition(continuous[0].elapsed(at: start.addingTimeInterval(125)) == 125)

        let completionTime = start.addingTimeInterval(180)
        let completed = store.update(active: [active[1]], at: completionTime)
        precondition(completed.count == 2, "FAIL: a just-finished observed task must be retained")
        precondition(completed.first { $0.id == "first" }?.state == .completed, "FAIL: disappeared active task must become completed")
        precondition(completed.first { $0.id == "second" }?.state == .running, "FAIL: remaining active task must stay running")
        let frozen = completed.first { $0.id == "first" }!
        precondition(frozen.activeSince == start && frozen.completedAt == completionTime)
        precondition(frozen.elapsed(at: start.addingTimeInterval(10_000)) == 180, "completed duration must freeze")

        guard let expired = store.expire(at: completionTime.addingTimeInterval(300)) else {
            fatalError("FAIL: completion expiry must publish a replacement task list")
        }
        precondition(expired.count == 1 && expired.first?.id == "second" && expired.first?.state == .running,
                     "FAIL: completed tasks must expire after five minutes even when task polling has no valid response")

        let freshStore = TaskStatusStore()
        precondition(freshStore.update(active: [], at: start).isEmpty, "FAIL: unseen idle history must never become completed")

        let reactivated = store.update(active: active, at: completionTime.addingTimeInterval(301))
        precondition(reactivated.first { $0.id == "first" }?.activeSince == completionTime.addingTimeInterval(301),
                     "a task active after completion must start a new run")
        let restartedStore = TaskStatusStore()
        precondition(restartedStore.update(active: [active[0]], at: start.addingTimeInterval(500))[0].activeSince == start.addingTimeInterval(500),
                     "a new store simulates restart and resets timing")

        let underMinute = WidgetTaskStatus(id: "short", title: "Short", state: .running,
                                          activeSince: start, completedAt: nil)
        precondition(TaskDurationFormatter.string(for: underMinute, at: start.addingTimeInterval(40)) == "Running · 不到 1 分钟")
        let minutes = WidgetTaskStatus(id: "minutes", title: "Minutes", state: .completed,
                                      activeSince: start, completedAt: start.addingTimeInterval(12 * 60))
        precondition(TaskDurationFormatter.string(for: minutes, at: start.addingTimeInterval(99_999)) == "Completed · 用时 12 分钟")
        let hours = WidgetTaskStatus(id: "hours", title: "Hours", state: .running,
                                    activeSince: start, completedAt: nil)
        precondition(TaskDurationFormatter.string(for: hours, at: start.addingTimeInterval(2 * 3_600 + 5 * 60)) == "Running · 2 小时 5 分钟")

        print("PASS: task status tracks duration, completion, expiry, reactivation, and restart semantics")
    }
}
