import Foundation

@main struct WidgetPreferencesTests {
    static func main() {
        let suite = "quota-rings-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var p = WidgetPreferences.load(from: defaults)
        precondition(p.size == .small && p.smallLayout == .vertical && p.displayScope == .focusCodex
                     && p.historyRetention == .session30Minutes
                     && p.opacityPreset == .opaque && p.densityPreset == .standard && p.ringTheme == .semantic)
        p.smallLayout = .horizontal; p.displayScope = .focusDesktop; p.size = .large
        p.historyRetention = .local5Hours
        p.opacityPreset = .light; p.densityPreset = .minimal; p.ringTheme = .warm
        p.save(to: defaults)
        let restored = WidgetPreferences.load(from: defaults)
        precondition(restored == p)
        p.size = .small
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
        defaults.set("invalid", forKey: "widget.size")
        defaults.set("invalid", forKey: "widget.displayScope")
        defaults.set("invalid", forKey: "widget.historyRetention")
        defaults.set("invalid", forKey: "widget.opacityPreset")
        defaults.set("invalid", forKey: "widget.densityPreset")
        defaults.set("invalid", forKey: "widget.ringTheme")
        let repaired = WidgetPreferences.load(from: defaults)
        precondition(repaired.size == .small && repaired.displayScope == .focusCodex
                     && repaired.historyRetention == .session30Minutes
                     && repaired.opacityPreset == .opaque && repaired.densityPreset == .standard && repaired.ringTheme == .semantic)
        precondition(repaired.smallLayout == .horizontal)
        defaults.set("local24Hours", forKey: "widget.historyRetention")
        precondition(WidgetPreferences.load(from: defaults).historyRetention == .local5Hours,
                     "legacy persistent preferences must migrate to the five-hour option")
        defaults.set("local7Days", forKey: "widget.historyRetention")
        precondition(WidgetPreferences.load(from: defaults).historyRetention == .local5Hours,
                     "legacy long-history preferences must migrate to the five-hour option")
        print("PASS: preference defaults, round trips, independence and invalid-value recovery")
    }
}
