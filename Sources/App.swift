import AppKit
import CoreGraphics

final class QuotaApp: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let client: QuotaClient
    private let defaults: UserDefaults
    private let historyStore: QuotaHistoryStore
    private var forecastEngine = QuotaForecastEngine()
    private var connectionState: QuotaConnectionState = .locating
    private let view = QuotaView(frame: NSRect(origin: .zero, size: QuotaView.preferredSize))
    private let largeView = LargeQuotaView(frame: NSRect(origin: .zero, size: LargeQuotaView.collapsedSize))
    private var preferences: WidgetPreferences
    private lazy var widgetMenu = WidgetMenu(preferences: preferences)
    private var changingFrame = false
    // Logical placement survives temporary screen-edge clamping while details are open.
    private var placementAnchor: NSPoint?
    private(set) var panel: NSPanel!
    private var statusItem: NSStatusItem!
    private let details = QuotaDetailsView(frame: NSRect(origin: .zero, size: QuotaDetailsView.preferredSize))
    private(set) var detailsPanel: NSPanel!
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var freshnessTimer: Timer?
    private var visibilityTimer: Timer?

    init(defaults: UserDefaults = .standard, client: QuotaClient = QuotaClient(), historyFileURL: URL? = nil) {
        self.defaults = defaults; self.client = client
        let loaded = WidgetPreferences.load(from: defaults)
        self.preferences = loaded
        let defaultHistoryURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Quota Rings", isDirectory: true)
            .appendingPathComponent("quota-history.json")
        self.historyStore = QuotaHistoryStore(retention: loaded.historyRetention,
                                              fileURL: historyFileURL ?? defaultHistoryURL)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let bundleID = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSApp.terminate(nil); return
        }
        NSApp.setActivationPolicy(.accessory)
        panel = NSPanel(contentRect: view.bounds, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Codex 额度双环"
        panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = false
        panel.level = .floating; panel.hidesOnDeactivate = false; panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = view
        if let screen = NSScreen.main {
            let saved = defaults
            let sidebar = initialSidebarOrigin(on: screen)
            let useSaved = saved.integer(forKey: "compactLayoutVersion") == 2
            let point = NSPoint(x: useSaved ? (saved.object(forKey: "positionX") as? Double ?? sidebar.x) : sidebar.x,
                                y: useSaved ? (saved.object(forKey: "positionY") as? Double ?? sidebar.y) : sidebar.y)
            let valid = NSScreen.screens.contains { $0.visibleFrame.contains(NSRect(origin: point, size: view.bounds.size)) }
            panel.setFrameOrigin(valid ? point : sidebar)
            saved.set(2, forKey: "compactLayoutVersion")
        }
        detailsPanel = NSPanel(contentRect: details.bounds, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        detailsPanel.title = "额度详情"
        detailsPanel.backgroundColor = .clear; detailsPanel.isOpaque = false; detailsPanel.hasShadow = true
        detailsPanel.level = .floating; detailsPanel.hidesOnDeactivate = false
        detailsPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        detailsPanel.contentView = details
        panel.delegate = self
        view.showUsed = defaults.bool(forKey: "showUsed")
        view.onMenu = { [weak self] in self?.makeMenu() ?? NSMenu() }
        view.onClick = { [weak self] in self?.toggleDetails() }
        view.onDrag = { [weak self] in self?.hideDetails() }
        view.onDragFinished = { [weak self] in self?.snapPanelAfterDrag() }
        largeView.onMenu = { [weak self] in self?.makeMenu() ?? NSMenu() }
        largeView.onClick = { [weak self] in self?.toggleDetails() }
        largeView.onDragFinished = { [weak self] in self?.snapPanelAfterDrag() }
        largeView.onInstallCodex = { [weak self] in self?.installCodex() }
        details.onInstallCodex = { [weak self] in self?.installCodex() }
        largeView.showUsed = view.showUsed
        widgetMenu.onChange = { [weak self] selection in self?.applyPreferences(selection) }
        applyPresentation()
        configureLayout(restorePosition: true)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "circle.dashed", accessibilityDescription: "Codex 额度")
        statusItem.button?.toolTip = "Codex 额度双环"
        statusItem.button?.target = self; statusItem.button?.action = #selector(showMenu)
        client.onChange = { [weak self] snapshot, error in
            self?.applyQuota(snapshot: snapshot, error: error)
        }
        client.onConnectionState = { [weak self] state in
            self?.applyConnectionState(state)
        }
        publishHistory()
        applyConnectionState(.locating)
        freshnessTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.view.needsDisplay = true; self.largeView.needsDisplay = true; self.details.updateLabels()
            self.publishHistory()
        }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(woke), name: NSWorkspace.didWakeNotification, object: nil)
        let notifications: [Notification.Name] = [NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didDeactivateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification,
            NSWorkspace.didHideApplicationNotification, NSWorkspace.didUnhideApplicationNotification]
        for name in notifications {
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refreshVisibility), name: name, object: nil)
        }
        visibilityTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.refreshVisibility() }
        RunLoop.main.add(visibilityTimer!, forMode: .common)
        refreshVisibility()
        client.start()
    }
    func windowDidMove(_ notification: Notification) {
        guard !changingFrame, let panel else { return }
        placementAnchor = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
        savePosition()
    }
    private func savePosition() {
        guard let panel else { return }
        let anchor = placementAnchor ?? NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
        let key = "widget.position.\(preferences.positionKey)"
        defaults.set(anchor.x, forKey: key + ".x")
        defaults.set(anchor.y, forKey: key + ".top")
    }
    func applicationWillTerminate(_ notification: Notification) {
        hideDetails()
        freshnessTimer?.invalidate()
        visibilityTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
        panel?.orderOut(nil)
        client.stop()
    }
    private func initialSidebarOrigin(on screen: NSScreen) -> NSPoint {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let frames = windows.compactMap { item -> CGRect? in
            guard ["Codex", "ChatGPT"].contains(item[kCGWindowOwnerName as String] as? String ?? ""),
                  item[kCGWindowLayer as String] as? Int == 0,
                  let bounds = item[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary), frame.width > 400, frame.height > 300 else { return nil }
            return frame
        }
        if let frame = frames.max(by: { $0.width * $0.height < $1.width * $1.height }) {
            let desktopTop = NSScreen.screens.first?.frame.maxY ?? screen.frame.maxY
            return NSPoint(x: frame.minX + 5, y: desktopTop - frame.maxY + 110)
        }
        return NSPoint(x: screen.visibleFrame.minX + 5, y: screen.visibleFrame.minY + 30)
    }
    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        func info(_ text: String) { let item = NSMenuItem(title: text, action: nil, keyEquivalent: ""); item.isEnabled = false; menu.addItem(item) }
        func action(_ text: String, _ selector: Selector) -> NSMenuItem {
            let item = NSMenuItem(title: text, action: selector, keyEquivalent: ""); item.target = self; menu.addItem(item); return item
        }
        info("Codex \(view.showUsed ? "已用" : "剩余")额度")
        if let snapshot = view.snapshot {
            let format = DateFormatter(); format.dateFormat = "MM-dd HH:mm:ss"
            info("更新：\(format.string(from: snapshot.fetchedAt))")
            for (name, window) in [("5小时", snapshot.fiveHour), ("一周", snapshot.week)] {
                if let reset = window?.resetsAt { info("\(name)重置：\(format.string(from: Date(timeIntervalSince1970: reset)))") }
            }
        }
        if let error = view.connectionError { info(error) }
        if let error = historyStore.persistenceError { info(error) }
        info("每30秒刷新 · 点击查看详情")
        menu.addItem(.separator())
        _ = action("额度详情", #selector(toggleDetails))
        switch connectionState {
        case .codexNotInstalled: _ = action("安装 Codex", #selector(installCodex))
        default: break
        }
        let used = action("显示已用百分比", #selector(toggleUsed)); used.state = view.showUsed ? .on : .off
        let options = widgetMenu.makeMenu()
        for item in options.items { options.removeItem(item); menu.addItem(item) }
        menu.addItem(.separator())
        _ = action("退出额度双环", #selector(quit))
        return menu
    }
    @objc private func showMenu() {
        guard let button = statusItem.button else { return }
        makeMenu().popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
    }
    @objc private func toggleUsed() {
        view.showUsed.toggle(); details.showUsed = view.showUsed
        largeView.showUsed = view.showUsed
        defaults.set(view.showUsed, forKey: "showUsed")
    }
    func applyPreferences(_ selection: WidgetPreferences) {
        let previous = preferences
        let structuralChange = previous.size != selection.size || previous.smallLayout != selection.smallLayout
            || previous.displayScope != selection.displayScope || previous.densityPreset != selection.densityPreset
        if structuralChange { savePosition() }
        let layoutChanged = preferences.positionKey != selection.positionKey
        if structuralChange { hideDetails(); largeView.isExpanded = false }
        preferences = selection; preferences.save(to: defaults)
        widgetMenu.preferences = selection
        applyPresentation()
        if previous.historyRetention != selection.historyRetention {
            _ = historyStore.setRetention(selection.historyRetention, at: Date())
            publishHistory()
        }
        if structuralChange { configureLayout(restorePosition: layoutChanged) }
        else {
            if preferences.size == .large, largeView.isExpanded { configureLayout(restorePosition: false) }
            if detailsPanel.isVisible { resizeDetailsPanel() }
        }
        refreshVisibility()
    }
    private func configureLayout(restorePosition: Bool) {
        guard let panel else { return }
        changingFrame = true
        defer { changingFrame = false }
        view.smallLayout = preferences.smallLayout
        let content: QuotaView = preferences.size == .large ? largeView : view
        let size = content.preferredContentSize
        var anchor = placementAnchor ?? NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
        let key = "widget.position.\(preferences.positionKey)"
        if restorePosition, let x = defaults.object(forKey: key + ".x") as? Double,
           let top = defaults.object(forKey: key + ".top") as? Double {
            anchor = NSPoint(x: x, y: top)
        }
        let screen = NSScreen.screens.first { $0.visibleFrame.contains(anchor) }?.visibleFrame
            ?? panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? panel.frame
        let x = max(screen.minX, min(anchor.x, screen.maxX - size.width))
        let y = max(screen.minY, min(anchor.y - size.height, screen.maxY - size.height))
        placementAnchor = largeView.isExpanded ? anchor : NSPoint(x: x, y: y + size.height)
        panel.contentView = content
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        content.frame = NSRect(origin: .zero, size: size)
        panel.hasShadow = preferences.size == .large
    }
    private func applyPresentation() {
        let metrics = WidgetLayoutMetrics(density: preferences.densityPreset)
        let opacity = preferences.opacityPreset.alpha
        view.metrics = metrics; view.contentOpacity = opacity
        largeView.metrics = metrics; largeView.contentOpacity = opacity
        details.metrics = metrics; details.contentOpacity = opacity
        panel?.alphaValue = opacity
        detailsPanel?.alphaValue = opacity
    }
    private func snapPanelAfterDrag() {
        guard let panel else { return }
        let screenFrame = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? panel.frame
        let desktopTop = NSScreen.screens.map { $0.frame.maxY }.max() ?? screenFrame.maxY
        let ownPID = Int(ProcessInfo.processInfo.processIdentifier)
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        var codexFrames: [CGRect] = []
        var occupiedFrames: [CGRect] = []
        for item in windows {
            guard item[kCGWindowLayer as String] as? Int == 0,
                  (item[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  item[kCGWindowOwnerPID as String] as? Int != ownPID,
                  let bounds = item[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  frame.width > 40, frame.height > 40 else { continue }
            let appKitFrame = CGRect(x: frame.minX, y: desktopTop - frame.maxY, width: frame.width, height: frame.height)
            let owner = item[kCGWindowOwnerName as String] as? String
            if owner == "Codex" || owner == "ChatGPT" {
                codexFrames.append(appKitFrame)
            } else {
                occupiedFrames.append(appKitFrame)
            }
        }
        let resolved = WidgetPlacementResolver.resolve(panelFrame: panel.frame, screenFrame: screenFrame,
                                                       codexFrames: codexFrames, occupiedFrames: occupiedFrames)
        changingFrame = true
        panel.setFrameOrigin(resolved.origin)
        changingFrame = false
        placementAnchor = NSPoint(x: resolved.minX, y: resolved.maxY)
        savePosition()
    }
    private func applyQuota(snapshot: QuotaSnapshot?, error: String?) {
        let forecasts = (error == nil ? snapshot.map { forecastEngine.record($0) } : nil) ?? .collecting
        for target in [view as QuotaView, largeView as QuotaView] {
            target.snapshot = snapshot
            target.connectionError = error
            target.forecasts = forecasts
        }
        details.snapshot = snapshot
        details.connectionError = error
        details.forecasts = forecasts
        if error == nil, let snapshot, !snapshot.isStale() {
            _ = historyStore.record(snapshot)
            publishHistory()
        }
    }
    private func publishHistory() {
        let samples = historyStore.samples(at: Date())
        largeView.historySamples = samples; largeView.historyRetention = historyStore.retention
        details.historySamples = samples; details.historyRetention = historyStore.retention
        if detailsPanel?.isVisible == true { resizeDetailsPanel() }
    }
    private func applyConnectionState(_ state: QuotaConnectionState) {
        connectionState = state
        view.connectionState = state
        largeView.connectionState = state
        details.connectionState = state
        if preferences.size == .large, largeView.isExpanded { configureLayout(restorePosition: false) }
        if detailsPanel?.isVisible == true { resizeDetailsPanel() }
    }
    private func resizeDetailsPanel() {
        let size = details.preferredContentSize
        let current = detailsPanel.frame
        details.frame = NSRect(origin: .zero, size: size)
        detailsPanel.setFrame(NSRect(x: current.minX, y: current.maxY - size.height, width: size.width, height: size.height), display: true)
    }
    @objc func toggleDetails() {
        if preferences.size == .large {
            guard shouldDisplayNow() else { return }
            largeView.isExpanded.toggle()
            configureLayout(restorePosition: false)
            return
        }
        if detailsPanel.isVisible { hideDetails(); return }
        guard shouldDisplayNow() else { return }
        view.isExpanded = true
        details.showUsed = view.showUsed
        let screen = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? panel.frame
        let size = details.preferredContentSize
        var x = panel.frame.maxX + 8
        if x + size.width > screen.maxX { x = panel.frame.minX - size.width - 8 }
        x = max(screen.minX, min(x, screen.maxX-size.width))
        let y = max(screen.minY, min(panel.frame.maxY + 36 - size.height, screen.maxY-size.height))
        details.frame = NSRect(origin: .zero, size: size)
        detailsPanel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        detailsPanel.orderFrontRegardless()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown && event.keyCode == 53 { self.hideDetails(); return nil }
            if event.type != .keyDown && event.window !== self.detailsPanel && event.window !== self.panel { self.hideDetails() }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in self?.hideDetails() }
    }
    private func hideDetails() {
        detailsPanel?.orderOut(nil)
        view.isExpanded = false
        if let localMonitor { NSEvent.removeMonitor(localMonitor); self.localMonitor = nil }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor); self.globalMonitor = nil }
    }
    private func shouldDisplayNow() -> Bool {
        let front = NSWorkspace.shared.frontmostApplication
        if preferences.displayScope == .always { return true }
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return false }
        let hasWindow = windows.contains { item in
            guard let front, item[kCGWindowOwnerPID as String] as? Int == Int(front.processIdentifier),
                  item[kCGWindowLayer as String] as? Int == 0,
                  let bounds = item[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return false }
            return frame.width > 200 && frame.height > 150
        }
        // Finder foreground alone also includes Finder windows. Only a clear desktop qualifies.
        let ordinaryWindow = windows.contains { item in
            guard item[kCGWindowOwnerPID as String] as? Int != Int(ProcessInfo.processInfo.processIdentifier),
                  item[kCGWindowLayer as String] as? Int == 0,
                  (item[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let bounds = item[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  frame.width > 40, frame.height > 40 else { return false }
            let desktopTop = NSScreen.screens.first?.frame.maxY ?? 0
            let appKitFrame = CGRect(x: frame.minX, y: desktopTop-frame.maxY, width: frame.width, height: frame.height)
            return NSScreen.screens.contains { $0.visibleFrame.intersection(appKitFrame).width > 40 && $0.visibleFrame.intersection(appKitFrame).height > 40 }
        }
        return WidgetVisibility.shouldShow(scope: preferences.displayScope, frontmostBundleID: front?.bundleIdentifier,
                                           hasCodexWindow: hasWindow, isDesktopVisible: !ordinaryWindow)
    }
    @objc private func refreshVisibility() {
        if shouldDisplayNow() {
            if !panel.isVisible { panel.orderFrontRegardless() }
        } else {
            if detailsPanel.isVisible { hideDetails() }
            if largeView.isExpanded { largeView.isExpanded = false; configureLayout(restorePosition: false) }
            if panel.isVisible { panel.orderOut(nil) }
        }
    }
    @objc private func woke() { client.stop(); client.start() }
    @objc private func installCodex() {
        guard let url = URL(string: "https://chatgpt.com/download/") else { return }
        NSWorkspace.shared.open(url)
    }
    @objc private func quit() { NSApp.terminate(nil) }
}

#if !QUOTA_TEST
@main struct Main {
    static func main() {
        let app = NSApplication.shared
        let delegate = QuotaApp()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
#endif
