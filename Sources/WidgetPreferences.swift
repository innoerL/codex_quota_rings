import Foundation

enum WidgetSize: String, CaseIterable { case large, small }
enum SmallLayout: String, CaseIterable { case vertical, horizontal }
enum DisplayScope: String, CaseIterable { case focusCodex, always, focusDesktop }
enum QuotaBudget: String, CaseIterable {
    case off, reserve10, reserve20, reserve30
    var reservedPercent: Double? {
        switch self { case .off: return nil; case .reserve10: return 10; case .reserve20: return 20; case .reserve30: return 30 }
    }
    var chineseLabel: String {
        switch self { case .off: return "关闭"; case .reserve10: return "保留 10%"; case .reserve20: return "保留 20%"; case .reserve30: return "保留 30%" }
    }
}

struct WidgetPreferences: Equatable {
    var size: WidgetSize = .small
    var smallLayout: SmallLayout = .vertical
    var displayScope: DisplayScope = .focusCodex
    var historyRetention: HistoryRetention = .session30Minutes
    var opacityPreset: WidgetOpacityPreset = .opaque
    var densityPreset: WidgetDensityPreset = .standard
    var ringTheme: WidgetRingTheme = .semantic
    var budget: QuotaBudget = .reserve20

    var positionKey: String { size == .large ? "large" : "small.\(smallLayout.rawValue)" }

    static func load(from defaults: UserDefaults = .standard) -> Self {
        Self(size: defaults.string(forKey: "widget.size").flatMap(WidgetSize.init(rawValue:)) ?? .small,
             smallLayout: defaults.string(forKey: "widget.smallLayout").flatMap(SmallLayout.init(rawValue:)) ?? .vertical,
             displayScope: defaults.string(forKey: "widget.displayScope").flatMap(DisplayScope.init(rawValue:)) ?? .focusCodex,
             historyRetention: historyRetention(from: defaults.string(forKey: "widget.historyRetention")),
             opacityPreset: defaults.string(forKey: "widget.opacityPreset").flatMap(WidgetOpacityPreset.init(rawValue:)) ?? .opaque,
             densityPreset: defaults.string(forKey: "widget.densityPreset").flatMap(WidgetDensityPreset.init(rawValue:)) ?? .standard,
             ringTheme: defaults.string(forKey: "widget.ringTheme").flatMap(WidgetRingTheme.init(rawValue:)) ?? .semantic,
             budget: defaults.string(forKey: "widget.budget").flatMap(QuotaBudget.init(rawValue:)) ?? .reserve20)
    }
    func save(to defaults: UserDefaults = .standard) {
        defaults.set(size.rawValue, forKey: "widget.size")
        defaults.set(smallLayout.rawValue, forKey: "widget.smallLayout")
        defaults.set(displayScope.rawValue, forKey: "widget.displayScope")
        defaults.set(historyRetention.rawValue, forKey: "widget.historyRetention")
        defaults.set(opacityPreset.rawValue, forKey: "widget.opacityPreset")
        defaults.set(densityPreset.rawValue, forKey: "widget.densityPreset")
        defaults.set(ringTheme.rawValue, forKey: "widget.ringTheme")
        defaults.set(budget.rawValue, forKey: "widget.budget")
    }

    private static func historyRetention(from rawValue: String?) -> HistoryRetention {
        switch rawValue {
        case HistoryRetention.local5Hours.rawValue, "local24Hours", "local7Days": return .local5Hours
        case HistoryRetention.session30Minutes.rawValue: return .session30Minutes
        default: return .session30Minutes
        }
    }
}
