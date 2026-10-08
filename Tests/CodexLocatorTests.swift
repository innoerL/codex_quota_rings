import Foundation

private final class FakeApplicationLocator: CodexApplicationLocating {
    let url: URL?
    private(set) var requestedBundleIDs: [String] = []

    init(url: URL?) { self.url = url }

    func applicationURL(bundleIdentifier: String) -> URL? {
        requestedBundleIDs.append(bundleIdentifier)
        return url
    }
}

private final class CheckedPaths {
    var values: [String] = []
}

@main struct CodexLocatorTests {
    static func main() {
        let home = URL(fileURLWithPath: "/Users/quota tester", isDirectory: true)

        func locate(appURL: URL? = nil,
                    environment: [String: String] = [:],
                    executablePaths: Set<String>) -> (CodexLocation?, FakeApplicationLocator, [String]) {
            let apps = FakeApplicationLocator(url: appURL)
            let checked = CheckedPaths()
            let locator = CodexLocator(applicationLocator: apps,
                                       environment: environment,
                                       homeDirectory: home) { path in
                checked.values.append(path)
                return executablePaths.contains(path)
            }
            return (locator.locate(), apps, checked.values)
        }

        let override = "/Developer Tools/Codex Beta/codex"
        let overridden = locate(environment: ["QUOTA_CODEX_PATH": override], executablePaths: [override])
        precondition(overridden.0 == CodexLocation(executableURL: URL(fileURLWithPath: override), applicationURL: nil))
        precondition(overridden.2 == [override], "developer override must be checked first")

        let movedApp = URL(fileURLWithPath: "/Volumes/Work Apps/Codex.app", isDirectory: true)
        let movedCLI = movedApp.appendingPathComponent("Contents/Resources/codex").path
        let moved = locate(appURL: movedApp, executablePaths: [movedCLI])
        precondition(moved.0 == CodexLocation(executableURL: URL(fileURLWithPath: movedCLI), applicationURL: movedApp))
        precondition(moved.1.requestedBundleIDs == ["com.openai.codex"], "application lookup must use the exact bundle identifier")

        let homeCLI = home.appendingPathComponent("Applications/Codex.app/Contents/Resources/codex").path
        let userInstall = locate(executablePaths: [homeCLI])
        precondition(userInstall.0?.executableURL.path == homeCLI, "user Applications must work without configuration")

        let brewCLI = "/opt/homebrew/bin/codex"
        let brokenMoved = locate(appURL: movedApp, executablePaths: [brewCLI])
        precondition(brokenMoved.0 == CodexLocation(executableURL: URL(fileURLWithPath: brewCLI), applicationURL: movedApp),
                     "a broken app CLI must fall back while retaining the app URL")
        precondition(brokenMoved.2.first == movedCLI && brokenMoved.2.contains(brewCLI),
                     "registered app candidates must be tried before common CLI paths")

        let pathCLI = "/custom tools/bin/codex"
        let pathOnly = locate(environment: ["PATH": "/missing:/custom tools/bin"], executablePaths: [pathCLI])
        precondition(pathOnly.0?.executableURL.path == pathCLI, "an executable on the explicit PATH must be discovered")

        let missing = locate(environment: ["PATH": "/missing"], executablePaths: [])
        precondition(missing.0 == nil, "absence must be reported without choosing a non-executable candidate")
        precondition(missing.2.contains("/Applications/Codex.app/Contents/Resources/codex"))
        precondition(missing.2.contains(homeCLI))
        precondition(missing.2.contains("/usr/local/bin/codex"))

        print("PASS: zero-configuration Codex discovery and invalid-candidate fallback")
    }
}
