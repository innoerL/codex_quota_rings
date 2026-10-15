import Foundation

@main struct QuotaHistoryTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("quota-history-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("quota-history.json")
        let base = Date(timeIntervalSince1970: 2_000_000_000)
        var clock = base

        func snapshot(_ offset: TimeInterval, _ five: Double?, _ week: Double?) -> QuotaSnapshot {
            QuotaSnapshot(fiveHour: five.map { QuotaWindow(usedPercent: $0, windowDurationMins: 300, resetsAt: nil) },
                          week: week.map { QuotaWindow(usedPercent: $0, windowDurationMins: 10080, resetsAt: nil) },
                          fetchedAt: base.addingTimeInterval(offset))
        }

        let session = QuotaHistoryStore(retention: .session30Minutes, fileURL: file, now: { clock })
        precondition(session.retention == .session30Minutes && !FileManager.default.fileExists(atPath: file.path))
        _ = session.record(snapshot(-1_900, 10, 20))
        _ = session.record(snapshot(-1_700, 20, 30))
        _ = session.record(snapshot(-1_700, 99, 99))
        _ = session.record(snapshot(-100, nil, 45))
        precondition(session.samples(at: clock).map(\.timestamp) == [base.addingTimeInterval(-1_700), base.addingTimeInterval(-100)])
        precondition(session.samples(at: clock).first?.fiveHourUsedPercent == 20, "duplicate timestamps keep the first finite sample")
        precondition(!FileManager.default.fileExists(atPath: file.path), "session history must stay memory-only")

        _ = session.record(snapshot(-200, -10, 140))
        let sorted = session.samples(at: clock)
        precondition(sorted.map(\.timestamp) == sorted.map(\.timestamp).sorted())
        precondition(sorted.first(where: { $0.timestamp == base.addingTimeInterval(-200) }) ==
                     QuotaHistorySample(timestamp: base.addingTimeInterval(-200), fiveHourUsedPercent: 0, weekUsedPercent: 100))
        _ = session.record(snapshot(61, 50, 50))
        _ = session.record(snapshot(-50, .infinity, .nan))
        precondition(session.samples(at: clock).count == 3, "future and fully non-finite samples must be rejected")

        _ = session.setRetention(.local5Hours, at: clock)
        precondition(FileManager.default.fileExists(atPath: file.path), "opt-in history must persist atomically")
        clock = base.addingTimeInterval(4 * 3_600)
        _ = session.record(snapshot(3 * 3_600, 40, 50))
        precondition(session.samples(at: clock).count == 4)
        clock = base.addingTimeInterval(6 * 3_600)
        precondition(session.samples(at: clock).map(\.timestamp) == [base.addingTimeInterval(3 * 3_600)])

        let reloaded = QuotaHistoryStore(retention: .local5Hours, fileURL: file, now: { clock })
        precondition(reloaded.samples(at: clock) == session.samples(at: clock), "persistent history must reload")
        clock = base.addingTimeInterval(9 * 3_600 + 1)
        precondition(reloaded.samples(at: clock).isEmpty, "five-hour retention must prune from the current clock")

        try Data("{broken".utf8).write(to: file)
        let recovered = QuotaHistoryStore(retention: .local5Hours, fileURL: file, now: { clock })
        precondition(recovered.samples(at: clock).isEmpty && !FileManager.default.fileExists(atPath: file.path))
        precondition(recovered.persistenceError != nil, "corrupt history recovery should be non-blocking and observable")

        clock = base
        _ = recovered.record(snapshot(0, 25, nil))
        precondition(FileManager.default.fileExists(atPath: file.path))
        _ = recovered.setRetention(.session30Minutes, at: clock)
        precondition(!FileManager.default.fileExists(atPath: file.path), "disabling persistence must delete its file")

        let pruneFile = root.appendingPathComponent("prune-history.json")
        var pruneClock = base
        let pruning = QuotaHistoryStore(retention: .local5Hours, fileURL: pruneFile, now: { pruneClock })
        _ = pruning.record(snapshot(0, 25, 35))
        pruneClock = base.addingTimeInterval(6 * 3_600)
        precondition(pruning.samples(at: pruneClock).isEmpty)
        let persistedAfterPrune = try JSONDecoder().decode([QuotaHistorySample].self, from: Data(contentsOf: pruneFile))
        precondition(persistedAfterPrune.isEmpty, "read-time pruning must also remove expired records from disk")

        let undeletableFile = root.appendingPathComponent("undeletable-history.json")
        try Data("[]".utf8).write(to: undeletableFile)
        let deletionFailure = QuotaHistoryStore(retention: .session30Minutes,
                                                fileURL: undeletableFile,
                                                now: { base },
                                                removeItem: { _ in throw CocoaError(.fileWriteNoPermission) })
        precondition(deletionFailure.persistenceError != nil)
        precondition(FileManager.default.fileExists(atPath: undeletableFile.path),
                     "failed opt-out deletion must remain visible instead of being silently ignored")

        print("PASS: private quota history retention, pruning, recovery, and deletion")
    }
}
