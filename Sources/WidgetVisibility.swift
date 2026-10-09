import Foundation

enum WidgetVisibility {
    static let hostBundleID = "com.openai.codex"
    static func shouldShow(scope: DisplayScope, frontmostBundleID: String?, hasCodexWindow: Bool, isDesktopVisible: Bool) -> Bool {
        switch scope {
        case .focusCodex: return hasCodexWindow && frontmostBundleID == hostBundleID
        case .always: return true
        case .focusDesktop: return frontmostBundleID == "com.apple.finder" && isDesktopVisible
        }
    }
    static func shouldShowTaskRows() -> Bool {
        // The default widget scope is `.focusCodex`; hiding task rows there
        // made active tasks impossible to see without changing preferences.
        true
    }
}
