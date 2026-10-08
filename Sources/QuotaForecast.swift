import Foundation

enum QuotaForecast: Equatable {
    case collecting
    case withinCurrentWindow
    case depletedAt(Date)
}

struct QuotaForecasts: Equatable {
    let fiveHour: QuotaForecast
    let week: QuotaForecast

    static let collecting = QuotaForecasts(fiveHour: .collecting, week: .collecting)
}

struct QuotaForecastEngine {
    private struct Sample {
        let usedPercent: Double
        let resetAt: TimeInterval
        let date: Date
    }

    private var fiveHourSamples: [Sample] = []
    private var weekSamples: [Sample] = []

    mutating func record(_ snapshot: QuotaSnapshot) -> QuotaForecasts {
        let fiveHour = Self.record(snapshot.fiveHour, at: snapshot.fetchedAt, samples: &fiveHourSamples)
        let week = Self.record(snapshot.week, at: snapshot.fetchedAt, samples: &weekSamples)
        return QuotaForecasts(fiveHour: fiveHour, week: week)
    }

    private static func record(_ window: QuotaWindow?, at date: Date, samples: inout [Sample]) -> QuotaForecast {
        guard let window,
              let resetAt = window.resetsAt,
              let usedPercent = window.clampedUsedPercent,
              let remainingPercent = window.remainingPercent else {
            samples.removeAll()
            return .collecting
        }

        if let last = samples.last,
           abs(last.resetAt - resetAt) > 0.5 || usedPercent + 0.25 < last.usedPercent {
            samples.removeAll()
        }

        if samples.last?.date == date {
            return forecast(at: date, resetAt: resetAt, remainingPercent: remainingPercent, samples: samples)
        }

        samples.append(Sample(usedPercent: usedPercent, resetAt: resetAt, date: date))
        let earliest = date.addingTimeInterval(-30 * 60)
        samples.removeAll { $0.date < earliest || abs($0.resetAt - resetAt) > 0.5 }

        return forecast(at: date, resetAt: resetAt, remainingPercent: remainingPercent, samples: samples)
    }

    private static func forecast(at date: Date, resetAt: TimeInterval, remainingPercent: Double, samples: [Sample]) -> QuotaForecast {
        guard samples.count >= 4,
              let first = samples.first,
              date.timeIntervalSince(first.date) >= 120 else { return .collecting }

        let hourlyRates = zip(samples, samples.dropFirst()).compactMap { earlier, later -> Double? in
            let seconds = later.date.timeIntervalSince(earlier.date)
            let increase = later.usedPercent - earlier.usedPercent
            guard seconds > 0, increase > 0 else { return nil }
            return increase / seconds * 3_600
        }.sorted()
        guard !hourlyRates.isEmpty else { return .collecting }
        let median = hourlyRates[hourlyRates.count / 2]
        guard median >= 0.1 else { return .collecting }

        let secondsUntilDepletion = remainingPercent / median * 3_600
        let depletionDate = date.addingTimeInterval(secondsUntilDepletion)
        return depletionDate.timeIntervalSince1970 >= resetAt ? .withinCurrentWindow : .depletedAt(depletionDate)
    }
}
