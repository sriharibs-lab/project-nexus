import Foundation
import OSLog

// MARK: - OfflineContentCache
//
// Persists article raw_content to FileManager so the reader works without a
// network connection after first open.
//
// Storage layout:
//   <Application Support>/NexusOfflineCache/<item-uuid>.txt
//
// Design choices:
//   • FileManager (not UserDefaults) — raw_content can be 50-200 KB per article;
//     UserDefaults is not designed for bulk text and blocks the main thread on
//     serialisation. FileManager writes on a background actor.
//   • Plain UTF-8 text files — no serialisation overhead, readable in Console.app
//     for debugging, trivially deleted by clearing Application Support.
//   • In-memory LRU of 50 entries (UUID -> String) avoids repeated disk reads
//     during a session while keeping memory bounded.
//   • Maximum on-disk cache: 100 files. Oldest-modified files are evicted first
//     when the cap is exceeded. Keeps the cache under ~20 MB for typical content.

private let logger = Logger(subsystem: "com.nexus.app", category: "OfflineContentCache")

/// Thread-safe offline cache for article raw_content.
/// All reads / writes happen on a background actor; callers safely await from MainActor.
actor OfflineContentCache {

    // MARK: - Singleton

    static let shared = OfflineContentCache()
    private init() {}

    // MARK: - Constants

    private let maxDiskEntries = 100
    private let maxMemoryEntries = 50

    // MARK: - In-memory LRU (insertion-order list + dict for O(1) lookup)

    private var memoryOrder: [UUID] = []     // front = oldest, back = most-recent
    private var memoryStore: [UUID: String] = [:]

    // MARK: - Cache directory (lazy)

    private var _cacheDirectory: URL?

    private func cacheDirectory() throws -> URL {
        if let dir = _cacheDirectory { return dir }
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in:  .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent("NexusOfflineCache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        _cacheDirectory = dir
        return dir
    }

    private func fileURL(for itemId: UUID) throws -> URL {
        try cacheDirectory().appendingPathComponent("\(itemId.uuidString).txt")
    }

    // MARK: - Maintenance (Settings → Data)

    /// Total bytes on disk for cached article text.
    func diskUsageBytes() -> Int {
        guard let dir = try? cacheDirectory(),
              let files = try? FileManager.default.contentsOfDirectory(
                  at: dir, includingPropertiesForKeys: [.fileSizeKey]
              )
        else { return 0 }
        return files.reduce(0) { total, url in
            total + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    /// Remove every cached entry (memory + disk).
    func clearAll() {
        memoryStore.removeAll()
        memoryOrder.removeAll()
        guard let dir = try? cacheDirectory(),
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        else { return }
        for url in files {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Read

    /// Returns cached raw_content for `itemId`, checking memory then disk.
    /// Returns `nil` when not cached — caller should fetch from API.
    func rawContent(for itemId: UUID) -> String? {
        // 1. Memory hit
        if let hit = memoryStore[itemId] {
            promoteInMemory(itemId)
            return hit
        }

        // 2. Disk hit
        guard let url = try? fileURL(for: itemId),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        logger.debug("Cache disk-hit: \(itemId.uuidString)")
        insertIntoMemory(itemId, text: text)
        return text
    }

    // MARK: - Write

    /// Persists `text` for `itemId` to both memory and disk.
    /// Silently no-ops on disk errors — reader still works, just won't be cached next time.
    func store(rawContent text: String, for itemId: UUID) {
        // Memory
        insertIntoMemory(itemId, text: text)

        // Disk
        do {
            let url = try fileURL(for: itemId)
            if FileManager.default.fileExists(atPath: url.path) {
                // Already written — bump modification date so it won't be evicted first.
                try FileManager.default.setAttributes(
                    [.modificationDate: Date()],
                    ofItemAtPath: url.path
                )
                return
            }
            try text.write(to: url, atomically: true, encoding: .utf8)
            logger.debug("Cache stored: \(itemId.uuidString) (\(text.utf8.count) bytes)")
            try evictOldestIfNeeded()
        } catch {
            logger.error("Cache write failed for \(itemId.uuidString): \(error.localizedDescription)")
        }
    }

    // MARK: - Eviction

    private func evictOldestIfNeeded() throws {
        let dir = try cacheDirectory()
        let urls = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        )
        guard urls.count > maxDiskEntries else { return }

        let sorted = urls.sorted {
            let d1 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let d2 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return d1 < d2
        }
        let evictCount = urls.count - maxDiskEntries
        for url in sorted.prefix(evictCount) {
            try? FileManager.default.removeItem(at: url)
            logger.debug("Cache evicted: \(url.lastPathComponent)")
        }
    }

    // MARK: - Memory LRU helpers

    private func insertIntoMemory(_ id: UUID, text: String) {
        if memoryStore[id] != nil {
            // Already present — promote and update value.
            promoteInMemory(id)
            memoryStore[id] = text
            return
        }
        if memoryOrder.count >= maxMemoryEntries, let oldest = memoryOrder.first {
            memoryOrder.removeFirst()
            memoryStore.removeValue(forKey: oldest)
        }
        memoryOrder.append(id)
        memoryStore[id] = text
    }

    private func promoteInMemory(_ id: UUID) {
        memoryOrder.removeAll { $0 == id }
        memoryOrder.append(id)
    }
}
