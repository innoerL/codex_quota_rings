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
        let normal = try parse(#"{"rateLimits":{"primary":{"usedPercent":80,"windowDurationMins":300},"secondary":{"usedPercent":76,"windowDurationMins":10080}},"rateLimitResetCredits":{"availableCount":2}}"#)
        expect(normal.fiveHour?.remainingPercent == 20, "80% used means 20% remaining")
        expect(normal.week?.remainingPercent == 24, "weekly quota is independent")
        expect(normal.resetCreditCount == 2, "available reset credits are decoded from the Codex rate limit response")
        expect(normal.earliestResetCreditExpiration == nil && normal.resetCreditDescription?.contains("未提供到期时间") == true,
               "只有重置卡总数时不得推测到期日期")
        let detailed = try parse(#"{"rateLimitsByLimitId":{"codex":{"planType":"prolite","primary":{"usedPercent":20,"windowDurationMins":300}}},"rateLimitResetCredits":{"availableCount":3,"credits":[{"status":"available","expiresAt":3000},{"status":"redeemed","expiresAt":1200},{"status":"available","expiresAt":2000},{"status":"available","expiresAt":900},{"status":"available","expiresAt":null}]}}"#)
        expect(detailed.planName == "Pro Lite" && detailed.planDescription == "当前套餐：Pro Lite",
               "从 Codex 额度桶读取当前套餐")
        expect(detailed.earliestResetCreditExpiration == Date(timeIntervalSince1970: 2000)
               && detailed.resetCreditDescription?.contains("最早到期") == true,
               "只选可用且尚未到期的重置卡，按最早到期展示")
        let unknownPlan = try parse(#"{"rateLimits":{"planType":"unknown","primary":{"usedPercent":20,"windowDurationMins":300}},"rateLimitResetCredits":{"availableCount":0,"credits":[]}}"#)
        expect(unknownPlan.planName == nil && unknownPlan.planDescription == "当前套餐：暂不可用"
               && unknownPlan.resetCreditDescription == "可用重置卡 × 0",
               "未知套餐和零张重置卡保持明确状态")
        expect(normal.fiveHour?.level == .caution, "20% remaining is terracotta")
        expect(QuotaWindow(usedPercent: 35, windowDurationMins: 300, resetsAt: nil).level == .ample, "65% remaining is sage green")
        expect(QuotaWindow(usedPercent: 36, windowDurationMins: 300, resetsAt: nil).level == .steady, "64% remaining is warm gold")
        expect(QuotaWindow(usedPercent: 70, windowDurationMins: 300, resetsAt: nil).level == .steady, "30% remaining remains warm gold")
        expect(QuotaWindow(usedPercent: 71, windowDurationMins: 300, resetsAt: nil).level == .caution, "29% remaining is terracotta")
        expect(QuotaWindow(usedPercent: 90, windowDurationMins: 300, resetsAt: nil).level == .caution, "10% remaining remains terracotta")
        expect(QuotaWindow(usedPercent: 91, windowDurationMins: 300, resetsAt: nil).level == .low, "9% remaining is deep berry red")
        expect(QuotaWindow(usedPercent: nil, windowDurationMins: 300, resetsAt: nil).level == .unknown, "unknown usage has no health color")
        expect(QuotaWindow.resetCountdown(seconds: 8760) == "2 小时 26 分钟后重置", "reset countdown contains hours and minutes")
        expect(QuotaWindow.resetCountdown(seconds: 295200) == "3 天 10 小时后重置", "multi-day countdown matches reference")
        expect(QuotaWindow.resetCountdown(seconds: 0) == "等待重置", "expired time never pretends quota reset")
        expect(QuotaWindow.resetCountdown(seconds: 35) == "不到 1 分钟后重置", "sub-minute countdown is clear")
        AppLanguageManager.current = .english
        expect(QuotaWindow.resetCountdown(seconds: 35) == "Resets in under 1 minute", "English language setting changes reset copy")
        AppLanguageManager.current = .chinese
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
        let negativeCredits = try parse(#"{"rateLimits":{"primary":{"usedPercent":10,"windowDurationMins":300}},"rateLimitResetCredits":{"availableCount":-2}}"#)
        expect(negativeCredits.resetCreditCount == 0, "invalid negative reset credits clamp to zero")
        expect(normal.isStale(at: Date(timeIntervalSince1970: 1091)), "old values are stale")
        expect(!normal.isStale(at: Date(timeIntervalSince1970: 1030)), "recent values remain current")
        let transitionNow = Date(timeIntervalSince1970: 1_700_000_000)
        let oldWindow = QuotaWindow(usedPercent: 32, windowDurationMins: 300, resetsAt: 1_700_010_000)
        let updatedWindow = QuotaWindow(usedPercent: 48, windowDurationMins: 300, resetsAt: 1_700_010_000)
        let transition = QuotaDisplayTransition.make(from: oldWindow, to: updatedWindow,
                                                       displayedUsedPercent: 32, at: transitionNow)
        expect(transition != nil, "额度增加时应创建平滑过渡")
        if let transition {
            expect(transition.usedPercent(at: transitionNow) == 32, "动画从当前显示值开始")
            expect(abs(transition.usedPercent(at: transitionNow.addingTimeInterval(0.14)) - 40) < 0.001,
                   "动画中点使用平滑插值")
            expect(transition.usedPercent(at: transitionNow.addingTimeInterval(1)) == 48,
                   "动画结束后显示完整新读数")
            expect(!transition.isActive(at: transitionNow.addingTimeInterval(1)), "动画按时结束")
        }
        let interrupted = QuotaDisplayTransition.make(from: updatedWindow,
                                                        to: QuotaWindow(usedPercent: 56, windowDurationMins: 300,
                                                                        resetsAt: updatedWindow.resetsAt),
                                                        displayedUsedPercent: 40, at: transitionNow)
        expect(interrupted?.fromUsedPercent == 40, "连续刷新从当前可见值继续，不跳回旧目标")
        expect(QuotaDisplayTransition.make(from: oldWindow,
                                            to: QuotaWindow(usedPercent: 12, windowDurationMins: 300,
                                                            resetsAt: oldWindow.resetsAt),
                                            displayedUsedPercent: 32, at: transitionNow) == nil,
               "用量大幅下降时不播放普通消耗动画")
        expect(QuotaDisplayTransition.make(from: oldWindow,
                                            to: QuotaWindow(usedPercent: 48, windowDurationMins: 300,
                                                            resetsAt: 1_700_020_000),
                                            displayedUsedPercent: 32, at: transitionNow) == nil,
               "重置时间变化时直接显示新读数")
        expect(QuotaDisplayTransition.make(from: oldWindow, to: updatedWindow,
                                            displayedUsedPercent: nil, at: transitionNow) == nil,
               "缺少可见旧读数时直接显示新读数")
        let paceNow = Date(timeIntervalSince1970: 1_700_000_000)
        let halfWeekReset = paceNow.addingTimeInterval(3.5 * 24 * 3_600).timeIntervalSince1970
        func weeklyPace(_ used: Double?, reset: Double? = halfWeekReset, duration: Int = 10_080) -> WeeklyUsagePace? {
            QuotaWindow(usedPercent: used, windowDurationMins: duration, resetsAt: reset).weeklyPace(at: paceNow)
        }
        expect(weeklyPace(65)?.state == .ahead, "weekly usage more than ten points ahead of elapsed time is fast")
        expect(weeklyPace(50)?.state == .balanced, "weekly usage matching elapsed time is on pace")
        expect(weeklyPace(30)?.state == .below, "weekly usage behind elapsed time is slow")
        expect(weeklyPace(50)?.localizedLabel.contains("已用 50% / 已过 50%") == true,
               "weekly pace explains the comparison behind its status")
        expect(weeklyPace(nil) == nil && weeklyPace(50, reset: nil) == nil,
               "missing quota or reset data cannot establish weekly pace")
        expect(weeklyPace(50, reset: paceNow.timeIntervalSince1970 - 1) == nil
               && weeklyPace(50, reset: paceNow.timeIntervalSince1970 + 8 * 24 * 3_600) == nil
               && weeklyPace(50, duration: 300) == nil,
               "expired, implausible, or nonweekly windows cannot establish weekly pace")
        let short = try parse(#"{"rateLimits":{"primary":{"usedPercent":50,"windowDurationMins":15}}}"#)
        expect(short.fiveHour == nil, "a 15 minute window must not be labelled 5 hours")
        do {
            _ = try parse(#"{"rateLimits":{"primary":{"usedPercent":true,"windowDurationMins":300}}}"#)
            expect(false, "boolean usage is malformed")
        } catch { checks += 1 }
        print("PASS: \(checks) quota checks")
    }
}
