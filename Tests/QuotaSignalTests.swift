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
        precondition(engine.spikeEvidence?.recentIncrease == 5
                     && engine.spikeEvidence?.speedMultiplier == 10
                     && engine.spikeEvidence?.localizedLabel.contains("近 5 分钟 +5.0%") == true,
                     "光环原因应来自同一次突增判定的增量与速率")
        _ = engine.record(snapshot(used: 16, at: 15))
        precondition(engine.spikeEvidence?.recentIncrease == 5,
                     "重复采样不得改变光环原因")

        var resetEngine = QuotaUsageAlertEngine()
        for minute in 0...15 {
            _ = resetEngine.record(snapshot(used: 10 + Double(minute), at: minute))
        }
        let afterReset = resetEngine.record(snapshot(used: 1, at: 16, resetAt: reset + 1_000))
        precondition(afterReset == .none, "FAIL: a reset must clear earlier anomaly evidence")
        precondition(resetEngine.spikeEvidence == nil, "重置后应清除突增原因")

        let imminent = QuotaWindow(usedPercent: 20, windowDurationMins: 300,
                                   resetsAt: start.addingTimeInterval(14 * 60).timeIntervalSince1970)
        let distant = QuotaWindow(usedPercent: 20, windowDurationMins: 300,
                                  resetsAt: start.addingTimeInterval(16 * 60).timeIntervalSince1970)
        precondition(imminent.isResetImminent(at: start) && !distant.isResetImminent(at: start),
                     "FAIL: reset emphasis must begin only in the final fifteen minutes")
        precondition(RingFeedback.resolve(usageAlert: .none, lowQuota: false) == .rest,
                     "FAIL: stable usage must keep the rings at rest")
        precondition(RingFeedback.resolve(usageAlert: .spike, lowQuota: false) == .surgeHalo,
                     "用量突增应使用扩散光环提示")
        precondition(RingFeedback.resolve(usageAlert: .none, lowQuota: true) == .breathing,
                     "FAIL: low quota must select the slow breathing halo")
        precondition(RingFeedback.resolve(usageAlert: .spike, lowQuota: true) == .surgeHalo,
                     "用量突增时扩散光环应优先于低额度呼吸效果")
        precondition(RingFeedback.surgeProgress(after: 0) == 0
                     && RingFeedback.surgeProgress(after: 0.625) == 0.5
                     && RingFeedback.surgeProgress(after: 1.25) == 0
                     && RingFeedback.surgeProgress(after: 2.5) == 0,
                     "扩散光环应每 1.25 秒循环一次")
        print("PASS: local spike detection, reset emphasis, and ring feedback states")
    }
}
