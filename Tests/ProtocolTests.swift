import Foundation

private final class CountingLocator: CodexLocating {
    var location: CodexLocation?
    private(set) var calls = 0

    init(location: CodexLocation?) { self.location = location }

    func locate() -> CodexLocation? {
        calls += 1
        return location
    }
}

@main struct ProtocolTests {
    private static var normalClient: QuotaClient!
    private static var authClient: QuotaClient!
    private static var missingClient: QuotaClient!
    private static var normalStates: [QuotaConnectionState] = []

    static func main() {
        guard CommandLine.arguments.count == 3 else {
            fputs("FAIL: expected normal and signed-out fixtures\n", stderr)
            exit(1)
        }
        startNormalFixture(URL(fileURLWithPath: CommandLine.arguments[1]))
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            fputs("FAIL: protocol test timed out\n", stderr)
            normalClient?.stop(); authClient?.stop(); missingClient?.stop(); exit(1)
        }
        RunLoop.main.run()
    }

    private static func startNormalFixture(_ executable: URL) {
        normalClient = QuotaClient(executableURL: executable)
        var readings: [Int] = []
        var taskTitles: [String] = []
        normalClient.onConnectionState = { normalStates.append($0) }
        normalClient.onTasksChange = { tasks in
            taskTitles = tasks.map(\.title)
            guard taskTitles == ["迁移目录编写", "新增礼物赠送记录表"],
                  tasks.allSatisfy({ $0.state == .running }) else {
                fail("active thread decoding or idle filtering failed: \(tasks)")
            }
        }
        normalClient.onChange = { snapshot, error in
            if let error {
                guard readings == [20, 25, 26], snapshot?.fiveHour?.remainingPercent == 26,
                      taskTitles == ["迁移目录编写", "新增礼物赠送记录表"],
                      normalStates.first == .locating,
                      normalStates.contains(.ready),
                      normalStates.contains(where: { if case .disconnected = $0 { return true }; return false }) else {
                    fail("protocol, tasks, structured states, or stale-value handling: \(readings); \(taskTitles); \(normalStates); \(error)")
                }
                normalClient.stop()
                startAuthenticationFixture(URL(fileURLWithPath: CommandLine.arguments[2]))
                return
            }
            if let value = snapshot?.fiveHour?.remainingPercent {
                readings.append(Int(value))
                if readings.count == 1 { normalClient.refresh() }
            }
        }
        normalClient.start()
    }

    private static func startAuthenticationFixture(_ executable: URL) {
        authClient = QuotaClient(executableURL: executable)
        authClient.onConnectionState = { state in
            guard state == .authenticationRequired else { return }
            authClient.stop()
            startMissingFixture()
        }
        authClient.start()
    }

    private static func startMissingFixture() {
        let locator = CountingLocator(location: nil)
        missingClient = QuotaClient(locator: locator)
        missingClient.onConnectionState = { state in
            guard state == .codexNotInstalled else { return }
            if locator.calls == 1 {
                DispatchQueue.main.async { missingClient.refresh() }
            } else {
                guard locator.calls == 2 else { fail("reconnect must ask the locator again: \(locator.calls)") }
                missingClient.stop()
                print("PASS: fragmented JSON, quota polling, tasks, structured connection states, and rediscovery")
                exit(0)
            }
        }
        missingClient.start()
    }

    private static func fail(_ message: String) -> Never {
        fputs("FAIL: \(message)\n", stderr)
        normalClient?.stop(); authClient?.stop(); missingClient?.stop()
        exit(1)
    }
}
