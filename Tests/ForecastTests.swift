import Foundation

@main struct ForecastTests {
    static func main() {
        func snapshot(used: Double, reset: TimeInterval, at date: Date) -> QuotaSnapshot {
            QuotaSnapshot(
                fiveHour: QuotaWindow(usedPercent: used, windowDurationMins: 300, resetsAt: reset),
                week: nil,
                fetchedAt: date
            )
        }

        let start = Date(timeIntervalSince1970: 1_700_000_000)

        var depletionEngine = QuotaForecastEngine()
        precondition(!depletionEngine.hasFiveHourSampleData, "FAIL: a new forecast engine must not claim sample data")
        precondition(depletionEngine.fiveHourSampleCount == 0, "FAIL: a new forecast engine must start with no samples")
        var depletion: QuotaForecast = .collecting
        for minute in 0...10 {
            depletion = depletionEngine.record(snapshot(used: 10 + Double(minute), reset: start.addingTimeInterval(10_800).timeIntervalSince1970,
                                                       at: start.addingTimeInterval(Double(minute) * 60))).fiveHour
        }
        precondition(depletionEngine.hasFiveHourSampleData, "FAIL: a valid quota reading must start forecast sampling")
        precondition(depletionEngine.fiveHourSampleCount == 11, "FAIL: the engine must expose the active-window sample count")
        guard case let .depletedAt(date) = depletion.outcome,
              abs(date.timeIntervalSince(start) - 5_400) < 1 else {
            fatalError("FAIL: positive recent use must predict depletion before reset")
        }
        guard let depletionRange = depletion.depletionRange,
              depletionRange.start < date,
              depletionRange.end > date else {
            fatalError("FAIL: a depletion forecast must expose an interval around its nominal time")
        }
        let refreshed = depletionEngine.record(snapshot(used: 30, reset: start.addingTimeInterval(10_800).timeIntervalSince1970,
                                                       at: start.addingTimeInterval(660))).fiveHour
        guard case let .depletedAt(refreshedDate) = refreshed.outcome else {
            fatalError("FAIL: new samples must keep updating an established forecast")
        }
        precondition(refreshedDate < date,
                     "FAIL: continued sampling must promptly recalculate the estimate from the latest rate")
        precondition(refreshed.sampleCount == 12 && refreshed.hourlyConsumption != nil,
                     "FAIL: updated forecasts must retain their current sampling evidence")

        var resetEngine = QuotaForecastEngine()
        var afterReset: QuotaForecast = .collecting
        for minute in 0...10 {
            let used = 10 + Double(minute)
            afterReset = resetEngine.record(snapshot(used: used, reset: start.addingTimeInterval(600).timeIntervalSince1970,
                                                       at: start.addingTimeInterval(Double(minute) * 60))).fiveHour
        }
        precondition(afterReset.outcome == .willNotDeplete, "FAIL: predicted depletion after reset must not claim a time")
        precondition(afterReset.depletionRange == nil, "FAIL: a reset-bounded forecast must not expose a depletion interval")

        var idleEngine = QuotaForecastEngine()
        var idleForecast: QuotaForecast = .collecting
        for minute in 0...10 {
            idleForecast = idleEngine.record(snapshot(used: 10, reset: start.addingTimeInterval(3_600).timeIntervalSince1970,
                                                       at: start.addingTimeInterval(Double(minute) * 60))).fiveHour
        }
        precondition(idleForecast.outcome == .collecting, "FAIL: flat usage must stay in collecting state")

        var sparseUseEngine = QuotaForecastEngine()
        var sparseUse: QuotaForecast = .collecting
        for minute in 0...20 {
            let used = minute < 10 ? 10.0 : 12.0
            sparseUse = sparseUseEngine.record(snapshot(used: used, reset: start.addingTimeInterval(200_000).timeIntervalSince1970,
                                                        at: start.addingTimeInterval(Double(minute) * 60))).fiveHour
        }
        guard case .depletedAt = sparseUse.outcome else {
            fatalError("FAIL: observed 30-minute consumption must predict even when the latest samples are flat")
        }
        precondition(sparseUse.confidence == .high,
                     "FAIL: a long continuous observation must gain high confidence even when its newest samples are flat")

        var boundaryEngine = QuotaForecastEngine()
        for minute in 0...10 {
            _ = boundaryEngine.record(snapshot(used: 10 + Double(minute), reset: start.addingTimeInterval(10_800).timeIntervalSince1970,
                                               at: start.addingTimeInterval(Double(minute) * 60)))
        }
        let afterBoundary = boundaryEngine.record(snapshot(used: 5, reset: start.addingTimeInterval(7_200).timeIntervalSince1970,
                                                           at: start.addingTimeInterval(660))).fiveHour
        precondition(afterBoundary.outcome == .collecting, "FAIL: a new reset window must discard old samples")

        var missingEngine = QuotaForecastEngine()
        let missing = missingEngine.record(QuotaSnapshot(
            fiveHour: QuotaWindow(usedPercent: nil, windowDurationMins: 300, resetsAt: start.addingTimeInterval(3_600).timeIntervalSince1970),
            week: nil,
            fetchedAt: start
        )).fiveHour
        precondition(missing.outcome == .collecting, "FAIL: missing quota percent must not produce a forecast")
        precondition(!missingEngine.hasFiveHourSampleData, "FAIL: missing quota percent must not count as forecast sampling")

        var duplicateEngine = QuotaForecastEngine()
        var beforeDuplicate: QuotaForecast = .collecting
        for minute in 0...9 {
            beforeDuplicate = duplicateEngine.record(snapshot(used: 10 + Double(minute), reset: start.addingTimeInterval(10_800).timeIntervalSince1970,
                                                               at: start.addingTimeInterval(Double(minute) * 60))).fiveHour
        }
        let duplicate = duplicateEngine.record(snapshot(used: 19, reset: start.addingTimeInterval(10_800).timeIntervalSince1970,
                                                        at: start.addingTimeInterval(540))).fiveHour
        precondition(duplicate == beforeDuplicate, "FAIL: retrying a stale snapshot must not create an extra forecast sample")

        var variableRateEngine = QuotaForecastEngine()
        var variableRate: QuotaForecast = .collecting
        for minute in 0...10 {
            let used = minute == 10 ? 40.0 : 10 + Double(minute)
            variableRate = variableRateEngine.record(snapshot(used: used, reset: start.addingTimeInterval(7_200).timeIntervalSince1970,
                                                              at: start.addingTimeInterval(Double(minute) * 60))).fiveHour
        }
        guard case .depletedAt = variableRate.outcome else {
            fatalError("FAIL: varying consumption must still use total consumption divided by observed time")
        }
        precondition(variableRate.confidence == .low,
                     "FAIL: short observations must remain low confidence even when they include a large change")

        func forecast(samples: Int, minutes: Int, wobble: Double) -> QuotaForecast {
            var engine = QuotaForecastEngine()
            var result = QuotaForecast.collecting
            for index in 0..<samples {
                let progress = Double(index) / Double(max(samples - 1, 1))
                let used = 10 + progress * Double(minutes) + (index.isMultiple(of: 2) ? wobble : -wobble)
                result = engine.record(snapshot(used: used, reset: start.addingTimeInterval(36_000).timeIntervalSince1970,
                                                at: start.addingTimeInterval(progress * Double(minutes) * 60))).fiveHour
            }
            return result
        }
        precondition(forecast(samples: 21, minutes: 20, wobble: 0).confidence == .high,
                     "FAIL: 12+ samples over 20 minutes with <=15% difference must be high confidence")
        precondition(forecast(samples: 16, minutes: 15, wobble: 0).confidence == .medium,
                     "FAIL: 8+ samples over 15 minutes must be medium confidence")
        precondition(forecast(samples: 11, minutes: 10, wobble: 0).confidence == .low,
                     "FAIL: observations below 15 minutes must be low confidence")

        var weekEngine = QuotaForecastEngine()
        var weekly = QuotaForecasts.collecting
        for minute in 0...20 {
            weekly = weekEngine.record(QuotaSnapshot(
                fiveHour: QuotaWindow(usedPercent: 10 + Double(minute), windowDurationMins: 300, resetsAt: start.addingTimeInterval(36_000).timeIntervalSince1970),
                week: QuotaWindow(usedPercent: 10 + Double(minute), windowDurationMins: 10_080, resetsAt: start.addingTimeInterval(36_000).timeIntervalSince1970),
                fetchedAt: start.addingTimeInterval(Double(minute) * 60)
            ))
        }
        precondition(weekly.week.outcome == .collecting && weekly.week.confidence == nil,
                     "FAIL: weekly quota must never produce a depletion forecast")

        print("PASS: quota forecasts cover confidence, live recalculation, depletion, reset, idle, and no-week behavior")
    }
}
