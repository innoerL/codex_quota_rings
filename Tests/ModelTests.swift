import Foundation

@main struct ModelTests {
    static func main() throws {
        var checks = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fputs("FAIL: \(message)\n", stderr); exit(1) }
            checks += 1
        }
        func parse(_ text: String) throws -> QuotaSnapshot {
            try QuotaSnapshot.decode(Data(text.utf8), at: Date(timeIntervalSince1970: 1000))
        }
        let normal = try parse(#"{"rateLimits":{"primary":{"usedPercent":80,"windowDurationMins":300},"secondary":{"usedPercent":76,"windowDurationMins":10080}}}"#)
        expect(normal.fiveHour?.remainingPercent == 20, "80% used means 20% remaining")
        expect(normal.week?.remainingPercent == 24, "weekly quota is independent")
        expect(normal.fiveHour?.level == .caution, "20% remaining is yellow")
        expect(QuotaWindow(usedPercent: 49, windowDurationMins: 300, resetsAt: nil).level == .ample, "51% remaining is green")
        expect(QuotaWindow(usedPercent: 50, windowDurationMins: 300, resetsAt: nil).level == .caution, "50% remaining is yellow")
        expect(QuotaWindow(usedPercent: 81, windowDurationMins: 300, resetsAt: nil).level == .low, "19% remaining is red")
        expect(QuotaWindow(usedPercent: nil, windowDurationMins: 300, resetsAt: nil).level == .unknown, "unknown usage has no health color")
        expect(QuotaWindow.resetCountdown(seconds: 8760) == "2 小时 26 分钟后重置", "reset countdown contains hours and minutes")
        expect(QuotaWindow.resetCountdown(seconds: 295200) == "3 天 10 小时后重置", "multi-day countdown matches reference")
        expect(QuotaWindow.resetCountdown(seconds: 0) == "等待重置", "expired time never pretends quota reset")
        expect(QuotaWindow.resetCountdown(seconds: 35) == "不到 1 分钟后重置", "sub-minute countdown is clear")
        let mapped = try parse(#"{"rateLimits":{"primary":{"usedPercent":5,"windowDurationMins":300}},"rateLimitsByLimitId":{"codex":{"secondary":{"usedPercent":42,"windowDurationMins":300},"primary":{"usedPercent":60,"windowDurationMins":10080}}}}"#)
        expect(mapped.fiveHour?.remainingPercent == 58, "Codex map takes priority; match duration rather than primary slot")
        expect(mapped.week?.remainingPercent == 40, "swapped weekly window remains correct")
        let missing = try parse(#"{"rateLimits":{"primary":{"usedPercent":null,"windowDurationMins":300},"secondary":null}}"#)
        expect(missing.fiveHour?.remainingPercent == nil && missing.week == nil, "missing values must never display full quota")
        let other = try parse(#"{"rateLimitsByLimitId":{"other":{"primary":{"usedPercent":1,"windowDurationMins":300}}},"rateLimits":{"primary":{"usedPercent":1,"windowDurationMins":300}}}"#)
        expect(other.fiveHour == nil, "never show another product's quota")
        let bounds = try parse(#"{"rateLimits":{"primary":{"usedPercent":110,"windowDurationMins":300},"secondary":{"usedPercent":0,"windowDurationMins":10080}}}"#)
        expect(bounds.fiveHour?.remainingPercent == 0, "exhausted quota clamps at zero")
        expect(bounds.week?.remainingPercent == 100, "a real zero usage remains valid")
        expect(normal.isStale(at: Date(timeIntervalSince1970: 1091)), "old values are stale")
        expect(!normal.isStale(at: Date(timeIntervalSince1970: 1030)), "recent values remain current")
        let short = try parse(#"{"rateLimits":{"primary":{"usedPercent":50,"windowDurationMins":15}}}"#)
        expect(short.fiveHour == nil, "a 15 minute window must not be labelled 5 hours")
        do {
            _ = try parse(#"{"rateLimits":{"primary":{"usedPercent":true,"windowDurationMins":300}}}"#)
            expect(false, "boolean usage is malformed")
        } catch { checks += 1 }
        print("PASS: \(checks) quota checks")
    }
}
