import AppKit

@main struct MenuTests {
    static func main() {
        _ = NSApplication.shared
        let controller = WidgetMenu(preferences: WidgetPreferences())
        var last: WidgetPreferences?
        controller.onChange = { last = $0 }
        let menu = controller.makeMenu()
        precondition(menu.items.count == 8)
        precondition(menu.items[2].submenu!.items.map(\.title) == ["聚焦 Codex 时显示", "一直显示", "聚焦桌面时显示"])
        precondition(menu.items[2].submenu!.items[0].state == .on)
        precondition(menu.items[3].title == "透明度")
        precondition(menu.items[3].submenu!.items.map(\.title) == ["不透明", "半透明", "轻透"])
        precondition(menu.items[3].submenu!.items[0].state == .on)
        precondition(menu.items[4].title == "紧凑度")
        precondition(menu.items[4].submenu!.items.map(\.title) == ["标准", "紧凑", "极简"])
        precondition(menu.items[4].submenu!.items[0].state == .on)
        precondition(menu.items[5].title == "环形配色")
        precondition(menu.items[5].submenu!.items.map(\.title) == ["额度状态", "石墨", "暖色", "系统强调色"])
        precondition(menu.items[5].submenu!.items[0].state == .on)
        precondition(menu.items[6].title == "趋势记录")
        precondition(menu.items[6].submenu!.items.map(\.title) == ["仅本次 · 30 分钟", "保留 5 小时"])
        precondition(menu.items[6].submenu!.items[0].state == .on)
        precondition(menu.items[7].title == "界面语言")
        precondition(menu.items[7].submenu!.items.map(\.title) == ["中文", "English"])
        precondition(menu.items[7].submenu!.items[0].state == .on)
        let desktop = menu.items[2].submenu!.items[2]
        NSApp.sendAction(desktop.action!, to: desktop.target, from: desktop)
        precondition(last?.displayScope == .focusDesktop && last?.size == .small)
        let large = controller.makeMenu().items[0].submenu!.items[0]
        NSApp.sendAction(large.action!, to: large.target, from: large)
        precondition(last?.size == .large && last?.displayScope == .focusDesktop)
        precondition(!controller.makeMenu().items[1].isEnabled)
        let translucent = controller.makeMenu().items[3].submenu!.items[1]
        NSApp.sendAction(translucent.action!, to: translucent.target, from: translucent)
        precondition(last?.opacityPreset == .translucent && last?.size == .large)
        let minimal = controller.makeMenu().items[4].submenu!.items[2]
        NSApp.sendAction(minimal.action!, to: minimal.target, from: minimal)
        precondition(last?.densityPreset == .minimal && last?.opacityPreset == .translucent)
        let warm = controller.makeMenu().items[5].submenu!.items[2]
        NSApp.sendAction(warm.action!, to: warm.target, from: warm)
        precondition(last?.ringTheme == .warm && last?.densityPreset == .minimal)
        let fiveHours = controller.makeMenu().items[6].submenu!.items[1]
        NSApp.sendAction(fiveHours.action!, to: fiveHours.target, from: fiveHours)
        precondition(last?.historyRetention == .local5Hours && last?.size == .large
                     && last?.displayScope == .focusDesktop)
        precondition(controller.makeMenu().items[3].submenu!.items.map(\.state) == [.off, .on, .off])
        precondition(controller.makeMenu().items[4].submenu!.items.map(\.state) == [.off, .off, .on])
        precondition(controller.makeMenu().items[5].submenu!.items.map(\.state) == [.off, .off, .on, .off])
        precondition(controller.makeMenu().items[6].submenu!.items.map(\.state) == [.off, .on])
        let english = controller.makeMenu().items[7].submenu!.items[1]
        NSApp.sendAction(english.action!, to: english.target, from: english)
        precondition(last?.language == .english && last?.historyRetention == .local5Hours)
        print("PASS: menu checkmarks, scope, appearance, theme, history and language selection, independent changes and disabled orientation")
    }
}
