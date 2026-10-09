import Foundation

enum QuotaForecast: Equatable {
    case collecting
    case unstable
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
        guard samples.count >= 6,
              let first = samples.first,
              date.timeIntervalSince(first.date) >= 10 * 60 else { return .collecting }

        let recentCutoff = date.addingTimeInterval(-10 * 60)
        let recentSamples = samples.filter { $0.date >= recentCutoff }
        guard recentSamples.count >= 4,
              let recentFirst = recentSamples.first,
              date.timeIntervalSince(recentFirst.date) >= 5 * 60,
              let longRate = robustHourlyRate(for: samples),
              let recentRate = robustHourlyRate(for: recentSamples),
              let recentEndToEndRate = endToEndHourlyRate(for: recentSamples) else { return .collecting }

        guard recentRate >= 0.1, recentEndToEndRate >= 0.1 else { return .collecting }
        guard ratesAgree(longRate, recentRate), ratesAgree(recentRate, recentEndToEndRate) else { return .unstable }

        let secondsUntilDepletion = remainingPercent / recentEndToEndRate * 3_600
        let depletionDate = date.addingTimeInterval(secondsUntilDepletion)
        return depletionDate.timeIntervalSince1970 >= resetAt ? .withinCurrentWindow : .depletedAt(depletionDate)
    }

    private static func robustHourlyRate(for samples: [Sample]) -> Double? {
        let rates = samples.indices.flatMap { start in
            samples.indices.dropFirst(start + 1).compactMap { end -> Double? in
                let seconds = samples[end].date.timeIntervalSince(samples[start].date)
                let increase = samples[end].usedPercent - samples[start].usedPercent
                guard seconds > 0, increase >= 0 else { return nil }
                return increase / seconds * 3_600
            }
        }.sorted()
        guard !rates.isEmpty else { return nil }
        return rates[rates.count / 2]
    }

    private static func endToEndHourlyRate(for samples: [Sample]) -> Double? {
        guard let first = samples.first, let last = samples.last else { return nil }
        let seconds = last.date.timeIntervalSince(first.date)
        let increase = last.usedPercent - first.usedPercent
        guard seconds > 0, increase >= 0 else { return nil }
        return increase / seconds * 3_600
    }

    private static func ratesAgree(_ first: Double, _ second: Double) -> Bool {
        abs(first - second) / max(first, second, 0.1) <= 0.35
    }
}
