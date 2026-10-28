import Foundation

enum WidgetSize: String, CaseIterable { case large, small }
enum SmallLayout: String, CaseIterable { case vertical, horizontal }
enum DisplayScope: String, CaseIterable { case focusCodex, always, focusDesktop }
enum MinimalArcOrder: String, CaseIterable { case fiveHourTop, weekTop }

struct WidgetPreferences: Equatable {
    var size: WidgetSize = .small
    var smallLayout: SmallLayout = .vertical
    var displayScope: DisplayScope = .focusCodex
    var historyRetention: HistoryRetention = .session30Minutes
    var opacityPreset: WidgetOpacityPreset = .opaque
    var densityPreset: WidgetDensityPreset = .standard
    var minimalArcOrder: MinimalArcOrder = .fiveHourTop
    var ringTheme: WidgetRingTheme = .semantic
    var language: AppLanguage = .chinese

    var positionKey: String {
        size == .large ? "large" : "small.\((densityPreset == .minimal ? SmallLayout.vertical : smallLayout).rawValue)"
    }

    func normalizedForDisplay() -> Self {
        var normalized = self
        if normalized.densityPreset == .minimal { normalized.smallLayout = .vertical }
        return normalized
    }

    static func load(from defaults: UserDefaults = .standard) -> Self {
        Self(size: defaults.string(forKey: "widget.size").flatMap(WidgetSize.init(rawValue:)) ?? .small,
             smallLayout: defaults.string(forKey: "widget.smallLayout").flatMap(SmallLayout.init(rawValue:)) ?? .vertical,
             displayScope: defaults.string(forKey: "widget.displayScope").flatMap(DisplayScope.init(rawValue:)) ?? .focusCodex,
             historyRetention: historyRetention(from: defaults.string(forKey: "widget.historyRetention")),
             opacityPreset: defaults.string(forKey: "widget.opacityPreset").flatMap(WidgetOpacityPreset.init(rawValue:)) ?? .opaque,
             densityPreset: defaults.string(forKey: "widget.densityPreset").flatMap(WidgetDensityPreset.init(rawValue:)) ?? .standard,
             minimalArcOrder: defaults.string(forKey: "widget.minimalArcOrder").flatMap(MinimalArcOrder.init(rawValue:)) ?? .fiveHourTop,
             ringTheme: defaults.string(forKey: "widget.ringTheme").flatMap(WidgetRingTheme.init(rawValue:)) ?? .semantic,
             language: defaults.string(forKey: "widget.language").flatMap(AppLanguage.init(rawValue:)) ?? .chinese).normalizedForDisplay()
    }
    func save(to defaults: UserDefaults = .standard) {
        let normalized = normalizedForDisplay()
        defaults.set(normalized.size.rawValue, forKey: "widget.size")
        defaults.set(normalized.smallLayout.rawValue, forKey: "widget.smallLayout")
        defaults.set(normalized.displayScope.rawValue, forKey: "widget.displayScope")
        defaults.set(normalized.historyRetention.rawValue, forKey: "widget.historyRetention")
        defaults.set(normalized.opacityPreset.rawValue, forKey: "widget.opacityPreset")
        defaults.set(normalized.densityPreset.rawValue, forKey: "widget.densityPreset")
        defaults.set(normalized.minimalArcOrder.rawValue, forKey: "widget.minimalArcOrder")
        defaults.set(normalized.ringTheme.rawValue, forKey: "widget.ringTheme")
        defaults.set(normalized.language.rawValue, forKey: "widget.language")
        defaults.removeObject(forKey: "widget.starTrailEnabled")
        defaults.removeObject(forKey: "widget.resetCelebrationEnabled")
    }

    private static func historyRetention(from rawValue: String?) -> HistoryRetention {
        switch rawValue {
        case HistoryRetention.local5Hours.rawValue, "local24Hours", "local7Days": return .local5Hours
        case HistoryRetention.session30Minutes.rawValue: return .session30Minutes
        default: return .session30Minutes
        }
    }
}
