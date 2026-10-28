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
    func weeklyPace(at date: Date = Date()) -> WeeklyUsagePace? {
        guard windowDurationMins == 10_080,
              let used = clampedUsedPercent,
              let resetsAt, resetsAt.isFinite else { return nil }
        let duration = TimeInterval(10_080 * 60)
        let remaining = resetsAt - date.timeIntervalSince1970
        guard remaining > 0, remaining <= duration else { return nil }
        return WeeklyUsagePace(usedPercent: used, elapsedPercent: (1 - remaining / duration) * 100)
    }
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

struct QuotaDisplayTransition {
    static let duration: TimeInterval = 0.28
    let fromUsedPercent: Double
    let toUsedPercent: Double
    let startedAt: Date

    static func make(from previous: QuotaWindow?, to current: QuotaWindow?,
                     displayedUsedPercent: Double?, at date: Date) -> Self? {
        guard let previous, let current,
              let oldUsed = previous.clampedUsedPercent,
              let newUsed = current.clampedUsedPercent,
              let displayedUsedPercent,
              newUsed + 0.25 >= oldUsed,
              abs(newUsed - displayedUsedPercent) >= 0.1 else { return nil }
        switch (previous.resetsAt, current.resetsAt) {
        case (nil, nil): break
        case let (old?, new?) where old.isFinite && new.isFinite && abs(old - new) <= 0.5: break
        default: return nil
        }
        return Self(fromUsedPercent: displayedUsedPercent, toUsedPercent: newUsed, startedAt: date)
    }

    func usedPercent(at date: Date) -> Double {
        let progress = min(1, max(0, date.timeIntervalSince(startedAt) / Self.duration))
        let eased = progress * progress * (3 - 2 * progress)
        return fromUsedPercent + (toUsedPercent - fromUsedPercent) * eased
    }

    func isActive(at date: Date) -> Bool { date.timeIntervalSince(startedAt) < Self.duration }
}

struct WeeklyUsagePace {
    enum State { case ahead, balanced, below }
    let usedPercent: Double
    let elapsedPercent: Double
    var state: State {
        let difference = usedPercent - elapsedPercent
        if difference > 10 { return .ahead }
        if difference < -10 { return .below }
        return .balanced
    }
    var localizedLabel: String {
        let used = Int(usedPercent.rounded()), elapsed = Int(elapsedPercent.rounded())
        let stateLabel: String
        switch state {
        case .ahead: stateLabel = localized("偏快", "fast")
        case .balanced: stateLabel = localized("平稳", "on pace")
        case .below: stateLabel = localized("偏慢", "slow")
        }
        return localized("周节奏：已用 \(used)% / 已过 \(elapsed)% · \(stateLabel)",
                         "Week: \(used)% used / \(elapsed)% elapsed · \(stateLabel)")
    }
}

private struct QuotaBucket: Decodable {
    let limitId: String?
    let planType: String?
    let primary: QuotaWindow?
    let secondary: QuotaWindow?
}
private struct QuotaResetCredit: Decodable {
    let status: String?
    let expiresAt: Double?
}
private struct QuotaResetCredits: Decodable {
    let availableCount: Int?
    let credits: [QuotaResetCredit]?
}
private struct QuotaResponse: Decodable {
    let rateLimits: QuotaBucket?
    let rateLimitsByLimitId: [String: QuotaBucket]?
    let rateLimitResetCredits: QuotaResetCredits?
}

struct QuotaSnapshot {
    let fiveHour: QuotaWindow?
    let week: QuotaWindow?
    /// 本机 Codex app-server 返回的可用一次性额度重置次数。
    let resetCreditCount: Int?
    let earliestResetCreditExpiration: Date?
    let planName: String?
    let fetchedAt: Date
    init(fiveHour: QuotaWindow?, week: QuotaWindow?, resetCreditCount: Int? = nil,
         earliestResetCreditExpiration: Date? = nil, planName: String? = nil, fetchedAt: Date) {
        self.fiveHour = fiveHour
        self.week = week
        self.resetCreditCount = resetCreditCount
        self.earliestResetCreditExpiration = earliestResetCreditExpiration
        self.planName = planName
        self.fetchedAt = fetchedAt
    }
    var planDescription: String {
        localized("当前套餐：\(planName ?? "暂不可用")", "Current plan: \(planName ?? "unavailable")")
    }
    var resetCreditDescription: String? {
        guard let resetCreditCount else { return nil }
        let count = localized("可用重置卡 × \(resetCreditCount)", "Reset cards available × \(resetCreditCount)")
        guard resetCreditCount > 0 else { return count }
        guard let earliestResetCreditExpiration else {
            return count + localized(" · 未提供到期时间", " · expiration unavailable")
        }
        let format = DateFormatter(); format.dateFormat = "M/d HH:mm"
        return count + localized(" · 最早到期 \(format.string(from: earliestResetCreditExpiration))",
                                 " · earliest expiry \(format.string(from: earliestResetCreditExpiration))")
    }
    var resetCreditCompactDescription: String? {
        guard let resetCreditCount else { return nil }
        let count = localized("重置卡 × \(resetCreditCount)", "Cards × \(resetCreditCount)")
        guard resetCreditCount > 0 else { return count }
        guard let earliestResetCreditExpiration else {
            return count + localized(" · 到期时间未提供", " · no expiry data")
        }
        let format = DateFormatter(); format.dateFormat = "M/d HH:mm"
        return count + localized(" · 最近到期 \(format.string(from: earliestResetCreditExpiration))",
                                 " · earliest \(format.string(from: earliestResetCreditExpiration))")
    }
    private static func displayPlanName(_ value: String?) -> String? {
        guard let value, value != "unknown" else { return nil }
        switch value {
        case "free": return "Free"
        case "go": return "Go"
        case "plus": return "Plus"
        case "pro": return "Pro"
        case "prolite": return "Pro Lite"
        case "promax": return "Pro Max"
        case "team": return "Team"
        case "business", "self_serve_business_prolite", "self_serve_business_usage_based": return "Business"
        case "enterprise", "ent26", "enterprise_cbp_automation", "enterprise_cbp_usage_based": return "Enterprise"
        case "edu", "edu_plus", "edu_pro": return "Edu"
        case "sci", "sci_plus": return "Sci"
        default: return nil
        }
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
        let resetCredits = response.rateLimitResetCredits
        let expiry = resetCredits?.credits?.compactMap { credit -> Date? in
            guard credit.status == "available", let timestamp = credit.expiresAt,
                  timestamp.isFinite, timestamp > date.timeIntervalSince1970 else { return nil }
            return Date(timeIntervalSince1970: timestamp)
        }.min()
        return QuotaSnapshot(fiveHour: windows.first { $0.windowDurationMins == 300 },
                             week: windows.first { $0.windowDurationMins == 10080 },
                             resetCreditCount: resetCredits?.availableCount.map { max(0, $0) },
                             earliestResetCreditExpiration: expiry,
                             planName: displayPlanName(bucket?.planType),
                             fetchedAt: date)
    }
    func isStale(at date: Date = Date()) -> Bool { date.timeIntervalSince(fetchedAt) > 90 }
}
