import Foundation

enum AppLanguage: String, CaseIterable {
    case chinese
    case english

    var menuLabel: String { self == .chinese ? "中文" : "English" }
}

enum AppLanguageManager {
    static var current: AppLanguage = .chinese
}

@inline(__always) func localized(_ chinese: String, _ english: String) -> String {
    AppLanguageManager.current == .chinese ? chinese : english
}

enum QuotaLevel { case ample, steady, caution, low, unknown }

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
        if remainingPercent >= 65 { return .ample }
        if remainingPercent >= 30 { return .steady }
        return remainingPercent >= 10 ? .caution : .low
    }
    static func resetCountdown(seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return localized("等待重置", "Waiting for reset") }
        if seconds < 60 { return localized("不到 1 分钟后重置", "Resets in under 1 minute") }
        let minutes = Int(min(seconds / 60, 5256000))
        let days = minutes / 1440, hours = (minutes % 1440) / 60
        if days > 0 { return localized("\(days) 天 \(hours) 小时后重置", "Resets in \(days)d \(hours)h") }
        if hours > 0 { return localized("\(hours) 小时 \(minutes % 60) 分钟后重置", "Resets in \(hours)h \(minutes % 60)m") }
        return localized("\(minutes) 分钟后重置", "Resets in \(minutes)m")
    }
    func resetDescription(at now: Date = Date()) -> String {
        guard let resetsAt, resetsAt.isFinite else { return localized("重置时间暂不可用", "Reset time unavailable") }
        let reset = Date(timeIntervalSince1970: resetsAt)
        let format = DateFormatter(); format.dateFormat = "M/d HH:mm"
        return "\(Self.resetCountdown(seconds: reset.timeIntervalSince(now))) · \(format.string(from: reset))"
    }
    func isResetImminent(at now: Date = Date(), threshold: TimeInterval = 15 * 60) -> Bool {
        guard let resetsAt, resetsAt.isFinite else { return false }
        let remaining = resetsAt - now.timeIntervalSince1970
        return remaining > 0 && remaining <= threshold
    }
}

private struct QuotaBucket: Decodable {
    let limitId: String?
    let primary: QuotaWindow?
    let secondary: QuotaWindow?
}
private struct QuotaResetCredits: Decodable {
    let availableCount: Int?
}
private struct QuotaResponse: Decodable {
    let rateLimits: QuotaBucket?
    let rateLimitsByLimitId: [String: QuotaBucket]?
    let rateLimitResetCredits: QuotaResetCredits?
}

struct QuotaSnapshot {
    let fiveHour: QuotaWindow?
    let week: QuotaWindow?
    /// Saved one-time quota resets reported by the local Codex app-server.
    let resetCreditCount: Int?
    let fetchedAt: Date
    init(fiveHour: QuotaWindow?, week: QuotaWindow?, resetCreditCount: Int? = nil, fetchedAt: Date) {
        self.fiveHour = fiveHour
        self.week = week
        self.resetCreditCount = resetCreditCount
        self.fetchedAt = fetchedAt
    }
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
                             week: windows.first { $0.windowDurationMins == 10080 },
                             resetCreditCount: response.rateLimitResetCredits?.availableCount.map { max(0, $0) },
                             fetchedAt: date)
    }
    func isStale(at date: Date = Date()) -> Bool { date.timeIntervalSince(fetchedAt) > 90 }
}
