import AppKit

@main struct ControllerTests {
    static func main() {
        _ = NSApplication.shared
        func approximatelyEqual(_ actual: NSSize, _ expected: NSSize) -> Bool {
            // Window Server content frames are rounded to device pixels. A one-point
            // tolerance keeps this integration test valid on both retina and CI displays.
            abs(actual.width - expected.width) <= 1 && abs(actual.height - expected.height) <= 1
        }
        let suite = "quota-controller-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let historyRoot = FileManager.default.temporaryDirectory.appendingPathComponent("quota-controller-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: historyRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: historyRoot) }
        let app = QuotaApp(defaults: defaults,
                           client: QuotaClient(executableURL: URL(fileURLWithPath: CommandLine.arguments[1])),
                           historyFileURL: historyRoot.appendingPathComponent("quota-history.json"))
        app.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        defer { app.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification)) }
        var p = WidgetPreferences(size: .small, smallLayout: .vertical, displayScope: .always)
        app.applyPreferences(p)
        precondition(app.panel.isVisible)
        let compactOrigin = app.panel.frame.origin
        let compactTop = app.panel.frame.maxY
        p.opacityPreset = .light
        p.densityPreset = .compact
        app.applyPreferences(p)
        precondition(app.panel.alphaValue == WidgetOpacityPreset.light.alpha,
                     "selected opacity must propagate to the compact panel")
        let compactExpectedSize = NSSize(width: 42 * 0.88, height: 124 * 0.88)
        precondition(approximatelyEqual(app.panel.frame.size, compactExpectedSize),
                     "compact density must alter the panel frame; expected \(compactExpectedSize), got \(app.panel.frame.size)")
        precondition(app.panel.frame.minX == compactOrigin.x && app.panel.frame.maxY == compactTop,
                     "density changes must preserve the saved top-left anchor")
        p.densityPreset = .minimal
        app.applyPreferences(p)
        precondition(approximatelyEqual(app.panel.frame.size, NSSize(width: 42 * 0.76, height: 124 * 0.76)),
                     "every density preset must change the active frame")
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
        let finalCompactSize = WidgetLayoutMetrics(density: .minimal).smallVertical
        precondition(approximatelyEqual(app.panel.frame.size, finalCompactSize)
                     && app.panel.frame.minX == compactOrigin.x && app.panel.frame.maxY == compactTop,
                     "restoring the compact widget must retain density and its top-left anchor")
        app.toggleDetails(); precondition(app.detailsPanel.isVisible)
        let detailTop = app.detailsPanel.frame.maxY
        p.historyRetention = .local5Hours; app.applyPreferences(p)
        precondition(app.detailsPanel.isVisible, "history changes must keep the compact detail card open")
        precondition(abs(app.detailsPanel.frame.maxY - detailTop) < 1,
                     "history changes must preserve the compact detail top edge")
        p.smallLayout = .horizontal; app.applyPreferences(p)
        precondition(!app.detailsPanel.isVisible && app.panel.frame.width > app.panel.frame.height)
        precondition(WidgetPreferences.load(from: defaults) == p)
        precondition(NSWorkspace.shared.frontmostApplication?.bundleIdentifier == front, "widget must not activate")
        app.panel.orderOut(nil)
        print("PASS: real panels, in-place expansion, compact details, position restore, persistence, no focus stealing")
    }
}
