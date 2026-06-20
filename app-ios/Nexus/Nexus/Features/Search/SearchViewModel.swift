import Combine
import Foundation

// MARK: - Search state

enum SearchState {
    case idle          // no query typed yet
    case searching     // request in flight
    case results([SearchResultItem])  // response received
    case empty         // query returned 0 results
    case failed(String)
}

// MARK: - SearchViewModel

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var state: SearchState = .idle
    @Published private(set) var embeddingAvailable: Bool = false

    // Debounce: wait 400ms after last keystroke before firing the request.
    // This avoids hammering the backend on every character and keeps latency
    // perception snappy (user sees results appear ~400ms after they stop typing).
    private var debounceTask: Task<Void, Never>?
    private let debounceDelay: Duration = .milliseconds(400)

    private let minQueryLength = 2  // don't search for single characters

    // MARK: - Public API

    func onQueryChange(_ newQuery: String) {
        debounceTask?.cancel()

        let trimmed = newQuery.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            state = .idle
            return
        }

        if trimmed.count < minQueryLength {
            // Don't trigger yet — but don't show error either
            return
        }

        debounceTask = Task {
            try? await Task.sleep(for: debounceDelay)
            guard !Task.isCancelled else { return }
            await performSearch(query: trimmed)
        }
    }

    func clearSearch() {
        debounceTask?.cancel()
        query = ""
        state = .idle
    }

    // MARK: - Private

    private func performSearch(query: String) async {
        state = .searching

        do {
            let response = try await APIClient.shared.search(query: query)
            embeddingAvailable = response.embeddingAvailable

            if response.results.isEmpty {
                state = .empty
            } else {
                state = .results(response.results)
            }
        } catch let e as APIError {
            state = .failed(e.errorDescription ?? "Search failed.")
        } catch {
            state = .failed("Search failed. Please try again.")
        }
    }
}
