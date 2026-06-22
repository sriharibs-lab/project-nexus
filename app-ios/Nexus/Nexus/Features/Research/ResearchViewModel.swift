import Combine
import Foundation

// MARK: - Source suggestion model

/// One AI-suggested source returned by POST /collections/research.
struct ResearchSource: Identifiable {
    let id = UUID()   // client-side only; backend has no row id for suggestions
    let index: Int
    let title: String
    let url: String
    let domain: String
    let rationale: String
    let contentType: String

    var isSelected: Bool = true   // default: user keeps all sources, can deselect
}

// MARK: - State machine

enum ResearchPhase: Equatable {
    case idle             // topic input visible
    case searching        // "Researching…" — Claude is thinking
    case reviewing        // sources arrived, user can deselect before confirming
    case confirming       // user tapped Confirm, ingest POSTs in flight
    case done(UUID)       // collection_id returned — navigate to collection
    case error(String)    // terminal error, user can retry
}

// MARK: - ViewModel

@MainActor
final class ResearchViewModel: ObservableObject {
    @Published var topic: String = ""
    @Published private(set) var phase: ResearchPhase = .idle
    @Published private(set) var sources: [ResearchSource] = []

    /// collection_id received in the SSE "done" event — set before transitioning to .done
    private var pendingCollectionId: UUID?

    var selectedSources: [ResearchSource] { sources.filter(\.isSelected) }
    var canConfirm: Bool { !selectedSources.isEmpty }

    // MARK: - Start research

    func startResearch() {
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        phase = .searching
        sources = []
        pendingCollectionId = nil

        Task {
            await streamResearch(topic: trimmed)
        }
    }

    // MARK: - Toggle source selection

    func toggleSource(id: UUID) {
        if let idx = sources.firstIndex(where: { $0.id == id }) {
            sources[idx].isSelected.toggle()
        }
    }

    // MARK: - Confirm selected sources → enqueue ingest

    func confirmSources() async {
        guard case .reviewing = phase else { return }
        guard let collectionId = pendingCollectionId else { return }
        let toIngest = selectedSources
        guard !toIngest.isEmpty else { return }

        phase = .confirming

        // Fire-and-forget: enqueue each selected source via POST /ingest.
        // Ingest is async on the backend — the collection is already created.
        // Failures are non-blocking: sources that fail to ingest will show
        // "Failed" status in the Sources tab; the collection is still valid.
        await withTaskGroup(of: Void.self) { group in
            for source in toIngest {
                group.addTask {
                    do {
                        _ = try await APIClient.shared.ingest(
                            url: source.url,
                            collectionId: collectionId,
                            contentType: source.contentType
                        )
                    } catch {
                        // Non-fatal: log and continue. Sources tab will show "Failed".
                    }
                }
            }
        }

        phase = .done(collectionId)
    }

    // MARK: - Retry

    func retry() {
        phase = .idle
        sources = []
        pendingCollectionId = nil
    }

    // MARK: - Private SSE consumer

    private func streamResearch(topic: String) async {
        let body = ResearchRequestBody(topic: topic, name: topic)

        do {
            try await APIClient.shared.streamSSE(.research, body: body) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let dict):
                    self.handleSSEEvent(dict)
                case .failure(let error):
                    Task { @MainActor in
                        self.phase = .error(error.localizedDescription)
                    }
                }
            }
        } catch {
            phase = .error("Connection failed. Check your network and try again.")
        }
    }

    private func handleSSEEvent(_ dict: [String: Any]) {
        guard let event = dict["event"] as? String else { return }

        switch event {
        case "searching":
            // Already in .searching phase — nothing to do except confirm we're alive.
            break

        case "source":
            guard let index = dict["index"] as? Int,
                  let sourceDict = dict["source"] as? [String: Any],
                  let title = sourceDict["title"] as? String,
                  let url = sourceDict["url"] as? String
            else { return }

            let source = ResearchSource(
                index: index,
                title: title,
                url: url,
                domain: sourceDict["domain"] as? String ?? "",
                rationale: sourceDict["rationale"] as? String ?? "",
                contentType: sourceDict["content_type"] as? String ?? "article"
            )
            sources.append(source)
            // Transition to reviewing on first source arrival so the list animates in
            if case .searching = phase { phase = .reviewing }

        case "done":
            guard let idStr = dict["collection_id"] as? String,
                  let collectionId = UUID(uuidString: idStr)
            else {
                phase = .error("Invalid response from server.")
                return
            }
            pendingCollectionId = collectionId
            // If sources arrived before done, we're already in .reviewing.
            // If no sources arrived (empty collection), go straight to done.
            if case .reviewing = phase {
                // Stay in reviewing — user must confirm.
            } else {
                phase = .done(collectionId)
            }

        case "error":
            let msg = dict["message"] as? String ?? "Something went wrong. Please try again."
            phase = .error(msg)

        default:
            break
        }
    }
}
