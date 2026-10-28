import Foundation

@main struct WidgetPreferencesTests {
    static func main() {
        let suite = "quota-rings-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var p = WidgetPreferences.load(from: defaults)
        precondition(p.size == .small && p.smallLayout == .vertical && p.displayScope == .focusCodex
                     && p.historyRetention == .session30Minutes
                     && p.opacityPreset == .opaque && p.densityPreset == .standard && p.ringTheme == .semantic && p.language == .chinese
                     && p.minimalArcOrder == .fiveHourTop)
        p.smallLayout = .horizontal; p.displayScope = .focusDesktop; p.size = .large
        p.historyRetention = .local5Hours
        p.opacityPreset = .light; p.densityPreset = .minimal; p.minimalArcOrder = .weekTop; p.ringTheme = .warm
        p.language = .english
        p = p.normalizedForDisplay()
        p.save(to: defaults)
        let restored = WidgetPreferences.load(from: defaults)
        precondition(restored == p)
        precondition(restored.minimalArcOrder == .weekTop,
                     "极简弧线顺序应持久保存")
        precondition(restored.smallLayout == .vertical,
                     "minimal density must normalize the saved orientation for the single ring")
        p.densityPreset = .standard; p.smallLayout = .horizontal; p.size = .small
        precondition(p.smallLayout == .horizontal && p.displayScope == .focusDesktop)
        for scope in DisplayScope.allCases {
            p.displayScope = scope; p.save(to: defaults)
            precondition(WidgetPreferences.load(from: defaults) == p)
        }
        for retention in HistoryRetention.allCases {
            p.historyRetention = retention; p.save(to: defaults)
            precondition(WidgetPreferences.load(from: defaults) == p)
        }
        for theme in WidgetRingTheme.allCases {
            p.ringTheme = theme; p.save(to: defaults)
            precondition(WidgetPreferences.load(from: defaults) == p)
        }
        for language in AppLanguage.allCases {
            p.language = language; p.save(to: defaults)
            precondition(WidgetPreferences.load(from: defaults) == p)
        }
        defaults.set("invalid", forKey: "widget.size")
        defaults.set("invalid", forKey: "widget.displayScope")
        defaults.set("invalid", forKey: "widget.historyRetention")
        defaults.set("invalid", forKey: "widget.opacityPreset")
        defaults.set("invalid", forKey: "widget.densityPreset")
        defaults.set("invalid", forKey: "widget.minimalArcOrder")
        defaults.set("invalid", forKey: "widget.ringTheme")
        defaults.set("invalid", forKey: "widget.language")
        defaults.set(false, forKey: "widget.starTrailEnabled")
        defaults.set(false, forKey: "widget.resetCelebrationEnabled")
        let repaired = WidgetPreferences.load(from: defaults)
        precondition(repaired.size == .small && repaired.displayScope == .focusCodex
                     && repaired.historyRetention == .session30Minutes
                     && repaired.opacityPreset == .opaque && repaired.densityPreset == .standard && repaired.ringTheme == .semantic && repaired.language == .chinese
                     && repaired.minimalArcOrder == .fiveHourTop)
        repaired.save(to: defaults)
        precondition(defaults.object(forKey: "widget.starTrailEnabled") == nil
                     && defaults.object(forKey: "widget.resetCelebrationEnabled") == nil,
                     "保存新设置时应清理已移除的动画选项")
        precondition(repaired.smallLayout == .horizontal)
        defaults.set("local24Hours", forKey: "widget.historyRetention")
        precondition(WidgetPreferences.load(from: defaults).historyRetention == .local5Hours,
                     "legacy persistent preferences must migrate to the five-hour option")
        defaults.set("local7Days", forKey: "widget.historyRetention")
        precondition(WidgetPreferences.load(from: defaults).historyRetention == .local5Hours,
                     "legacy long-history preferences must migrate to the five-hour option")
        defaults.set("compact", forKey: "widget.densityPreset")
        precondition(WidgetPreferences.load(from: defaults).densityPreset == .standard,
                     "旧紧凑模式应迁移到标准模式")
        defaults.set(WidgetDensityPreset.minimal.rawValue, forKey: "widget.densityPreset")
        defaults.set(SmallLayout.horizontal.rawValue, forKey: "widget.smallLayout")
        precondition(WidgetPreferences.load(from: defaults).smallLayout == .vertical,
                     "minimal density must migrate prior horizontal layouts to the single ring")
        print("PASS: preference defaults, round trips, independence and invalid-value recovery")
    }
}
