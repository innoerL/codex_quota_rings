import AppKit

final class WidgetMenu: NSObject {
    var preferences: WidgetPreferences
    var onChange: ((WidgetPreferences) -> Void)?
    private enum Choice { case size(WidgetSize), layout(SmallLayout), scope(DisplayScope), opacity(WidgetOpacityPreset), density(WidgetDensityPreset), theme(WidgetRingTheme), history(HistoryRetention), language(AppLanguage), floatingIsland(Bool), starTrail(Bool), resetCelebration(Bool), mergedRings(Bool) }
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
        group(localized("小组件布局", "Small layout"), choices: [(localized("竖向", "Vertical"), .layout(.vertical), preferences.smallLayout == .vertical), (localized("横向", "Horizontal"), .layout(.horizontal), preferences.smallLayout == .horizontal)], enabled: preferences.size == .small)
        group(localized("悬浮岛模式", "Floating island"), choices: toggleChoices(on: preferences.floatingIslandEnabled, onChoice: .floatingIsland(true), offChoice: .floatingIsland(false)))
        group(localized("显示范围", "Visibility"), choices: [(localized("聚焦 Codex 时显示", "Show with Codex"), .scope(.focusCodex), preferences.displayScope == .focusCodex), (localized("一直显示", "Always show"), .scope(.always), preferences.displayScope == .always), (localized("聚焦桌面时显示", "Show on desktop"), .scope(.focusDesktop), preferences.displayScope == .focusDesktop)])
        group(localized("透明度", "Opacity"), choices: [(localized("不透明", "Opaque"), .opacity(.opaque), preferences.opacityPreset == .opaque), (localized("半透明", "Translucent"), .opacity(.translucent), preferences.opacityPreset == .translucent), (localized("轻透", "Light"), .opacity(.light), preferences.opacityPreset == .light)])
        group(localized("紧凑度", "Density"), choices: [(localized("标准", "Standard"), .density(.standard), preferences.densityPreset == .standard), (localized("紧凑", "Compact"), .density(.compact), preferences.densityPreset == .compact), (localized("极简", "Minimal"), .density(.minimal), preferences.densityPreset == .minimal)])
        group(localized("环形配色", "Ring colors"), choices: [(localized("额度状态", "Quota status"), .theme(.semantic), preferences.ringTheme == .semantic), (localized("石墨", "Graphite"), .theme(.graphite), preferences.ringTheme == .graphite), (localized("暖色", "Warm"), .theme(.warm), preferences.ringTheme == .warm), (localized("系统强调色", "System accent"), .theme(.systemAccent), preferences.ringTheme == .systemAccent)])
        group(localized("趋势记录", "Trend history"), choices: [(localized("仅本次 · 30 分钟", "Session only · 30 min"), .history(.session30Minutes), preferences.historyRetention == .session30Minutes), (localized("保留 5 小时", "Keep 5 hours"), .history(.local5Hours), preferences.historyRetention == .local5Hours)])
        group(localized("界面语言", "Language"), choices: AppLanguage.allCases.map { ($0.menuLabel, .language($0), preferences.language == $0) })
        group(localized("星轨模式", "Star trails"), choices: toggleChoices(on: preferences.starTrailEnabled, onChoice: .starTrail(true), offChoice: .starTrail(false)))
        group(localized("重置庆祝", "Reset celebration"), choices: toggleChoices(on: preferences.resetCelebrationEnabled, onChoice: .resetCelebration(true), offChoice: .resetCelebration(false)))
        group(localized("双环合体", "Concentric rings"), choices: toggleChoices(on: preferences.mergedRingsEnabled, onChoice: .mergedRings(true), offChoice: .mergedRings(false)))
        return menu
    }
    private func toggleChoices(on: Bool, onChoice: Choice, offChoice: Choice) -> [(String, Choice, Bool)] {
        [(localized("开启", "On"), onChoice, on), (localized("关闭", "Off"), offChoice, !on)]
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
        case .language(let language): preferences.language = language
        case .floatingIsland(let enabled): preferences.floatingIslandEnabled = enabled
        case .starTrail(let enabled): preferences.starTrailEnabled = enabled
        case .resetCelebration(let enabled): preferences.resetCelebrationEnabled = enabled
        case .mergedRings(let enabled): preferences.mergedRingsEnabled = enabled
        }
        onChange?(preferences)
    }
}
