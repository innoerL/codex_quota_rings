import Foundation

@main struct ProtocolTests {
    static func main() {
        let client = QuotaClient(executableURL: URL(fileURLWithPath: CommandLine.arguments[1]))
        var readings: [Int] = []
        client.onChange = { snapshot, error in
            if let error {
                guard readings == [20, 25, 26], snapshot?.fiveHour?.remainingPercent == 26 else {
                    fputs("FAIL: protocol, notification, or stale last-value handling: \(readings); \(error)\n", stderr)
                    client.stop(); exit(1)
                }
                client.stop()
                print("PASS: fragmented JSON, handshake, two read-only polls, push update, disconnect state")
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
