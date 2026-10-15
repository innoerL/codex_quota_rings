import Foundation

enum QuotaUsageAlert: Equatable {
    case none
    case spike

    var chineseLabel: String? {
        switch self {
        case .none: return nil
        case .spike: return "用量突然升高"
        }
    }
}

struct QuotaUsageAlertEngine {
    private struct Sample {
        let usedPercent: Double
        let resetAt: TimeInterval
        let date: Date
    }

    private var samples: [Sample] = []

    mutating func record(_ snapshot: QuotaSnapshot) -> QuotaUsageAlert {
        guard let window = snapshot.fiveHour,
              let usedPercent = window.clampedUsedPercent,
              let resetAt = window.resetsAt else {
            samples.removeAll()
            return .none
        }
        if let last = samples.last,
           abs(last.resetAt - resetAt) > 0.5 || usedPercent + 0.25 < last.usedPercent {
            samples.removeAll()
        }
        guard samples.last?.date != snapshot.fetchedAt else { return alert(at: snapshot.fetchedAt) }
        samples.append(Sample(usedPercent: usedPercent, resetAt: resetAt, date: snapshot.fetchedAt))
        let cutoff = snapshot.fetchedAt.addingTimeInterval(-30 * 60)
        samples.removeAll { $0.date < cutoff || abs($0.resetAt - resetAt) > 0.5 }
        return alert(at: snapshot.fetchedAt)
    }

    private func alert(at date: Date) -> QuotaUsageAlert {
        let recentCutoff = date.addingTimeInterval(-5 * 60)
        let baseline = samples.filter { $0.date <= recentCutoff }
        let recent = samples.filter { $0.date >= recentCutoff }
        guard baseline.count >= 4,
              recent.count >= 2,
              let baselineRate = hourlyRate(baseline), baselineRate >= 0.5,
              let recentRate = hourlyRate(recent), recentRate >= max(baselineRate * 2.5, baselineRate + 5) else {
            return .none
        }
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
