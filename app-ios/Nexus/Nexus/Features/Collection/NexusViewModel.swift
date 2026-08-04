import Combine
import Foundation

// MARK: - Chat message model

/// A single turn in the Nexus chat thread.
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    var content: String          // accumulates during streaming
    var citedSources: [CitedSource] = []
    var isStreaming: Bool = false

    enum Role { case user, assistant }
}

/// A source cited in an assistant response.
struct CitedSource: Identifiable, Hashable {
    let id = UUID()
    let index: Int      // [Source N]
    let title: String
    let url: String
}

// MARK: - ViewModel state

enum NexusPhase: Equatable {
    case idle           // waiting for user input
    case streaming      // SSE stream in progress — Echo pulse shown
    case error(String)  // terminal error — dismissible
}

// MARK: - NexusViewModel

/// Manages the Nexus tab AI chat for a single collection.
///
/// Responsibilities:
/// - Maintains the full client-side message history (displayed to user)
/// - Passes the last 6 turns to the API as `messages[]` (SPEC §9a Pillar 4 episodic memory)
/// - Streams SSE events from POST /v1/collections/{id}/chat
/// - Parses [Source N] citation tokens into CitedSource chips
/// - Tracks retrieved sources emitted in the "sources" SSE event
@MainActor
final class NexusViewModel: ObservableObject {
    let collection: NexusCollection

    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var phase: NexusPhase = .idle
    @Published private(set) var retrievedSources: [CitedSource] = []
    @Published var inputText: String = ""

    /// After the first user message, swap from default starter prompts to
    /// contextual ones (SPEC §5a AI Starter Prompts).
    @Published private(set) var hasReceivedFirstMessage: Bool = false

    // MARK: - Lifecycle

    init(collection: NexusCollection) {
        self.collection = collection
    }

    // MARK: - Public actions

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, phase == .idle else { return }

        inputText = ""
        hasReceivedFirstMessage = true

        let userMsg = ChatMessage(role: .user, content: text)
        messages.append(userMsg)

        Task { await streamChat(userText: text) }
    }

    func sendStarter(_ prompt: String) {
        inputText = prompt
        send()
    }

    func dismissError() {
        if case .error = phase { phase = .idle }
    }

    // MARK: - Private SSE consumer

    private func streamChat(userText: String) async {
        phase = .streaming
        retrievedSources = []

        // Build prior turns to pass as conversation history.
        // Keep last 6 complete turns (user + assistant pairs = up to 12 messages)
        // so we don't exceed context budget while satisfying SPEC §9a rolling window.
        let priorHistory = buildHistory()

        let body = ChatRequestBody(
            message: userText,
            messages: priorHistory
        )

        // Append a placeholder for the assistant response (streamed into it)
        var assistantMsg = ChatMessage(role: .assistant, content: "", isStreaming: true)
        let assistantIndex = messages.count
        messages.append(assistantMsg)

        do {
            try await APIClient.shared.streamSSE(.chat(collectionId: collection.id), body: body) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let dict):
                    Task { @MainActor in
                        self.handleSSEEvent(dict, assistantIndex: assistantIndex)
                    }
                case .failure(let error):
                    Task { @MainActor in
                        self.messages[assistantIndex].isStreaming = false
                        self.phase = .error(error.localizedDescription)
                    }
                }
            }
        } catch {
            messages[assistantIndex].content = ""
            messages[assistantIndex].isStreaming = false
            phase = .error("Connection failed. Check your network and try again.")
        }
    }

    private func handleSSEEvent(_ dict: [String: Any], assistantIndex: Int) {
        guard let type = dict["type"] as? String else { return }

        switch type {
        case "sources":
            // Parse the retrieved RAG sources emitted before the answer begins.
            // These become tappable citation chips when [Source N] appears in text.
            if let items = dict["items"] as? [[String: Any]] {
                retrievedSources = items.enumerated().compactMap { idx, item in
                    guard let title = item["title"] as? String,
                          let url   = item["url"]   as? String
                    else { return nil }
                    return CitedSource(index: idx + 1, title: title, url: url)
                }
            }

        case "chunk":
            guard let text = dict["text"] as? String else { return }
            messages[assistantIndex].content += text

        case "done":
            // Parse [Source N] tokens into CitedSource chips now that the full
            // text is available.
            messages[assistantIndex].citedSources = parseCitations(
                from: messages[assistantIndex].content
            )
            messages[assistantIndex].isStreaming = false
            phase = .idle

        case "error":
            let msg = dict["message"] as? String ?? "Something went wrong. Please try again."
            messages[assistantIndex].isStreaming = false
            phase = .error(msg)

        default:
            break
        }
    }

    // MARK: - Citation parsing

    /// Finds all [Source N] references in `text` and returns CitedSource values
    /// for each unique index that exists in retrievedSources.
    private func parseCitations(from text: String) -> [CitedSource] {
        // Match a whole citation token — [Source 4], [Source 4, Source 5],
        // [Sources 4, 5], [Source 4 and 5] — then pull every number out of it.
        guard let bracketRx = try? NSRegularExpression(pattern: #"\[Sources?[^\]]*\]"#),
              let numRx = try? NSRegularExpression(pattern: #"\d+"#) else { return [] }
        let ns = text as NSString
        var seen = Set<Int>()
        var result: [CitedSource] = []
        for m in bracketRx.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let token = ns.substring(with: m.range)
            let tns = token as NSString
            for nm in numRx.matches(in: token, range: NSRange(location: 0, length: tns.length)) {
                guard let idx = Int(tns.substring(with: nm.range)), !seen.contains(idx),
                      let src = retrievedSources.first(where: { $0.index == idx }) else { continue }
                seen.insert(idx)
                result.append(src)
            }
        }
        return result.sorted { $0.index < $1.index }   // stable chip order
    }

    // MARK: - History builder

    /// Returns the last 12 messages (6 user+assistant pairs) in Anthropic format.
    /// Excludes any currently-streaming assistant message.
    private func buildHistory() -> [[String: String]] {
        let completed = messages.filter { !$0.isStreaming && !$0.content.isEmpty }
        let recent = completed.suffix(12)
        return recent.map { msg in
            ["role": msg.role == .user ? "user" : "assistant",
             "content": msg.content]
        }
    }
}

// MARK: - Starter prompts (SPEC §5a)

extension NexusViewModel {
    /// Default prompts shown before the user types anything.
    /// 3 chips max in the empty state (design review 2026-07-10: 5+ was too many).
    static let defaultStarterPrompts: [String] = [
        "What are the key ideas across these sources?",
        "What should I read first?",
        "Summarize this collection in 3 bullet points",
    ]

    /// Contextual prompts shown after the first message.
    /// Kept shorter so they fit as tappable chips.
    static let contextualStarterPrompts: [String] = [
        "Dig deeper on the main theme",
        "What are the strongest counter-arguments?",
        "How do these sources connect?",
    ]

    var starterPrompts: [String] {
        hasReceivedFirstMessage
            ? Self.contextualStarterPrompts
            : Self.defaultStarterPrompts
    }
}

// MARK: - Request body

private struct ChatRequestBody: Encodable {
    let message: String
    let messages: [[String: String]]?
}
