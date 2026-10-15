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
        var depletion: QuotaForecast = .collecting
        for minute in 0...10 {
            depletion = depletionEngine.record(snapshot(used: 10 + Double(minute), reset: start.addingTimeInterval(10_800).timeIntervalSince1970,
                                                       at: start.addingTimeInterval(Double(minute) * 60))).fiveHour
        }
        guard case let .depletedAt(date) = depletion.outcome,
              abs(date.timeIntervalSince(start) - 5_400) < 1 else {
            fatalError("FAIL: positive recent use must predict depletion before reset")
        }

        var resetEngine = QuotaForecastEngine()
        var afterReset: QuotaForecast = .collecting
        for minute in 0...10 {
            let used = 10 + Double(minute)
            afterReset = resetEngine.record(snapshot(used: used, reset: start.addingTimeInterval(600).timeIntervalSince1970,
                                                       at: start.addingTimeInterval(Double(minute) * 60))).fiveHour
        }
        precondition(afterReset.outcome == .willNotDeplete, "FAIL: predicted depletion after reset must not claim a time")

        var idleEngine = QuotaForecastEngine()
        var idleForecast: QuotaForecast = .collecting
        for minute in 0...10 {
            idleForecast = idleEngine.record(snapshot(used: 10, reset: start.addingTimeInterval(3_600).timeIntervalSince1970,
                                                       at: start.addingTimeInterval(Double(minute) * 60))).fiveHour
        }
        precondition(idleForecast.outcome == .collecting, "FAIL: flat usage must stay in collecting state")

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

        var duplicateEngine = QuotaForecastEngine()
        for minute in 0...9 {
            _ = duplicateEngine.record(snapshot(used: 10 + Double(minute), reset: start.addingTimeInterval(10_800).timeIntervalSince1970,
                                               at: start.addingTimeInterval(Double(minute) * 60)))
        }
        let duplicate = duplicateEngine.record(snapshot(used: 19, reset: start.addingTimeInterval(10_800).timeIntervalSince1970,
                                                        at: start.addingTimeInterval(540))).fiveHour
        precondition(duplicate.outcome == .collecting, "FAIL: retrying a stale snapshot must not create an extra forecast sample")

        var unstableEngine = QuotaForecastEngine()
        var unstable: QuotaForecast = .collecting
        for minute in 0...10 {
            let used = minute == 10 ? 40.0 : 10 + Double(minute)
            unstable = unstableEngine.record(snapshot(used: used, reset: start.addingTimeInterval(7_200).timeIntervalSince1970,
                                                       at: start.addingTimeInterval(Double(minute) * 60))).fiveHour
        }
        precondition(unstable.outcome == .unstable,
                     "FAIL: a recent spike that disagrees with the stable rate must suppress a depletion time")

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
                     "FAIL: 8+ samples over 15 minutes with <=25% difference must be medium confidence")
        precondition(forecast(samples: 11, minutes: 10, wobble: 0).confidence == .low,
                     "FAIL: 6+ samples over 10 minutes with <=35% difference must be low confidence")

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

        print("PASS: quota forecasts cover confidence, depletion, reset, idle, and no-week behavior")
    }
}
