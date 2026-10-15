import Foundation

enum ForecastOutcome: Equatable {
    case collecting
    case unstable
    case willNotDeplete
    case depletedAt(Date)
}

enum ForecastConfidence: Equatable {
    case high
    case medium
    case low

    var chineseLabel: String {
        switch self {
        case .high: return "高"
        case .medium: return "中"
        case .low: return "低"
        }
    }
}

struct QuotaForecast: Equatable {
    let outcome: ForecastOutcome
    let confidence: ForecastConfidence?

    static let collecting = QuotaForecast(outcome: .collecting, confidence: nil)
    static let unstable = QuotaForecast(outcome: .unstable, confidence: nil)
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

    mutating func record(_ snapshot: QuotaSnapshot) -> QuotaForecasts {
        let fiveHour = Self.record(snapshot.fiveHour, at: snapshot.fetchedAt, samples: &fiveHourSamples)
        return QuotaForecasts(fiveHour: fiveHour, week: .collecting)
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
              let rollingRate = robustHourlyRate(for: samples),
              let recentRate = robustHourlyRate(for: recentSamples),
              let recentEndToEndRate = endToEndHourlyRate(for: recentSamples),
              rollingRate >= 0.1, recentRate >= 0.1, recentEndToEndRate >= 0.1 else { return .collecting }

        let largestDifference = max(relativeDifference(rollingRate, recentRate),
                                    relativeDifference(rollingRate, recentEndToEndRate),
                                    relativeDifference(recentRate, recentEndToEndRate))
        guard largestDifference <= 0.35 else { return .unstable }

        let span = date.timeIntervalSince(first.date)
        let confidence: ForecastConfidence
        if samples.count >= 12, span >= 20 * 60, largestDifference <= 0.15 {
            confidence = .high
        } else if samples.count >= 8, span >= 15 * 60, largestDifference <= 0.25 {
            confidence = .medium
        } else {
            confidence = .low
        }
        let secondsUntilDepletion = remainingPercent / recentEndToEndRate * 3_600
        let depletionDate = date.addingTimeInterval(secondsUntilDepletion)
        let outcome: ForecastOutcome = depletionDate.timeIntervalSince1970 >= resetAt ? .willNotDeplete : .depletedAt(depletionDate)
        return QuotaForecast(outcome: outcome, confidence: confidence)
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

    private static func relativeDifference(_ first: Double, _ second: Double) -> Double {
        abs(first - second) / max(first, second, 0.1)
    }
}
