import Foundation

enum WidgetSize: String, CaseIterable { case large, small }
enum SmallLayout: String, CaseIterable { case vertical, horizontal }
enum DisplayScope: String, CaseIterable { case focusCodex, always, focusDesktop }

struct WidgetPreferences: Equatable {
    var size: WidgetSize = .small
    var smallLayout: SmallLayout = .vertical
    var displayScope: DisplayScope = .focusCodex

    var positionKey: String { size == .large ? "large" : "small.\(smallLayout.rawValue)" }

    static func load(from defaults: UserDefaults = .standard) -> Self {
        Self(size: defaults.string(forKey: "widget.size").flatMap(WidgetSize.init(rawValue:)) ?? .small,
             smallLayout: defaults.string(forKey: "widget.smallLayout").flatMap(SmallLayout.init(rawValue:)) ?? .vertical,
             displayScope: defaults.string(forKey: "widget.displayScope").flatMap(DisplayScope.init(rawValue:)) ?? .focusCodex)
    }
    func save(to defaults: UserDefaults = .standard) {
        defaults.set(size.rawValue, forKey: "widget.size")
        defaults.set(smallLayout.rawValue, forKey: "widget.smallLayout")
        defaults.set(displayScope.rawValue, forKey: "widget.displayScope")
    }
}
