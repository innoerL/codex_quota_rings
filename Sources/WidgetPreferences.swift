import Foundation

enum WidgetSize: String, CaseIterable { case large, small }
enum SmallLayout: String, CaseIterable { case vertical, horizontal }
enum DisplayScope: String, CaseIterable { case focusCodex, always, focusDesktop }

struct WidgetPreferences: Equatable {
    var size: WidgetSize = .small
    var smallLayout: SmallLayout = .vertical
    var displayScope: DisplayScope = .focusCodex
    var historyRetention: HistoryRetention = .session30Minutes
    var opacityPreset: WidgetOpacityPreset = .opaque
    var densityPreset: WidgetDensityPreset = .standard
    var ringTheme: WidgetRingTheme = .semantic
    var language: AppLanguage = .chinese
    var starTrailEnabled = true
    var resetCelebrationEnabled = true

    var positionKey: String { size == .large ? "large" : "small.\(smallLayout.rawValue)" }

    static func load(from defaults: UserDefaults = .standard) -> Self {
        Self(size: defaults.string(forKey: "widget.size").flatMap(WidgetSize.init(rawValue:)) ?? .small,
             smallLayout: defaults.string(forKey: "widget.smallLayout").flatMap(SmallLayout.init(rawValue:)) ?? .vertical,
             displayScope: defaults.string(forKey: "widget.displayScope").flatMap(DisplayScope.init(rawValue:)) ?? .focusCodex,
             historyRetention: historyRetention(from: defaults.string(forKey: "widget.historyRetention")),
             opacityPreset: defaults.string(forKey: "widget.opacityPreset").flatMap(WidgetOpacityPreset.init(rawValue:)) ?? .opaque,
             densityPreset: defaults.string(forKey: "widget.densityPreset").flatMap(WidgetDensityPreset.init(rawValue:)) ?? .standard,
             ringTheme: defaults.string(forKey: "widget.ringTheme").flatMap(WidgetRingTheme.init(rawValue:)) ?? .semantic,
             language: defaults.string(forKey: "widget.language").flatMap(AppLanguage.init(rawValue:)) ?? .chinese,
             starTrailEnabled: defaults.object(forKey: "widget.starTrailEnabled") as? Bool ?? true,
             resetCelebrationEnabled: defaults.object(forKey: "widget.resetCelebrationEnabled") as? Bool ?? true)
    }
    func save(to defaults: UserDefaults = .standard) {
        defaults.set(size.rawValue, forKey: "widget.size")
        defaults.set(smallLayout.rawValue, forKey: "widget.smallLayout")
        defaults.set(displayScope.rawValue, forKey: "widget.displayScope")
        defaults.set(historyRetention.rawValue, forKey: "widget.historyRetention")
        defaults.set(opacityPreset.rawValue, forKey: "widget.opacityPreset")
        defaults.set(densityPreset.rawValue, forKey: "widget.densityPreset")
        defaults.set(ringTheme.rawValue, forKey: "widget.ringTheme")
        defaults.set(language.rawValue, forKey: "widget.language")
        defaults.set(starTrailEnabled, forKey: "widget.starTrailEnabled")
        defaults.set(resetCelebrationEnabled, forKey: "widget.resetCelebrationEnabled")
    }

    private static func historyRetention(from rawValue: String?) -> HistoryRetention {
        switch rawValue {
        case HistoryRetention.local5Hours.rawValue, "local24Hours", "local7Days": return .local5Hours
        case HistoryRetention.session30Minutes.rawValue: return .session30Minutes
        default: return .session30Minutes
        }
    }
}
