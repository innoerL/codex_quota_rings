import Foundation

@main struct QuotaTrendTests {
    static func main() {
        let start = Date(timeIntervalSince1970: 1_000)
        func sample(_ seconds: TimeInterval, _ five: Double?, _ week: Double?) -> QuotaHistorySample {
            QuotaHistorySample(timestamp: start.addingTimeInterval(seconds),
                               fiveHourUsedPercent: five, weekUsedPercent: week)
        }

        precondition(QuotaTrendSeries.make(samples: []) == QuotaTrendSeries(fiveHour: [], week: []))
        let one = QuotaTrendSeries.make(samples: [sample(0, 20, nil)])
        precondition(one.fiveHour == [[QuotaTrendPoint(x: 0, y: 0.8)]] && one.week.isEmpty)

        let normal = QuotaTrendSeries.make(samples: [sample(0, 20, 40), sample(10, 30, nil), sample(20, 40, 60)])
        precondition(normal.fiveHour == [[QuotaTrendPoint(x: 0, y: 0.8),
                                         QuotaTrendPoint(x: 0.5, y: 0.7),
                                         QuotaTrendPoint(x: 1, y: 0.6)]])
        precondition(normal.week == [[QuotaTrendPoint(x: 0, y: 0.6)], [QuotaTrendPoint(x: 1, y: 0.4)]],
                     "missing values must break a line")

        let reset = QuotaTrendSeries.make(samples: [sample(0, 70, 70), sample(10, 80, 80), sample(20, 20, 50)])
        precondition(reset.fiveHour.count == 2 && reset.fiveHour[0].count == 2 && reset.fiveHour[1].count == 1,
                     "a large used-percent drop must start a new five-hour segment")
        precondition(reset.week.count == 2, "reset boundaries are independent for each quota window")

        print("PASS: reset-aware quota trend geometry and sparse states")
    }
}
