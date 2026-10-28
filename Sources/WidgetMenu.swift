import AppKit

final class WidgetMenu: NSObject {
    var preferences: WidgetPreferences
    var onChange: ((WidgetPreferences) -> Void)?
    private enum Choice { case size(WidgetSize), layout(SmallLayout), scope(DisplayScope), opacity(WidgetOpacityPreset), density(WidgetDensityPreset), arcOrder(MinimalArcOrder), theme(WidgetRingTheme), history(HistoryRetention), language(AppLanguage) }
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
        group(localized("大小", "Size"), choices: [(localized("大", "Large"), .size(.large), preferences.size == .large), (localized("小", "Small"), .size(.small), preferences.size == .small)])
        let minimalLayout = preferences.densityPreset == .minimal
        group(minimalLayout ? localized("小组件布局（极简单圆）", "Small layout (Minimal uses one ring)") : localized("小组件布局", "Small layout"), choices: [(localized("竖向", "Vertical"), .layout(.vertical), preferences.smallLayout == .vertical), (localized("横向", "Horizontal"), .layout(.horizontal), preferences.smallLayout == .horizontal)], enabled: preferences.size == .small && !minimalLayout)
        group(localized("显示范围", "Visibility"), choices: [(localized("聚焦 Codex 时显示", "Show with Codex"), .scope(.focusCodex), preferences.displayScope == .focusCodex), (localized("一直显示", "Always show"), .scope(.always), preferences.displayScope == .always), (localized("聚焦桌面时显示", "Show on desktop"), .scope(.focusDesktop), preferences.displayScope == .focusDesktop)])
        group(localized("透明度", "Opacity"), choices: [(localized("不透明", "Opaque"), .opacity(.opaque), preferences.opacityPreset == .opaque), (localized("半透明", "Translucent"), .opacity(.translucent), preferences.opacityPreset == .translucent), (localized("轻透", "Light"), .opacity(.light), preferences.opacityPreset == .light)])
        group(localized("模式", "Mode"), choices: [(localized("标准", "Standard"), .density(.standard), preferences.densityPreset == .standard), (localized("极简", "Minimal"), .density(.minimal), preferences.densityPreset == .minimal)])
        group(localized("极简弧线顺序", "Minimal arc order"), choices: [(localized("上方 5 小时 · 下方一周", "5 hours above · week below"), .arcOrder(.fiveHourTop), preferences.minimalArcOrder == .fiveHourTop), (localized("上方一周 · 下方 5 小时", "Week above · 5 hours below"), .arcOrder(.weekTop), preferences.minimalArcOrder == .weekTop)], enabled: preferences.size == .small && minimalLayout)
        group(localized("环形配色", "Ring colors"), choices: [(localized("额度状态", "Quota status"), .theme(.semantic), preferences.ringTheme == .semantic), (localized("石墨", "Graphite"), .theme(.graphite), preferences.ringTheme == .graphite), (localized("暖色", "Warm"), .theme(.warm), preferences.ringTheme == .warm), (localized("系统强调色", "System accent"), .theme(.systemAccent), preferences.ringTheme == .systemAccent)])
        group(localized("趋势记录", "Trend history"), choices: [(localized("仅本次 · 30 分钟", "Session only · 30 min"), .history(.session30Minutes), preferences.historyRetention == .session30Minutes), (localized("保留 5 小时", "Keep 5 hours"), .history(.local5Hours), preferences.historyRetention == .local5Hours)])
        group(localized("界面语言", "Language"), choices: AppLanguage.allCases.map { ($0.menuLabel, .language($0), preferences.language == $0) })
        return menu
    }
    @objc private func selectChoice(_ sender: NSMenuItem) {
        guard let choice = sender.representedObject as? Choice else { return }
        switch choice {
        case .size(let size): preferences.size = size
        case .layout(let layout): guard preferences.size == .small else { return }; preferences.smallLayout = layout
        case .scope(let scope): preferences.displayScope = scope
        case .opacity(let opacity): preferences.opacityPreset = opacity
        case .density(let density):
            preferences.densityPreset = density
            if density == .minimal { preferences.smallLayout = .vertical }
        case .arcOrder(let order): preferences.minimalArcOrder = order
        case .theme(let theme): preferences.ringTheme = theme
        case .history(let retention): preferences.historyRetention = retention
        case .language(let language): preferences.language = language
        }
        onChange?(preferences)
    }
}
