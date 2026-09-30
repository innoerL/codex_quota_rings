import AppKit

@main struct ControllerTests {
    static func main() {
        _ = NSApplication.shared
        let suite = "quota-controller-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let app = QuotaApp(defaults: defaults, client: QuotaClient(executableURL: URL(fileURLWithPath: CommandLine.arguments[1])))
        app.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        defer { app.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification)) }
        var p = WidgetPreferences(size: .small, smallLayout: .vertical, displayScope: .always)
        app.applyPreferences(p)
        precondition(app.panel.isVisible)
        let compactSize = app.panel.frame.size
        let compactOrigin = app.panel.frame.origin
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        p.size = .large; app.applyPreferences(p)
        let collapsedHeight = app.panel.frame.height
        app.toggleDetails()
        precondition(app.panel.frame.height > collapsedHeight && !app.detailsPanel.isVisible)
        app.toggleDetails()
        precondition(app.panel.frame.height == collapsedHeight)
        // Expansion may need to clamp the taller card upward, but that is not a drag.
        let screen = app.panel.screen!.visibleFrame
        app.panel.setFrameOrigin(NSPoint(x: screen.minX + 30, y: screen.minY + 5))
        let bottomOrigin = app.panel.frame.origin
        app.toggleDetails(); app.toggleDetails()
        precondition(app.panel.frame.origin == bottomOrigin, "expanding near bottom must preserve placement")
        app.toggleDetails()
        p.size = .small; app.applyPreferences(p)
        p.size = .large; app.applyPreferences(p)
        precondition(app.panel.frame.origin == bottomOrigin, "temporary expansion clamp must not overwrite saved position")
        p.size = .small; app.applyPreferences(p)
        precondition(app.panel.frame.size == compactSize && app.panel.frame.origin == compactOrigin)
        app.toggleDetails(); precondition(app.detailsPanel.isVisible)
        p.smallLayout = .horizontal; app.applyPreferences(p)
        precondition(!app.detailsPanel.isVisible && app.panel.frame.width > app.panel.frame.height)
        precondition(WidgetPreferences.load(from: defaults) == p)
        precondition(NSWorkspace.shared.frontmostApplication?.bundleIdentifier == front, "widget must not activate")
        app.panel.orderOut(nil)
        print("PASS: real panels, in-place expansion, compact details, position restore, persistence, no focus stealing")
    }
}
