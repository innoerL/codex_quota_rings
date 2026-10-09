import Foundation

enum HistoryRetention: String, CaseIterable {
    case session30Minutes
    case local24Hours
    case local7Days

    var duration: TimeInterval {
        switch self {
        case .session30Minutes: return 30 * 60
        case .local24Hours: return 24 * 60 * 60
        case .local7Days: return 7 * 24 * 60 * 60
        }
    }

    var persistsLocally: Bool { self != .session30Minutes }
}

struct QuotaHistorySample: Codable, Equatable {
    let timestamp: Date
    let fiveHourUsedPercent: Double?
    let weekUsedPercent: Double?
}

final class QuotaHistoryStore {
    private(set) var retention: HistoryRetention
    private(set) var persistenceError: String?
    private var storedSamples: [QuotaHistorySample] = []
    private let fileURL: URL
    private let now: () -> Date
    private let removeItem: (URL) throws -> Void

    init(retention: HistoryRetention, fileURL: URL, now: @escaping () -> Date = Date.init,
         removeItem: @escaping (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }) {
        self.retention = retention
        self.fileURL = fileURL
        self.now = now
        self.removeItem = removeItem
        if retention.persistsLocally {
            load()
        } else {
            removePersistedHistoryIfPresent()
        }
        storedSamples = normalize(storedSamples, at: now())
        if retention.persistsLocally, persistenceError == nil { persist() }
    }

    @discardableResult
    func record(_ snapshot: QuotaSnapshot) -> [QuotaHistorySample] {
        let current = now()
        guard let sample = normalizedSample(timestamp: snapshot.fetchedAt,
                                            fiveHour: snapshot.fiveHour?.clampedUsedPercent,
                                            week: snapshot.week?.clampedUsedPercent,
                                            at: current),
              !storedSamples.contains(where: { $0.timestamp == sample.timestamp }) else {
            storedSamples = normalize(storedSamples, at: current)
            if retention.persistsLocally { persist() }
            return storedSamples
        }
        storedSamples.append(sample)
        storedSamples = normalize(storedSamples, at: current)
        if retention.persistsLocally { persist() }
        return storedSamples
    }

    @discardableResult
    func setRetention(_ retention: HistoryRetention, at current: Date) -> [QuotaHistorySample] {
        self.retention = retention
        persistenceError = nil
        storedSamples = normalize(storedSamples, at: current)
        if retention.persistsLocally {
            persist()
        } else {
            do {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try removeItem(fileURL)
                }
            } catch {
                persistenceError = "无法删除本地趋势记录"
            }
        }
        return storedSamples
    }

    func samples(at current: Date) -> [QuotaHistorySample] {
        let normalized = normalize(storedSamples, at: current)
        let didPrune = normalized != storedSamples
        storedSamples = normalized
        if didPrune, retention.persistsLocally, FileManager.default.fileExists(atPath: fileURL.path) {
            persist()
        }
        return storedSamples
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            storedSamples = try JSONDecoder().decode([QuotaHistorySample].self, from: data)
        } catch {
            storedSamples = []
            persistenceError = "本地趋势记录已损坏，已重新开始记录"
            try? removeItem(fileURL)
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(storedSamples)
            try data.write(to: fileURL, options: .atomic)
            persistenceError = nil
        } catch {
            persistenceError = "无法保存本地趋势记录"
        }
    }

    private func removePersistedHistoryIfPresent() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            try removeItem(fileURL)
        } catch {
            persistenceError = "无法删除本地趋势记录"
        }
    }

    private func normalize(_ samples: [QuotaHistorySample], at current: Date) -> [QuotaHistorySample] {
        guard current.timeIntervalSince1970.isFinite else { return [] }
        let cutoff = current.addingTimeInterval(-retention.duration)
        var timestamps = Set<Date>()
        return samples.compactMap { sample in
            normalizedSample(timestamp: sample.timestamp,
                             fiveHour: sample.fiveHourUsedPercent,
                             week: sample.weekUsedPercent,
                             at: current)
        }.filter { $0.timestamp >= cutoff && timestamps.insert($0.timestamp).inserted }
         .sorted { $0.timestamp < $1.timestamp }
    }

    private func normalizedSample(timestamp: Date, fiveHour: Double?, week: Double?, at current: Date) -> QuotaHistorySample? {
        let seconds = timestamp.timeIntervalSince1970
        guard seconds.isFinite, timestamp <= current.addingTimeInterval(60) else { return nil }
        func value(_ candidate: Double?) -> Double? {
            guard let candidate, candidate.isFinite else { return nil }
            return min(100, max(0, candidate))
        }
        let five = value(fiveHour), weekly = value(week)
        guard five != nil || weekly != nil else { return nil }
        return QuotaHistorySample(timestamp: timestamp, fiveHourUsedPercent: five, weekUsedPercent: weekly)
    }
}
