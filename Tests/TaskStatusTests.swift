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

        let completed = store.update(active: [active[1]], at: start.addingTimeInterval(1))
        precondition(completed.count == 2, "FAIL: a just-finished observed task must be retained")
        precondition(completed.first { $0.id == "first" }?.state == .completed, "FAIL: disappeared active task must become completed")
        precondition(completed.first { $0.id == "second" }?.state == .running, "FAIL: remaining active task must stay running")

        let expired = store.update(active: [active[1]], at: start.addingTimeInterval(302))
        precondition(expired.count == 1 && expired.first?.id == "second" && expired.first?.state == .running,
                     "FAIL: completed tasks must expire after five minutes without ending still-running tasks")

        let freshStore = TaskStatusStore()
        precondition(freshStore.update(active: [], at: start).isEmpty, "FAIL: unseen idle history must never become completed")

        print("PASS: task status tracks multiple running tasks and five-minute completion retention")
    }
}
