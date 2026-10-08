import Foundation

enum QuotaLevel { case ample, caution, low, unknown }

struct QuotaWindow: Decodable {
    let usedPercent: Double?
    let windowDurationMins: Int?
    let resetsAt: Double?
    var clampedUsedPercent: Double? {
        guard let usedPercent, usedPercent.isFinite else { return nil }
        return min(100, max(0, usedPercent))
    }
    var remainingPercent: Double? { clampedUsedPercent.map { 100 - $0 } }
    var level: QuotaLevel {
        guard let remainingPercent else { return .unknown }
        if remainingPercent > 50 { return .ample }
        return remainingPercent >= 20 ? .caution : .low
    }
    static func resetCountdown(seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "等待重置" }
        if seconds < 60 { return "不到 1 分钟后重置" }
        let minutes = Int(min(seconds / 60, 5256000))
        let days = minutes / 1440, hours = (minutes % 1440) / 60
        if days > 0 { return "\(days) 天 \(hours) 小时后重置" }
        if hours > 0 { return "\(hours) 小时 \(minutes % 60) 分钟后重置" }
        return "\(minutes) 分钟后重置"
    }
    func resetDescription(at now: Date = Date()) -> String {
        guard let resetsAt, resetsAt.isFinite else { return "重置时间暂不可用" }
        let reset = Date(timeIntervalSince1970: resetsAt)
        let format = DateFormatter(); format.dateFormat = "M/d HH:mm"
        return "\(Self.resetCountdown(seconds: reset.timeIntervalSince(now))) · \(format.string(from: reset))"
    }
}

private struct QuotaBucket: Decodable {
    let limitId: String?
    let primary: QuotaWindow?
    let secondary: QuotaWindow?
}
private struct QuotaResponse: Decodable {
    let rateLimits: QuotaBucket?
    let rateLimitsByLimitId: [String: QuotaBucket]?
}

struct QuotaSnapshot {
    let fiveHour: QuotaWindow?
    let week: QuotaWindow?
    let fetchedAt: Date
    static func decode(_ data: Data, at date: Date = Date()) throws -> QuotaSnapshot {
        let response = try JSONDecoder().decode(QuotaResponse.self, from: data)
        let bucket: QuotaBucket?
        if let map = response.rateLimitsByLimitId {
            bucket = map["codex"]
        } else if response.rateLimits?.limitId == nil || response.rateLimits?.limitId == "codex" {
            bucket = response.rateLimits
        } else { bucket = nil }
        let windows = [bucket?.primary, bucket?.secondary].compactMap { $0 }
        return QuotaSnapshot(fiveHour: windows.first { $0.windowDurationMins == 300 },
                             week: windows.first { $0.windowDurationMins == 10080 }, fetchedAt: date)
    }
    func isStale(at date: Date = Date()) -> Bool { date.timeIntervalSince(fetchedAt) > 90 }
}
