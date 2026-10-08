import AppKit

protocol CodexWorkspaceOpening {
    func applicationURL(for url: URL) -> URL?
    func open(_ url: URL) -> Bool
    func activateCodex(applicationURL: URL?) -> Bool
}

protocol CodexNavigating {
    @discardableResult func openTask(id: String) -> Bool
}

struct WorkspaceCodexOpener: CodexWorkspaceOpening {
    func applicationURL(for url: URL) -> URL? {
        NSWorkspace.shared.urlForApplication(toOpen: url)
    }

    func open(_ url: URL) -> Bool { NSWorkspace.shared.open(url) }

    func activateCodex(applicationURL: URL?) -> Bool {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: WidgetVisibility.hostBundleID).first {
            return running.activate(options: [.activateAllWindows])
        }
        let url = applicationURL ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: WidgetVisibility.hostBundleID)
        guard let url else { return false }
        return NSWorkspace.shared.open(url)
    }
}

struct CodexNavigator: CodexNavigating {
    private let workspace: CodexWorkspaceOpening
    private let codexApplicationURL: () -> URL?

    init(workspace: CodexWorkspaceOpening = WorkspaceCodexOpener(),
         codexApplicationURL: @escaping () -> URL?) {
        self.workspace = workspace
        self.codexApplicationURL = codexApplicationURL
    }

    @discardableResult
    func openTask(id: String) -> Bool {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard let encoded = id.addingPercentEncoding(withAllowedCharacters: allowed), !encoded.isEmpty,
              let url = URL(string: "codex://threads/\(encoded)") else {
            return workspace.activateCodex(applicationURL: codexApplicationURL())
        }
        if workspace.applicationURL(for: url) != nil, workspace.open(url) { return true }
        return workspace.activateCodex(applicationURL: codexApplicationURL())
    }
}
