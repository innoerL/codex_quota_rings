import Foundation

private final class FakeWorkspace: CodexWorkspaceOpening {
    var handlerURL: URL?
    var openResult = false
    var activationResult = false
    private(set) var handlerQueries: [URL] = []
    private(set) var opened: [URL] = []
    private(set) var activationURLs: [URL?] = []

    func applicationURL(for url: URL) -> URL? { handlerQueries.append(url); return handlerURL }
    func open(_ url: URL) -> Bool { opened.append(url); return openResult }
    func activateCodex(applicationURL: URL?) -> Bool {
        activationURLs.append(applicationURL); return activationResult
    }
}

@main struct CodexNavigatorTests {
    static func main() {
        let app = URL(fileURLWithPath: "/Applications/Codex.app")
        let workspace = FakeWorkspace()
        workspace.handlerURL = app; workspace.openResult = true
        let navigator = CodexNavigator(workspace: workspace, codexApplicationURL: { app })
        precondition(navigator.openTask(id: "folder/你好 task?x=1"))
        let opened = workspace.opened[0].absoluteString
        precondition(opened == "codex://threads/folder%2F%E4%BD%A0%E5%A5%BD%20task%3Fx%3D1", "reserved and Unicode ID encoding: \(opened)")
        precondition(workspace.handlerQueries == workspace.opened && workspace.activationURLs.isEmpty)

        let noHandler = FakeWorkspace(); noHandler.activationResult = true
        precondition(CodexNavigator(workspace: noHandler, codexApplicationURL: { app }).openTask(id: "thread"))
        precondition(noHandler.opened.isEmpty && noHandler.activationURLs == [app])

        let failedOpen = FakeWorkspace()
        failedOpen.handlerURL = app; failedOpen.openResult = false; failedOpen.activationResult = true
        precondition(CodexNavigator(workspace: failedOpen, codexApplicationURL: { app }).openTask(id: "thread"))
        precondition(failedOpen.opened.count == 1 && failedOpen.activationURLs == [app])

        let absent = FakeWorkspace()
        precondition(!CodexNavigator(workspace: absent, codexApplicationURL: { nil }).openTask(id: "thread"))
        precondition(absent.activationURLs == [nil], "absent Codex should be a harmless no-op after one fallback attempt")

        print("PASS: encoded Codex task navigation and exact-app activation fallback")
    }
}
