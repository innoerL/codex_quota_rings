import Foundation

enum QuotaUsageAlert: Equatable {
    case none
    case spike

    var localizedLabel: String? {
        switch self {
        case .none: return nil
        case .spike: return localized("用量突然升高", "Usage rose sharply")
        }
    }
}

struct QuotaSpikeEvidence: Equatable {
    let recentIncrease: Double
    let speedMultiplier: Double

    var localizedLabel: String {
        let increase = String(format: "%.1f", recentIncrease)
        let multiplier = String(format: "%.1f", speedMultiplier)
        return localized("用量突增：近 5 分钟 +\(increase)% · 约此前 \(multiplier) 倍",
                         "Usage spike: +\(increase)% / 5m · \(multiplier)× prior pace")
    }
}

enum RingFeedback: Equatable {
    case rest
    case surgeHalo
    case breathing

    static func resolve(usageAlert: QuotaUsageAlert, lowQuota: Bool) -> RingFeedback {
        if usageAlert == .spike { return .surgeHalo }
        return lowQuota ? .breathing : .rest
    }

    static let surgeCycleDuration: TimeInterval = 1.25
    static func surgeProgress(after elapsed: TimeInterval) -> Double {
        guard elapsed.isFinite, elapsed >= 0 else { return 0 }
        return (elapsed / surgeCycleDuration).truncatingRemainder(dividingBy: 1)
    }
}

struct QuotaUsageAlertEngine {
    private struct Sample {
        let usedPercent: Double
        let resetAt: TimeInterval
        let date: Date
    }

    private var samples: [Sample] = []
    private(set) var spikeEvidence: QuotaSpikeEvidence?

    mutating func record(_ snapshot: QuotaSnapshot) -> QuotaUsageAlert {
        guard let window = snapshot.fiveHour,
              let usedPercent = window.clampedUsedPercent,
              let resetAt = window.resetsAt else {
            samples.removeAll()
            spikeEvidence = nil
            return .none
        }
        if let last = samples.last,
           abs(last.resetAt - resetAt) > 0.5 || usedPercent + 0.25 < last.usedPercent {
            samples.removeAll()
        }
        guard samples.last?.date != snapshot.fetchedAt else { return updateAlert(at: snapshot.fetchedAt) }
        samples.append(Sample(usedPercent: usedPercent, resetAt: resetAt, date: snapshot.fetchedAt))
        let cutoff = snapshot.fetchedAt.addingTimeInterval(-30 * 60)
        samples.removeAll { $0.date < cutoff || abs($0.resetAt - resetAt) > 0.5 }
        return updateAlert(at: snapshot.fetchedAt)
    }

    private mutating func updateAlert(at date: Date) -> QuotaUsageAlert {
        let recentCutoff = date.addingTimeInterval(-5 * 60)
        let baseline = samples.filter { $0.date <= recentCutoff }
        let recent = samples.filter { $0.date >= recentCutoff }
        guard baseline.count >= 4,
              recent.count >= 2,
              let baselineRate = hourlyRate(baseline), baselineRate >= 0.5,
              let recentRate = hourlyRate(recent), recentRate >= max(baselineRate * 2.5, baselineRate + 5),
              let recentFirst = recent.first, let recentLast = recent.last else {
            spikeEvidence = nil
            return .none
        }
        spikeEvidence = QuotaSpikeEvidence(recentIncrease: max(0, recentLast.usedPercent - recentFirst.usedPercent),
                                           speedMultiplier: recentRate / baselineRate)
        return .spike
    }

    private func hourlyRate(_ values: [Sample]) -> Double? {
        guard let first = values.first, let last = values.last else { return nil }
        let elapsed = last.date.timeIntervalSince(first.date)
        let consumption = last.usedPercent - first.usedPercent
        guard elapsed > 0, consumption >= 0 else { return nil }
        return consumption / elapsed * 3_600
    }
}
