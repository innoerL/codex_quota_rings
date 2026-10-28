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
        precondition(normal.resetPositions.isEmpty, "用量平稳上升时不得标出重置点")
        let axisRange = QuotaTrendRenderer.timeRange(for: [sample(0, 20, nil), sample(20, 40, nil)])
        precondition(axisRange?.start == start && axisRange?.end == start.addingTimeInterval(20),
                     "trend axes must use the first and latest local samples as their time bounds")

        let reset = QuotaTrendSeries.make(samples: [sample(0, 70, 70), sample(10, 80, 80), sample(20, 20, 50)])
        precondition(reset.fiveHour.count == 2 && reset.fiveHour[0].count == 2 && reset.fiveHour[1].count == 1,
                     "a large used-percent drop must start a new five-hour segment")
        precondition(reset.resetPositions == [1], "重置标记应对齐重置后的第一份采样")
        let middleReset = QuotaTrendSeries.make(samples: [sample(0, 60, 20), sample(10, 70, 30),
                                                           sample(20, 10, 40), sample(30, 15, 50)])
        precondition(middleReset.resetPositions == [2.0 / 3.0], "中间的重置标记应落在正确的时间位置")
        let noFiveHourReset = QuotaTrendSeries.make(samples: [sample(0, 20, 90), sample(10, 25, 10)])
        precondition(noFiveHourReset.resetPositions.isEmpty, "一周额度回落不得标成 5 小时额度重置")
        let missingBeforeReset = QuotaTrendSeries.make(samples: [sample(0, 70, nil), sample(10, nil, nil), sample(20, 10, nil)])
        precondition(missingBeforeReset.resetPositions.isEmpty, "采样断档时不得推断重置点")

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
