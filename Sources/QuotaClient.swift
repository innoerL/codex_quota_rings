import Foundation

/// Owns one read-only app-server session. All mutable state lives on the main queue.
final class QuotaClient {
    var onChange: ((QuotaSnapshot?, String?) -> Void)?
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var buffer = Data()
    private var generation = UUID()
    private var initialized = false
    private var pendingID: Int?
    private var nextID = 1
    private var pollTimer: Timer?
    private var retryTimer: Timer?
    private var stopped = true
    private var snapshot: QuotaSnapshot?
    private let executableURL: URL?

    init(executableURL: URL? = nil) { self.executableURL = executableURL }

    func start() {
        guard stopped else { return }
        stopped = false
        connect()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.refresh() }
    }
    func stop() {
        stopped = true
        pollTimer?.invalidate(); pollTimer = nil
        retryTimer?.invalidate(); retryTimer = nil
        disconnect()
    }
    func refresh() {
        guard !stopped else { return }
        guard let process, process.isRunning, initialized else {
            if self.process == nil { retryTimer?.invalidate(); retryTimer = nil; connect() }
            return
        }
        guard pendingID == nil else { return }
        nextID += 1
        let id = nextID
        pendingID = id
        send(["id": id, "method": "account/rateLimits/read"])
        let token = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            guard let self, self.generation == token, self.pendingID == id else { return }
            self.fail("额度请求超时，将自动重连")
        }
    }
    private func connect() {
        guard !stopped, process == nil else { return }
        let candidates = [ProcessInfo.processInfo.environment["QUOTA_CODEX_PATH"],
                          "/usr/local/bin/codex", "/opt/homebrew/bin/codex",
                          "/Applications/Codex.app/Contents/Resources/codex"].compactMap { $0 }
        let executable = executableURL ?? candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map { URL(fileURLWithPath: $0) }
        guard let executable else { fail("找不到 Codex CLI，请安装 Codex 或设置 QUOTA_CODEX_PATH"); return }
        let child = Process()
        child.executableURL = executable
        child.arguments = ["app-server", "--listen", "stdio://"]
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:" + (environment["PATH"] ?? "")
        child.environment = environment
        // Avoid inheriting a project folder whose local configuration may differ.
        child.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        let stdin = Pipe(), stdout = Pipe()
        child.standardInput = stdin; child.standardOutput = stdout; child.standardError = FileHandle.nullDevice
        input = stdin.fileHandleForWriting; output = stdout.fileHandleForReading
        process = child; initialized = false; buffer.removeAll()
        let token = generation
        output?.readabilityHandler = { [weak self] handle in
            let bytes = handle.availableData
            DispatchQueue.main.async {
                guard let self, self.generation == token, !self.stopped else { return }
                if bytes.isEmpty { self.fail("额度连接已断开，将自动重连") }
                else { self.consume(bytes) }
            }
        }
        child.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.generation == token, !self.stopped else { return }
                self.fail("Codex 连接已结束，将自动重连")
            }
        }
        do {
            try child.run()
            send(["id": 1, "method": "initialize", "params": ["clientInfo": ["name": "quota_rings", "title": "Quota Rings", "version": "1.0.0"]]])
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
                guard let self, self.generation == token, !self.initialized else { return }
                self.fail("Codex 连接超时，将自动重连")
            }
        } catch { fail("无法启动 Codex 额度连接") }
    }
    private func send(_ message: [String: Any]) {
        guard let input else { return }
        do {
            var bytes = try JSONSerialization.data(withJSONObject: message)
            bytes.append(10)
            try input.write(contentsOf: bytes)
        } catch { fail("无法发送额度查询，将自动重连") }
    }
    private func consume(_ bytes: Data) {
        buffer.append(bytes)
        guard buffer.count <= 4 * 1024 * 1024 else { fail("额度响应过大，连接已重置"); return }
        while let newline = buffer.firstIndex(of: 10) {
            let line = buffer.subdata(in: buffer.startIndex..<newline)
            buffer.removeSubrange(buffer.startIndex...newline)
            guard !line.isEmpty,
                  let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
            if let id = object["id"] as? Int {
                if id == 1 {
                    guard object["result"] != nil else { fail("Codex 初始化失败，请检查本机登录"); return }
                    initialized = true
                    send(["method": "initialized"])
                    refresh()
                } else if id == pendingID {
                    pendingID = nil
                    guard let result = object["result"] as? [String: Any] else {
                        fail("无法读取额度，请检查网络和 Codex 登录状态"); return
                    }
                    accept(result)
                }
            } else if object["method"] as? String == "account/rateLimits/updated",
                      let result = object["params"] as? [String: Any] {
                accept(result)
            } else if object["method"] as? String == "account/updated" {
                snapshot = nil
                onChange?(nil, "账户已变化，正在重新读取")
                refresh()
            }
        }
    }
    private func accept(_ result: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: result)
            snapshot = try QuotaSnapshot.decode(data)
            onChange?(snapshot, nil)
        } catch { fail("额度数据格式异常，将自动重试") }
    }
    private func fail(_ message: String) {
        guard !stopped else { return }
        disconnect()
        onChange?(snapshot, message)
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in self?.connect() }
    }
    private func disconnect() {
        generation = UUID()
        initialized = false; pendingID = nil; nextID = 1
        output?.readabilityHandler = nil
        process?.terminationHandler = nil
        try? input?.close()
        if let process, process.isRunning { process.terminate() }
        try? output?.close()
        input = nil; output = nil; process = nil; buffer.removeAll()
    }
}
