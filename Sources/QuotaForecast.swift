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

    /// Relative uncertainty applied to the observed consumption rate. A faster
    /// plausible rate gives the early bound and a slower one gives the late bound.
    var rateUncertainty: Double {
        switch self {
        case .high: return 0.10
        case .medium: return 0.20
        case .low: return 0.35
        }
    }
}

struct QuotaForecast: Equatable {
    let outcome: ForecastOutcome
    let confidence: ForecastConfidence?
    /// The plausible depletion interval when the nominal forecast is before reset.
    let depletionRange: DateInterval?

    init(outcome: ForecastOutcome, confidence: ForecastConfidence?, depletionRange: DateInterval? = nil) {
        self.outcome = outcome
        self.confidence = confidence
        self.depletionRange = depletionRange
    }

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

    var hasFiveHourSampleData: Bool { !fiveHourSamples.isEmpty }
    var fiveHourSampleCount: Int { fiveHourSamples.count }

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
        guard samples.count >= 2,
              let first = samples.first,
              let consumptionRate = endToEndHourlyRate(for: samples),
              consumptionRate > 0.01 else { return .collecting }

        let span = date.timeIntervalSince(first.date)
        let confidence: ForecastConfidence
        if samples.count >= 12, span >= 20 * 60 {
            confidence = .high
        } else if samples.count >= 8, span >= 15 * 60 {
            confidence = .medium
        } else {
            confidence = .low
        }
        let secondsUntilDepletion = remainingPercent / consumptionRate * 3_600
        let depletionDate = date.addingTimeInterval(secondsUntilDepletion)
        guard depletionDate.timeIntervalSince1970 < resetAt else {
            return QuotaForecast(outcome: .willNotDeplete, confidence: confidence)
        }

        let uncertainty = confidence.rateUncertainty
        let earliest = date.addingTimeInterval(remainingPercent / (consumptionRate * (1 + uncertainty)) * 3_600)
        let resetDate = Date(timeIntervalSince1970: resetAt)
        let latestEstimate = date.addingTimeInterval(remainingPercent / (consumptionRate * (1 - uncertainty)) * 3_600)
        let latest = min(latestEstimate, resetDate)
        let range = latest > earliest ? DateInterval(start: earliest, end: latest) : nil
        return QuotaForecast(outcome: .depletedAt(depletionDate), confidence: confidence, depletionRange: range)
    }

    private static func endToEndHourlyRate(for samples: [Sample]) -> Double? {
        guard let first = samples.first, let last = samples.last else { return nil }
        let seconds = last.date.timeIntervalSince(first.date)
        let increase = last.usedPercent - first.usedPercent
        guard seconds > 0, increase >= 0 else { return nil }
        return increase / seconds * 3_600
    }

}
