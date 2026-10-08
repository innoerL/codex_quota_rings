import AppKit

@main struct MenuTests {
    static func main() {
        _ = NSApplication.shared
        let controller = WidgetMenu(preferences: WidgetPreferences())
        var last: WidgetPreferences?
        controller.onChange = { last = $0 }
        let menu = controller.makeMenu()
        precondition(menu.items.count == 4)
        precondition(menu.items[2].submenu!.items.map(\.title) == ["聚焦 Codex 时显示", "一直显示", "聚焦桌面时显示"])
        precondition(menu.items[2].submenu!.items[0].state == .on)
        precondition(menu.items[3].title == "趋势记录")
        precondition(menu.items[3].submenu!.items.map(\.title) == ["仅本次 · 30 分钟", "保留 24 小时", "保留 7 天"])
        precondition(menu.items[3].submenu!.items[0].state == .on)
        let desktop = menu.items[2].submenu!.items[2]
        NSApp.sendAction(desktop.action!, to: desktop.target, from: desktop)
        precondition(last?.displayScope == .focusDesktop && last?.size == .small)
        let large = controller.makeMenu().items[0].submenu!.items[0]
        NSApp.sendAction(large.action!, to: large.target, from: large)
        precondition(last?.size == .large && last?.displayScope == .focusDesktop)
        precondition(!controller.makeMenu().items[1].isEnabled)
        let sevenDays = controller.makeMenu().items[3].submenu!.items[2]
        NSApp.sendAction(sevenDays.action!, to: sevenDays.target, from: sevenDays)
        precondition(last?.historyRetention == .local7Days && last?.size == .large
                     && last?.displayScope == .focusDesktop)
        precondition(controller.makeMenu().items[3].submenu!.items.map(\.state) == [.off, .off, .on])
        print("PASS: menu checkmarks, scope and history selection, independent changes and disabled orientation")
    }
}
