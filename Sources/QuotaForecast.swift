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
    var englishLabel: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
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
    /// Metadata for explaining the estimate without exposing raw samples.
    let sampleCount: Int
    let observedSpan: TimeInterval
    let hourlyConsumption: Double?

    init(outcome: ForecastOutcome, confidence: ForecastConfidence?, depletionRange: DateInterval? = nil,
         sampleCount: Int = 0, observedSpan: TimeInterval = 0, hourlyConsumption: Double? = nil) {
        self.outcome = outcome
        self.confidence = confidence
        self.depletionRange = depletionRange
        self.sampleCount = sampleCount
        self.observedSpan = observedSpan
        self.hourlyConsumption = hourlyConsumption
    }

    static let collecting = QuotaForecast(outcome: .collecting, confidence: nil)
    static let unstable = QuotaForecast(outcome: .unstable, confidence: nil)

    var explanation: String {
        guard sampleCount > 0 else { return localized("预测依据：等待额度采样", "Forecast basis: waiting for quota samples") }
        let minutes = max(0, Int((observedSpan / 60).rounded(.down)))
        let span = minutes > 0 ? localized("\(minutes) 分钟", "\(minutes) min") : localized("不足 1 分钟", "under 1 min")
        guard let hourlyConsumption, hourlyConsumption > 0.01 else {
            return localized("预测依据：\(sampleCount) 个采样 · \(span) · 等待消耗数据", "Forecast basis: \(sampleCount) samples · \(span) · waiting for consumption data")
        }
        let confidenceText = confidence.map { localized(" · 可信度：\($0.chineseLabel)", " · confidence: \($0.englishLabel)") } ?? ""
        return localized(String(format: "预测依据：%d 个采样 · %@\n%.1f%%/小时%@", sampleCount, span, hourlyConsumption, confidenceText),
                         String(format: "Forecast basis: %d samples · %@\n%.1f%%/hour%@", sampleCount, span, hourlyConsumption, confidenceText))
    }
}

struct QuotaForecasts: Equatable {
    let fiveHour: QuotaForecast
    let week: QuotaForecast

    static let collecting = QuotaForecasts(fiveHour: .collecting, week: .collecting)
}

enum ForecastChange: Equatable {
    case earlier(by: TimeInterval)
    case later(by: TimeInterval)

    var localizedLabel: String {
        let interval: TimeInterval
        let prefix: String
        switch self {
        case .earlier(let by): interval = by; prefix = "提前"
        case .later(let by): interval = by; prefix = "推迟"
        }
        let minutes = max(1, Int((interval / 60).rounded()))
        let englishDirection = prefix == "提前" ? "earlier" : "later"
        return localized("预测较上次\(prefix) \(minutes) 分钟", "Forecast is \(englishDirection) by \(minutes) minutes")
    }

    var level: QuotaLevel {
        switch self {
        case .earlier: return .low
        case .later: return .ample
        }
    }
}

/// Reports only meaningful movement, comparing every update to the last
/// acknowledged estimate so gradual changes can accumulate into one signal.
struct ForecastChangeDetector {
    private let threshold: TimeInterval
    private var baseline: Date?

    init(threshold: TimeInterval = 10 * 60) { self.threshold = threshold }

    mutating func record(_ forecast: QuotaForecast) -> ForecastChange? {
        guard case let .depletedAt(date) = forecast.outcome else {
            baseline = nil
            return nil
        }
        guard let baseline else {
            self.baseline = date
            return nil
        }
        let change = date.timeIntervalSince(baseline)
        guard abs(change) >= threshold else { return nil }
        self.baseline = date
        return change < 0 ? .earlier(by: -change) : .later(by: change)
    }
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
        let span = samples.first.map { max(0, date.timeIntervalSince($0.date)) } ?? 0
        guard samples.count >= 2,
              let consumptionRate = endToEndHourlyRate(for: samples),
              consumptionRate > 0.01 else {
            return QuotaForecast(outcome: .collecting, confidence: nil,
                                 sampleCount: samples.count, observedSpan: span)
        }

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
            return QuotaForecast(outcome: .willNotDeplete, confidence: confidence,
                                 sampleCount: samples.count, observedSpan: span, hourlyConsumption: consumptionRate)
        }

        let uncertainty = confidence.rateUncertainty
        let earliest = date.addingTimeInterval(remainingPercent / (consumptionRate * (1 + uncertainty)) * 3_600)
        let resetDate = Date(timeIntervalSince1970: resetAt)
        let latestEstimate = date.addingTimeInterval(remainingPercent / (consumptionRate * (1 - uncertainty)) * 3_600)
        let latest = min(latestEstimate, resetDate)
        let range = latest > earliest ? DateInterval(start: earliest, end: latest) : nil
        return QuotaForecast(outcome: .depletedAt(depletionDate), confidence: confidence, depletionRange: range,
                             sampleCount: samples.count, observedSpan: span, hourlyConsumption: consumptionRate)
    }

    private static func endToEndHourlyRate(for samples: [Sample]) -> Double? {
        guard let first = samples.first, let last = samples.last else { return nil }
        let seconds = last.date.timeIntervalSince(first.date)
        let increase = last.usedPercent - first.usedPercent
        guard seconds > 0, increase >= 0 else { return nil }
        return increase / seconds * 3_600
    }

}
