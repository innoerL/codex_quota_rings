import Foundation

@main struct VisibilityTests {
    static func main() {
        var count = 0
        for scope in DisplayScope.allCases {
            for front in [nil, "com.openai.codex", "com.apple.finder", "com.apple.Safari"] as [String?] {
                for hostWindow in [false, true] {
                    for desktop in [false, true] {
                        let expected: Bool
                        switch scope {
                        case .focusCodex: expected = front == "com.openai.codex" && hostWindow
                        case .always: expected = true
                        case .focusDesktop: expected = front == "com.apple.finder" && desktop
                        }
                        precondition(WidgetVisibility.shouldShow(scope: scope, frontmostBundleID: front,
                            hasCodexWindow: hostWindow, isDesktopVisible: desktop) == expected)
                        count += 1
                    }
                }
            }
        }
        precondition(!WidgetVisibility.shouldShowTaskRows(frontmostBundleID: WidgetVisibility.hostBundleID),
                     "FAIL: task rows must hide while Codex is focused")
        precondition(WidgetVisibility.shouldShowTaskRows(frontmostBundleID: "com.apple.finder"),
                     "FAIL: task rows must show outside focused Codex")
        print("PASS: \(count) display-scope combinations")
    }
}
