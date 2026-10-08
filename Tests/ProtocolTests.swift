import Foundation

@main struct ProtocolTests {
    static func main() {
        let client = QuotaClient(executableURL: URL(fileURLWithPath: CommandLine.arguments[1]))
        var readings: [Int] = []
        var taskTitles: [String] = []
        client.onTasksChange = { tasks in
            taskTitles = tasks.map(\.title)
            guard taskTitles == ["迁移目录编写", "新增礼物赠送记录表"],
                  tasks.allSatisfy({ $0.state == .running }) else {
                fputs("FAIL: active thread decoding or idle filtering failed: \(tasks)\n", stderr)
                client.stop(); exit(1)
            }
        }
        client.onChange = { snapshot, error in
            if let error {
                guard readings == [20, 25, 26], snapshot?.fiveHour?.remainingPercent == 26,
                      taskTitles == ["迁移目录编写", "新增礼物赠送记录表"] else {
                    fputs("FAIL: protocol, notification, task status, or stale last-value handling: \(readings); \(taskTitles); \(error)\n", stderr)
                    client.stop(); exit(1)
                }
                client.stop()
                print("PASS: fragmented JSON, quota polling, active task titles, push update, and disconnect state")
                exit(0)
            }
            if let value = snapshot?.fiveHour?.remainingPercent {
                readings.append(Int(value))
                if readings.count == 1 { client.refresh() }
            }
        }
        client.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            fputs("FAIL: protocol test timed out\n", stderr); client.stop(); exit(1)
        }
        RunLoop.main.run()
    }
}
