import Foundation

@main struct QuotaSignalTests {
    static func main() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let reset = start.addingTimeInterval(5 * 3_600).timeIntervalSince1970
        func snapshot(used: Double, at minute: Int, resetAt: TimeInterval = reset) -> QuotaSnapshot {
            QuotaSnapshot(fiveHour: QuotaWindow(usedPercent: used, windowDurationMins: 300, resetsAt: resetAt),
                          week: nil, fetchedAt: start.addingTimeInterval(Double(minute) * 60))
        }

        var engine = QuotaUsageAlertEngine()
        var alert: QuotaUsageAlert = .none
        for minute in 0...10 {
            alert = engine.record(snapshot(used: 10 + Double(minute) * 0.1, at: minute))
        }
        precondition(alert == .none, "FAIL: steady use must not be an anomaly")
        for minute in 11...15 {
            alert = engine.record(snapshot(used: 11 + Double(minute - 10), at: minute))
        }
        precondition(alert == .spike, "FAIL: a five-minute rate far above the earlier rate must be shown")

        var resetEngine = QuotaUsageAlertEngine()
        for minute in 0...15 {
            _ = resetEngine.record(snapshot(used: 10 + Double(minute), at: minute))
        }
        let afterReset = resetEngine.record(snapshot(used: 1, at: 16, resetAt: reset + 1_000))
        precondition(afterReset == .none, "FAIL: a reset must clear earlier anomaly evidence")

        let imminent = QuotaWindow(usedPercent: 20, windowDurationMins: 300,
                                   resetsAt: start.addingTimeInterval(14 * 60).timeIntervalSince1970)
        let distant = QuotaWindow(usedPercent: 20, windowDurationMins: 300,
                                  resetsAt: start.addingTimeInterval(16 * 60).timeIntervalSince1970)
        precondition(imminent.isResetImminent(at: start) && !distant.isResetImminent(at: start),
                     "FAIL: reset emphasis must begin only in the final fifteen minutes")
        print("PASS: local spike detection and imminent reset emphasis")
    }
}
