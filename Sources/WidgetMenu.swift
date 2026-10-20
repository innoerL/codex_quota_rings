import AppKit

final class WidgetMenu: NSObject {
    var preferences: WidgetPreferences
    var onChange: ((WidgetPreferences) -> Void)?
    private enum Choice { case size(WidgetSize), layout(SmallLayout), scope(DisplayScope), opacity(WidgetOpacityPreset), density(WidgetDensityPreset), theme(WidgetRingTheme), history(HistoryRetention), budget(QuotaBudget) }
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
        group("透明度", choices: [("不透明", .opacity(.opaque), preferences.opacityPreset == .opaque), ("半透明", .opacity(.translucent), preferences.opacityPreset == .translucent), ("轻透", .opacity(.light), preferences.opacityPreset == .light)])
        group("紧凑度", choices: [("标准", .density(.standard), preferences.densityPreset == .standard), ("紧凑", .density(.compact), preferences.densityPreset == .compact), ("极简", .density(.minimal), preferences.densityPreset == .minimal)])
        group("环形配色", choices: [("额度状态", .theme(.semantic), preferences.ringTheme == .semantic), ("石墨", .theme(.graphite), preferences.ringTheme == .graphite), ("暖色", .theme(.warm), preferences.ringTheme == .warm), ("系统强调色", .theme(.systemAccent), preferences.ringTheme == .systemAccent)])
        group("趋势记录", choices: [("仅本次 · 30 分钟", .history(.session30Minutes), preferences.historyRetention == .session30Minutes), ("保留 5 小时", .history(.local5Hours), preferences.historyRetention == .local5Hours)])
        group("额度预算线", choices: QuotaBudget.allCases.map { ($0.chineseLabel, .budget($0), preferences.budget == $0) })
        return menu
    }
    @objc private func selectChoice(_ sender: NSMenuItem) {
        guard let choice = sender.representedObject as? Choice else { return }
        switch choice {
        case .size(let size): preferences.size = size
        case .layout(let layout): guard preferences.size == .small else { return }; preferences.smallLayout = layout
        case .scope(let scope): preferences.displayScope = scope
        case .opacity(let opacity): preferences.opacityPreset = opacity
        case .density(let density): preferences.densityPreset = density
        case .theme(let theme): preferences.ringTheme = theme
        case .history(let retention): preferences.historyRetention = retention
        case .budget(let budget): preferences.budget = budget
        }
        onChange?(preferences)
    }
}
