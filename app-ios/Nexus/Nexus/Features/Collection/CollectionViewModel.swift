import Combine
import Foundation

@MainActor
final class CollectionViewModel: ObservableObject {
    let collection: NexusCollection

    @Published private(set) var items: [Item] = []
    @Published private(set) var isLoading = false
    @Published var error: APIError?
    /// Non-nil when a swipe-to-delete API call fails; shown as an alert in CollectionView.
    @Published var deleteError: APIError?

    // MARK: - Auto-polling

    /// Interval between ingest-status poll ticks, in seconds.
    private let pollInterval: TimeInterval = 4

    /// Active polling task — nil when all items are in a terminal state.
    private var pollTask: Task<Void, Never>?

    /// Ingest statuses that indicate a source is still being processed.
    /// Polling continues as long as at least one item has one of these statuses.
    private static let activeStatuses: Set<Item.IngestStatus> = [.pending, .processing]

    /// Returns true when any item still needs the backend to finish work on it.
    private var hasActiveItems: Bool {
        items.contains { Self.activeStatuses.contains($0.ingestStatus) }
    }

    init(collection: NexusCollection) {
        self.collection = collection
    }

    deinit {
        pollTask?.cancel()
    }

    // MARK: - Load sources

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await APIClient.shared.fetchItems(in: collection.id)
            items = fetched
            startPollingIfNeeded()
        } catch let e as APIError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    // MARK: - Delete a source (swipe-to-delete)
    //
    // Optimistic removal: strip the item from the local list immediately so the
    // UI responds at once (no waiting for the network). If the API call fails,
    // re-insert the item at its original position and surface deleteError to
    // CollectionView, which shows an alert.
    //
    // This avoids a janky "item reappears" flash on success while still giving
    // the user accurate feedback on failure.

    func delete(item: Item) async {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }

        // Optimistic removal
        items.remove(at: idx)

        do {
            try await APIClient.shared.deleteItem(id: item.id, in: collection.id)
        } catch let e as APIError {
            // Roll back: re-insert at original position
            items.insert(item, at: min(idx, items.count))
            deleteError = e
        } catch {
            items.insert(item, at: min(idx, items.count))
            deleteError = .networkError(error)
        }
    }

    // MARK: - Auto-polling (private)
    //
    // Polling starts automatically after each successful load() when at least one
    // item is still pending or processing. Every 4 seconds it fetches the full
    // items list and merges the results in-place: existing items are updated by ID
    // so the list order is preserved and in-progress UI state (scroll position,
    // pressed state) is not disrupted.
    //
    // The poll loop exits as soon as every item reaches a terminal status
    // (completed or failed). It also exits on cancellation (deinit) or if the
    // network call throws — errors during polling are silent because load()
    // already surfaced any initial error, and a transient poll failure should not
    // interrupt the user.
    //
    // Only one polling task runs at a time. If load() is called while polling is
    // already active (e.g. pull-to-refresh), the old task is cancelled first so
    // the fresh results from load() become the new baseline.

    private func startPollingIfNeeded() {
        // Cancel any existing poll so load() results become the authoritative baseline.
        pollTask?.cancel()
        pollTask = nil

        guard hasActiveItems else { return }

        pollTask = Task { [weak self] in
            guard let self else { return }
            // The first poll fires after one full interval — the initial load()
            // already has fresh data.
            do {
                try await Task.sleep(nanoseconds: UInt64(self.pollInterval * 1_000_000_000))
            } catch {
                return // Cancelled
            }

            while !Task.isCancelled {
                await self.pollOnce()

                // Stop the loop once all items have reached a terminal state.
                if !self.hasActiveItems { break }

                do {
                    try await Task.sleep(nanoseconds: UInt64(self.pollInterval * 1_000_000_000))
                } catch {
                    break // Cancelled
                }
            }
        }
    }

    /// Fetches the current items list and merges updates in-place by ID.
    /// New items (added by another client session) are appended at the end.
    /// Items that no longer appear in the server response are not removed — they
    /// may be in the process of being optimistically deleted on this device.
    private func pollOnce() async {
        do {
            let fetched = try await APIClient.shared.fetchItems(in: collection.id)
            mergeItems(fetched)
        } catch {
            // Silent: a transient poll error should not surface to the user.
            // The next tick will retry automatically.
        }
    }

    /// Merges `fetched` into the current `items` array.
    ///
    /// - Items already in the list are updated in-place (status, title, summary,
    ///   tags etc.) so the view redraws individual rows without a full-list reload.
    /// - Items in `fetched` that are not yet in the local list are appended
    ///   (handles the case where a background ingest creates a new item).
    /// - Items currently in the local list but absent from `fetched` are kept
    ///   (they may be mid-optimistic-delete; the delete call will clean them up).
    private func mergeItems(_ fetched: [Item]) {
        var updated = items
        var fetchedById: [UUID: Item] = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })

        // Update existing entries in place
        for i in updated.indices {
            if let fresh = fetchedById[updated[i].id] {
                updated[i] = fresh
                fetchedById.removeValue(forKey: fresh.id)
            }
        }

        // Append genuinely new items (not already in the local list)
        let newItems = fetched.filter { fetchedById[$0.id] != nil }
        updated.append(contentsOf: newItems)

        items = updated
    }
}
