import AppKit

final class WidgetMenu: NSObject {
    var preferences: WidgetPreferences
    var onChange: ((WidgetPreferences) -> Void)?
    private enum Choice { case size(WidgetSize), layout(SmallLayout), scope(DisplayScope), history(HistoryRetention) }
    init(preferences: WidgetPreferences) { self.preferences = preferences }

    func makeMenu() -> NSMenu {
        let menu = NSMenu(); menu.autoenablesItems = false
        func group(_ title: String, choices: [(String, Choice, Bool)], enabled: Bool = true) {
            let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let submenu = NSMenu(); submenu.autoenablesItems = false
            for (name, choice, selected) in choices {
                let item = NSMenuItem(title: name, action: #selector(selectChoice(_:)), keyEquivalent: "")
                item.target = self; item.representedObject = choice; item.state = selected ? .on : .off
                submenu.addItem(item)
            }
            parent.submenu = submenu; parent.isEnabled = enabled; menu.addItem(parent)
        }
        group("大小", choices: [("大", .size(.large), preferences.size == .large), ("小", .size(.small), preferences.size == .small)])
        group("小组件布局", choices: [("竖向", .layout(.vertical), preferences.smallLayout == .vertical), ("横向", .layout(.horizontal), preferences.smallLayout == .horizontal)], enabled: preferences.size == .small)
        group("显示范围", choices: [("聚焦 Codex 时显示", .scope(.focusCodex), preferences.displayScope == .focusCodex), ("一直显示", .scope(.always), preferences.displayScope == .always), ("聚焦桌面时显示", .scope(.focusDesktop), preferences.displayScope == .focusDesktop)])
        group("趋势记录", choices: [("仅本次 · 30 分钟", .history(.session30Minutes), preferences.historyRetention == .session30Minutes), ("保留 24 小时", .history(.local24Hours), preferences.historyRetention == .local24Hours), ("保留 7 天", .history(.local7Days), preferences.historyRetention == .local7Days)])
        return menu
    }
    @objc private func selectChoice(_ sender: NSMenuItem) {
        guard let choice = sender.representedObject as? Choice else { return }
        switch choice {
        case .size(let size): preferences.size = size
        case .layout(let layout): guard preferences.size == .small else { return }; preferences.smallLayout = layout
        case .scope(let scope): preferences.displayScope = scope
        case .history(let retention): preferences.historyRetention = retention
        }
        onChange?(preferences)
    }
}
