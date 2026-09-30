import AppKit

final class WidgetMenu: NSObject {
    var preferences: WidgetPreferences
    var onChange: ((WidgetPreferences) -> Void)?
    private enum Choice { case size(WidgetSize), layout(SmallLayout), scope(DisplayScope) }
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
        return menu
    }
    @objc private func selectChoice(_ sender: NSMenuItem) {
        guard let choice = sender.representedObject as? Choice else { return }
        switch choice {
        case .size(let size): preferences.size = size
        case .layout(let layout): guard preferences.size == .small else { return }; preferences.smallLayout = layout
        case .scope(let scope): preferences.displayScope = scope
        }
        onChange?(preferences)
    }
}
