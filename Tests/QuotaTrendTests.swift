import Foundation

@main struct QuotaTrendTests {
    static func main() {
        let start = Date(timeIntervalSince1970: 1_000)
        func sample(_ seconds: TimeInterval, _ five: Double?, _ week: Double?) -> QuotaHistorySample {
            QuotaHistorySample(timestamp: start.addingTimeInterval(seconds),
                               fiveHourUsedPercent: five, weekUsedPercent: week)
        }

        precondition(QuotaTrendSeries.make(samples: []) == QuotaTrendSeries(fiveHour: []))
        let one = QuotaTrendSeries.make(samples: [sample(0, 20, nil)])
        precondition(one.fiveHour == [[QuotaTrendPoint(x: 0, y: 0.8)]])

        let normalSamples = [sample(0, 20, 40), sample(10, 30, nil), sample(20, 40, 60)]
        let normal = QuotaTrendSeries.make(samples: normalSamples)
        precondition(normal.fiveHour == [[QuotaTrendPoint(x: 0, y: 0.8),
                                         QuotaTrendPoint(x: 0.5, y: 0.7),
                                         QuotaTrendPoint(x: 1, y: 0.6)]])
        let axisRange = QuotaTrendRenderer.timeRange(for: [sample(0, 20, nil), sample(20, 40, nil)])
        precondition(axisRange?.start == start && axisRange?.end == start.addingTimeInterval(20),
                     "trend axes must use the first and latest local samples as their time bounds")

        let reset = QuotaTrendSeries.make(samples: [sample(0, 70, 70), sample(10, 80, 80), sample(20, 20, 50)])
        precondition(reset.fiveHour.count == 2 && reset.fiveHour[0].count == 2 && reset.fiveHour[1].count == 1,
                     "a large used-percent drop must start a new five-hour segment")

        guard let hover = QuotaTrendInteraction.nearestSample(at: 0.5, in: normalSamples),
              hover.sample.timestamp == start.addingTimeInterval(10),
              abs((hover.hourlyConsumption ?? 0) - 3_600) < 0.1 else {
            fatalError("FAIL: hovering a trend point must expose its timestamp, used percentage, and local hourly rate")
        }
        let resetSamples = [sample(0, 70, nil), sample(10, 80, nil), sample(20, 20, nil)]
        precondition(QuotaTrendInteraction.nearestSample(at: 1, in: resetSamples)?.hourlyConsumption == nil,
                     "a reset discontinuity must not report a misleading consumption rate")

        print("PASS: five-hour-only reset-aware quota trend geometry and sparse states")
    }
}
