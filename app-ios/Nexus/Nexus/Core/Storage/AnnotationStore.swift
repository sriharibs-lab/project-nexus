import Foundation
import OSLog

// MARK: - AnnotationStore
//
// Persists Annotation records to FileManager JSON sidecars per item UUID.
// Pattern mirrors OfflineContentCache.swift — FileManager actor, no UserDefaults.
//
// Storage layout:
//   <Application Support>/NexusAnnotations/highlight_<item-uuid>.json
//
// Design decisions:
//   • FileManager JSON (not UserDefaults) — matches OfflineContentCache pattern;
//     unbounded growth of UserDefaults is undesirable for per-item highlight lists.
//   • Per-item sidecar file — surgical reads: opening an item only deserialises
//     its own highlights, not the full annotation corpus.
//   • ObservableObject + @Published — consistent with the rest of the codebase
//     (AuthManager, ItemDetailViewModel all use this pattern). @Observable macro
//     would require iOS 17+ and a deployment target audit before adoption.

private let logger = Logger(subsystem: "com.nexus.app", category: "AnnotationStore")

@MainActor
final class AnnotationStore: ObservableObject {

    // MARK: - Singleton

    static let shared = AnnotationStore()
    private init() {}

    // MARK: - In-memory cache: itemId → sorted annotation list
    //
    // @Published so any SwiftUI view observing this store via @ObservedObject
    // automatically re-renders when annotations are added or removed.

    @Published private var cache: [UUID: [Annotation]] = [:]

    // MARK: - Public API

    /// Returns all annotations for `itemId`, sorted by startOffset ascending.
    /// Loads from disk on first access; subsequent calls are memory-served.
    func annotations(for itemId: UUID) -> [Annotation] {
        if let cached = cache[itemId] { return cached }
        let loaded = loadFromDisk(itemId: itemId)
        cache[itemId] = loaded
        return loaded
    }

    /// Adds a new annotation and persists to disk.
    func add(_ annotation: Annotation) {
        var list = cache[annotation.itemId] ?? loadFromDisk(itemId: annotation.itemId)
        // Avoid duplicate inserts (e.g. retry after error)
        guard !list.contains(where: { $0.id == annotation.id }) else { return }
        list.append(annotation)
        list.sort { $0.startOffset < $1.startOffset }
        cache[annotation.itemId] = list
        saveToDisk(list, itemId: annotation.itemId)
    }

    /// Removes the annotation with `id` for `itemId` and persists.
    func remove(id: UUID, for itemId: UUID) {
        var list = cache[itemId] ?? loadFromDisk(itemId: itemId)
        list.removeAll { $0.id == id }
        cache[itemId] = list
        saveToDisk(list, itemId: itemId)
    }

    /// Removes all annotations for an item (e.g. on item deletion).
    func removeAll(for itemId: UUID) {
        cache[itemId] = []
        guard let url = try? fileURL(for: itemId) else { return }
        try? FileManager.default.removeItem(at: url)
        logger.debug("Removed all annotations for item \(itemId.uuidString)")
    }

    // MARK: - Disk helpers

    private var _storeDirectory: URL?

    private func storeDirectory() throws -> URL {
        if let dir = _storeDirectory { return dir }
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in:  .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent("NexusAnnotations", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        _storeDirectory = dir
        return dir
    }

    private func fileURL(for itemId: UUID) throws -> URL {
        try storeDirectory().appendingPathComponent("highlight_\(itemId.uuidString).json")
    }

    private func loadFromDisk(itemId: UUID) -> [Annotation] {
        guard let url = try? fileURL(for: itemId),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let annotations = try decoder.decode([Annotation].self, from: data)
            logger.debug("Loaded \(annotations.count) annotations for \(itemId.uuidString)")
            return annotations.sorted { $0.startOffset < $1.startOffset }
        } catch {
            logger.error("Failed to decode annotations for \(itemId.uuidString): \(error)")
            return []
        }
    }

    private func saveToDisk(_ annotations: [Annotation], itemId: UUID) {
        do {
            let url = try fileURL(for: itemId)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(annotations)
            try data.write(to: url, options: .atomicWrite)
            logger.debug("Saved \(annotations.count) annotations for \(itemId.uuidString)")
        } catch {
            logger.error("Failed to save annotations for \(itemId.uuidString): \(error)")
        }
    }
}
