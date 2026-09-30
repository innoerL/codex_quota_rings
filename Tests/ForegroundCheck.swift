import AppKit
import CoreGraphics

@main struct ForegroundCheck {
    static func waitFor(_ predicate: () -> Bool) -> Bool {
        let end = Date(timeIntervalSinceNow: 4)
        repeat {
            if predicate() { return true }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        } while Date() < end
        return false
    }
    static func visibleWidgetCount(_ pid: pid_t) -> Int {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.filter { item in
            guard item[kCGWindowOwnerPID as String] as? Int == Int(pid),
                  let bounds = item[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return false }
            return frame.width >= 40 && frame.height > 80
        }.count
    }
    static func main() {
        guard let host = NSRunningApplication.runningApplications(withBundleIdentifier: WidgetVisibility.hostBundleID).first,
              let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first,
              let widget = NSRunningApplication.runningApplications(withBundleIdentifier: "local.quota-rings").first else {
            fputs("FAIL: apps required for visibility check are not running\n", stderr); exit(1)
        }
        host.activate(options: [])
        guard waitFor({ NSWorkspace.shared.frontmostApplication?.bundleIdentifier == WidgetVisibility.hostBundleID && visibleWidgetCount(widget.processIdentifier) > 0 }) else {
            fputs("FAIL: widget not visible with Codex foreground\n", stderr); exit(1)
        }
        finder.activate(options: [])
        let hidden = waitFor { NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder" && visibleWidgetCount(widget.processIdentifier) == 0 }
        // Always restore the original Codex app before reporting a failure.
        host.activate(options: [])
        let restored = waitFor { NSWorkspace.shared.frontmostApplication?.bundleIdentifier == WidgetVisibility.hostBundleID && visibleWidgetCount(widget.processIdentifier) > 0 }
        guard hidden && restored else { fputs("FAIL: hidden=\(hidden), restored=\(restored)\n", stderr); exit(1) }
        print("PASS: visible in Codex, hidden in Finder, automatically restored in Codex")
    }
}
