import AppKit
import Foundation

struct CodexLocation: Equatable {
    let executableURL: URL
    let applicationURL: URL?
}

protocol CodexApplicationLocating {
    func applicationURL(bundleIdentifier: String) -> URL?
}

protocol CodexLocating {
    func locate() -> CodexLocation?
}

struct WorkspaceCodexApplicationLocator: CodexApplicationLocating {
    func applicationURL(bundleIdentifier: String) -> URL? {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first,
           let bundleURL = running.bundleURL {
            return bundleURL
        }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }
}

struct CodexLocator: CodexLocating {
    private let applicationLocator: CodexApplicationLocating
    private let environment: [String: String]
    private let homeDirectory: URL
    private let isExecutable: (String) -> Bool

    init() {
        self.init(applicationLocator: WorkspaceCodexApplicationLocator(),
                  environment: ProcessInfo.processInfo.environment,
                  homeDirectory: FileManager.default.homeDirectoryForCurrentUser,
                  isExecutable: Self.isRunnableExecutable(at:))
    }

    init(applicationLocator: CodexApplicationLocating,
         environment: [String: String],
         homeDirectory: URL,
         isExecutable: @escaping (String) -> Bool) {
        self.applicationLocator = applicationLocator
        self.environment = environment
        self.homeDirectory = homeDirectory
        self.isExecutable = isExecutable
    }

    func locate() -> CodexLocation? {
        if let override = environment["QUOTA_CODEX_PATH"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty, isExecutable(override) {
            return CodexLocation(executableURL: URL(fileURLWithPath: override), applicationURL: nil)
        }

        let registeredApp = applicationLocator.applicationURL(bundleIdentifier: WidgetVisibility.hostBundleID)
        let systemApp = URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true)
        let userApp = homeDirectory.appendingPathComponent("Applications/Codex.app", isDirectory: true)
        var candidates: [(URL, URL?)] = []

        if let registeredApp {
            candidates.append((registeredApp.appendingPathComponent("Contents/Resources/codex"), registeredApp))
        }
        candidates.append((systemApp.appendingPathComponent("Contents/Resources/codex"), systemApp))
        candidates.append((userApp.appendingPathComponent("Contents/Resources/codex"), userApp))

        for path in ["/opt/homebrew/bin/codex", "/usr/local/bin/codex"] {
            candidates.append((URL(fileURLWithPath: path), registeredApp))
        }
        for directory in (environment["PATH"] ?? "").split(separator: ":", omittingEmptySubsequences: true) {
            candidates.append((URL(fileURLWithPath: String(directory), isDirectory: true).appendingPathComponent("codex"), registeredApp))
        }

        var checked = Set<String>()
        for (executable, application) in candidates where checked.insert(executable.path).inserted {
            if isExecutable(executable.path) {
                return CodexLocation(executableURL: executable, applicationURL: application)
            }
        }
        return nil
    }

    static func isRunnableExecutable(at path: String) -> Bool {
        guard FileManager.default.isExecutableFile(atPath: path) else { return false }
        let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        return (try? resolved.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }
}
