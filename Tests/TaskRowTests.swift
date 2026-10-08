import AppKit

@main struct TaskRowTests {
    static func main() {
        _ = NSApplication.shared
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let status = WidgetTaskStatus(id: "thread/1", title: "一个很长很长而且必须在尾部截断的真实任务标题",
                                      state: .running, activeSince: start, completedAt: nil)
        let row = TaskRowView(status: status, frame: NSRect(x: 0, y: 0, width: 250, height: 28))
        row.now = start.addingTimeInterval(12 * 60)
        precondition(row.titleField.lineBreakMode == .byTruncatingTail)
        precondition(row.statusField.stringValue == "Running · 12 分钟")
        precondition(row.statusField.textColor == TaskStatusPalette.runningColor)
        precondition(row.usesPointingHandCursor)

        row.mouseEntered(with: NSEvent())
        precondition(row.isHovered)
        row.mouseExited(with: NSEvent())
        precondition(!row.isHovered)

        var rowClicks = 0, cardClicks = 0
        row.onClick = { id in precondition(id == "thread/1"); rowClicks += 1 }
        let card = QuotaView(frame: NSRect(x: 0, y: 0, width: 250, height: 80))
        card.onClick = { cardClicks += 1 }; card.addSubview(row)
        let down = NSEvent.mouseEvent(with: .leftMouseDown, location: NSPoint(x: 10, y: 10), modifierFlags: [], timestamp: 0,
                                      windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
        let up = NSEvent.mouseEvent(with: .leftMouseUp, location: NSPoint(x: 10, y: 10), modifierFlags: [], timestamp: 0.1,
                                    windowNumber: 0, context: nil, eventNumber: 2, clickCount: 1, pressure: 0)!
        row.mouseDown(with: down); row.mouseUp(with: up)
        precondition(rowClicks == 1 && cardClicks == 0, "task click must fire once without toggling its card")

        row.status = WidgetTaskStatus(id: "thread/1", title: "任务", state: .completed,
                                      activeSince: start, completedAt: start.addingTimeInterval(18 * 60))
        precondition(row.statusField.stringValue == "Completed · 用时 18 分钟")
        precondition(row.statusField.textColor == TaskStatusPalette.completedColor)
        print("PASS: reusable task row duration, palette, hover, cursor and isolated click")
    }
}
