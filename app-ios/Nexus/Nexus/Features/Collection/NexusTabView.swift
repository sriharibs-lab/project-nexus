import Combine
import SwiftUI
import UIKit

// MARK: - NexusTabView

/// The AI agent tab — the product's hero screen (SPEC §5a default landing).
///
/// Layout (top → bottom):
///   1. Framing paragraph — AI summary of the collection's scope
///   2. Chat thread — scrollable, user + assistant bubbles
///   3. Starter prompt chips — contextual after first turn
///   4. Composer — text field + send button
///
/// While the model is streaming:
///   - Echo-pulse wait state replaces the starter chips row
///   - The latest assistant bubble shows accumulated text in real time
///
/// Citation chips ([Source N]) appear beneath assistant responses as tappable pills
/// that open the source URL in Safari.
struct NexusTabView: View {
    let collection: NexusCollection
    /// Live items from CollectionViewModel (auto-polled while ingesting).
    /// collection.sourceCount is a stale navigation-time snapshot — research
    /// collections start at 0 and it never updates, which used to hide the
    /// entire chat UI (no composer, no chips) on fresh collections.
    var items: [Item] = []

    @StateObject private var vm: NexusViewModel
    /// Lifted from ChatComposer so the parent can dismiss the keyboard
    /// by setting this to false on any tap outside the composer.
    @FocusState private var composerFocused: Bool

    init(collection: NexusCollection, items: [Item] = []) {
        self.collection = collection
        self.items = items
        _vm = StateObject(wrappedValue: NexusViewModel(collection: collection))
    }

    // The composer and chips are ALWAYS visible (design review 2026-07-11).
    // Source availability is communicated inline in the thread area instead
    // of replacing the whole tab.
    var body: some View {
        chatUI
    }

    private var readyCount: Int { items.filter { $0.ingestStatus.isReady }.count }
    private var ingestingCount: Int {
        items.filter { $0.ingestStatus == .pending || $0.ingestStatus == .processing }.count
    }
    /// No sources at all → asking is pointless: chips hidden, composer dimmed
    /// (design review 2026-07-14). The sourceStatusStrip explains why.
    private var hasAnySources: Bool { !items.isEmpty || collection.sourceCount > 0 }

    // MARK: - Chat UI (shown when collection has sources)

    private var chatUI: some View {
        // The composer lives in a bottom safe-area inset so thread content
        // SCROLLS UNDERNEATH it — glass over flat page background reads as a
        // plain white card (device review 2026-07-15); glass needs content
        // behind it to exist.
        chatThread
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: NexusSpacing.sm) {
                    // Prompt chips carousel (after first exchange)
                    promptRow
                        .padding(.horizontal, NexusSpacing.sideGutter)
                    // Composer — receives the lifted FocusState binding so the
                    // parent can dismiss the keyboard from tap-outside.
                    ChatComposer(vm: vm, focused: $composerFocused)
                        .padding(.horizontal, NexusSpacing.sideGutter)
                        .opacity(hasAnySources ? 1 : 0.55)
                        .disabled(!hasAnySources)
                }
                .padding(.top, NexusSpacing.xs)
                .padding(.bottom, NexusSpacing.standard)
            }
        .background(NexusBackground())
        // Error banner overlay
        .overlay(alignment: .top) {
            if case .error(let msg) = vm.phase {
                ErrorBanner(message: msg) { vm.dismissError() }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(NexusAnimation.element, value: vm.phase == .idle)
    }

    // MARK: - Chat thread

    private var chatThread: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: NexusSpacing.md) {
                    if vm.messages.isEmpty {
                        // Empty state: hero (mark → framing → ASK → chips)
                        heroBlock
                            .padding(.top, NexusSpacing.lg)
                    } else {
                        // With history: framing stays as quiet context at top
                        Text(framingText)
                            .font(.system(size: 16.5, weight: .medium))
                            .kerning(-0.25)
                            .lineSpacing(5)
                            .foregroundColor(.Nexus.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, NexusSpacing.lg)
                    }

                    // Source availability — inline in the thread, never replacing
                    // the composer (design review 2026-07-11)
                    sourceStatusStrip

                    // Messages
                    ForEach(vm.messages) { msg in
                        MessageBubble(message: msg, retrievedSources: vm.retrievedSources)
                            .id(msg.id)
                    }

                    // Wait state — in-thread, after the last message (prototype)
                    if vm.phase == .streaming, vm.messages.last?.content.isEmpty != false {
                        EchoPulseView()
                            .frame(height: 44)
                    }

                    // Invisible anchor for auto-scroll
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, NexusSpacing.sideGutter)
                .padding(.bottom, NexusSpacing.sm)
            }
            // Drag-to-dismiss: keyboard slides down interactively as the user
            // scrolls up through the message history. Consistent with iOS system
            // patterns (Messages, Mail). Already used in OnboardingView.
            .scrollDismissesKeyboard(.interactively)
            // Tap-outside dismiss: plain gesture on the scroll area — chips and
            // buttons inside still win their own taps (never simultaneousGesture,
            // see 1F-004)
            .onTapGesture { composerFocused = false }
            .onChange(of: vm.messages.count) { _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            // Also scroll when text accumulates mid-stream
            .onChange(of: vm.messages.last?.content) { _ in
                withAnimation(.linear(duration: 0.1)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Source status strip (inline, thread area)

    @ViewBuilder
    private var sourceStatusStrip: some View {
        if items.isEmpty && collection.sourceCount == 0 {
            HStack(spacing: NexusSpacing.sm) {
                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.Nexus.muted)
                Text("No sources yet — add links in the Sources tab and I'll read them.")
                    .font(.Nexus.bodySmall)
                    .foregroundColor(.Nexus.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, NexusSpacing.md)
            .padding(.vertical, NexusSpacing.sm)
            .background(Color.Nexus.surface2.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else if ingestingCount > 0 {
            HStack(spacing: NexusSpacing.sm) {
                ProgressView().scaleEffect(0.7)
                Text(readyCount > 0
                     ? "\(readyCount) of \(items.count) ready — ask away, more arriving…"
                     : "Reading your sources — ready in a few seconds…")
                    .font(.Nexus.bodySmall)
                    .foregroundColor(.Nexus.muted)
            }
            .padding(.horizontal, NexusSpacing.md)
            .padding(.vertical, NexusSpacing.sm)
            .background(Color.Nexus.bloom.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Hero (empty state) — locked prototype spec (flows/qa Ask pane):
    // Echo mark top-left → framing as PLAIN TEXT (16.5/medium, relaxed
    // leading) → "ASK" overline → wrapping starter chips. No card, no label.

    private var framingText: String {
        if let f = collection.framingParagraph, !f.isEmpty { return f }
        let n = collection.sourceCount
        let countStr = n == 0 ? "sources" : (n == 1 ? "1 source" : "\(n) sources")
        return "This collection has \(countStr). Ask me anything about what you've saved here."
    }

    // Per-collection, AI-generated starter chips shown on creation; falls back to
    // the generic defaults for older collections that predate the feature (#D).
    private var heroStarters: [String] {
        if let q = collection.suggestedQuestions, !q.isEmpty { return q }
        return vm.starterPrompts
    }

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            EchoMark(color: Color.Nexus.ink, size: 27)

            Text(framingText)
                .font(.system(size: 16.5, weight: .medium))
                .kerning(-0.25)
                .lineSpacing(5)
                .foregroundColor(.Nexus.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            // Suggested questions only once the AI can actually answer from
            // processed sources — offering them while everything is still
            // "Reading…" invited questions it had to refuse (device 2026-10).
            if readyCount > 0 {
                Text("ASK")
                    .font(.Nexus.overline)
                    .foregroundColor(.Nexus.ghost)
                    .kerning(NexusKerning.wide)
                    .padding(.top, 28)

                StarterPromptsRow(prompts: heroStarters) { vm.sendStarter($0) }
                    .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Suggestion carousel (above composer, after first exchange only)
    //
    // Empty state has its chips in the hero; the wait pulse lives in-thread.

    @ViewBuilder
    private var promptRow: some View {
        // ONE suggestion system: the same contextual starters as the hero
        // (not a second, generic "Dig deeper…" set), and only when sources are
        // ready and nothing is streaming — fewer competing pills on screen.
        if !vm.messages.isEmpty, vm.phase != .streaming, readyCount > 0 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NexusSpacing.xs) {
                    ForEach(heroStarters, id: \.self) { prompt in
                        StarterChip(label: prompt, nowrap: true) { vm.sendStarter(prompt) }
                    }
                }
                .padding(.horizontal, NexusSpacing.sideGutter)
            }
            .padding(.horizontal, -NexusSpacing.sideGutter)
        }
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: ChatMessage
    let retrievedSources: [CitedSource]

    // Locked prototype spec (flows/qa):
    //  • user — quiet right-aligned pill: surface2 fill, hairline border,
    //    radius 18, 15pt ink, max 82% width. Never a loud accent bubble.
    //  • assistant — NO bubble: plain 15pt ink text, relaxed leading,
    //    citation chips below.
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user { Spacer(minLength: NexusSpacing.xxxl) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: NexusSpacing.xs) {
                if message.role == .user {
                    Text(strippedContent)
                        .font(.system(size: 15))
                        .kerning(-0.2)
                        .foregroundColor(.Nexus.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.Nexus.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.Nexus.accent.opacity(0.22), lineWidth: NexusBorder.hair)
                        )
                } else {
                    // Render markdown LIVE while streaming. The old per-token
                    // freeze came from recompiling regexes each token — the block
                    // parser now uses static compiled regexes, and inline() falls
                    // back to plain text on an unclosed ** mid-stream. So bold and
                    // bullets render as they arrive, no raw markdown flashes (#8).
                    AssistantMarkdown(content: strippedContent)
                }

                // While thinking, the in-thread EchoPulse is the wait indicator
                // (design review 2026-07-14: brand animation, not a cursor)

                // Citation chips beneath assistant response
                if message.role == .assistant && !message.citedSources.isEmpty {
                    CitationChipsRow(sources: message.citedSources)
                }
            }

            if message.role == .assistant { Spacer(minLength: NexusSpacing.xxxl) }
        }
        .animation(NexusAnimation.element, value: message.isStreaming)
    }

    // Strip citation tokens from the displayed text so the chips carry them
    // visually. Handles every form the model emits — [Source 4], [Source 4,
    // Source 5], [Sources 4, 5], [Source 4 and 5] — then cleans the punctuation
    // the removal leaves behind (empty "()", orphaned commas/spaces). Runs
    // unconditionally: raw tokens must never leak, even mid-stream or when no
    // chip resolved (device dogfood #B).
    private var strippedContent: String {
        var s = message.content
        // Only HORIZONTAL whitespace is ever collapsed — newlines carry the
        // markdown structure (headings, bullets, paragraphs). The old `\s{2,}`
        // flattened "\n\n" into a space and turned every answer into one run-on
        // paragraph with literal "##" in it (feedback 2026-10-09).
        let subs: [(String, String)] = [
            (#"[ \t]*\[Sources?[^\]]*\]"#, ""),  // any [Source ...] citation token
            (#"\([ \t]*[,;]?[ \t]*\)"#, ""),     // empty "()" / "( , )" left behind
            (#"[ \t]+([.,;:!?])"#, "$1"),        // space before punctuation
            (#"[ \t]{2,}"#, " "),                 // collapsed double spaces
            (#"\n{3,}"#, "\n\n"),                 // never more than one blank line
        ]
        for (pattern, template) in subs {
            guard let rx = try? NSRegularExpression(pattern: pattern) else { continue }
            s = rx.stringByReplacingMatches(
                in: s, range: NSRange(s.startIndex..., in: s), withTemplate: template
            )
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

}

// MARK: - Assistant markdown
//
// Claude's answers arrive as markdown (##, **, bullets). Text() renders only
// inline markdown — headings and lists leak through as raw symbols (review
// 2026-07-14). Lightweight block renderer: headings, bullets, numbered items,
// paragraphs; inline **bold**/*italic* via AttributedString per block.

struct AssistantMarkdown: View {
    let content: String

    private enum Block: Identifiable {
        case heading(String, level: Int)
        case bullet(String)
        case numbered(String, index: String)
        case paragraph(String)
        case rule
        case table(header: [String], rows: [[String]])

        var id: String {
            switch self {
            case .heading(let t, let l): return "h\(l):\(t)"
            case .bullet(let t): return "b:\(t)"
            case .numbered(let t, let i): return "n\(i):\(t)"
            case .paragraph(let t): return "p:\(t)"
            case .rule: return "hr"
            case .table(let h, let r): return "t:\(h.joined(separator: "|")):\(r.count)"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(blocks) { block in
                switch block {
                case .heading(let text, let level):
                    inline(text)
                        .font(.system(size: level <= 2 ? 16.5 : 15, weight: .semibold))
                        .kerning(-0.3)
                        .foregroundColor(.Nexus.ink)
                        .padding(.top, 4)
                case .bullet(let text):
                    HStack(alignment: .top, spacing: 9) {
                        Text("•")
                            .font(.system(size: 15))
                            .foregroundColor(.Nexus.faint)
                        inline(text)
                            .font(.system(size: 15))
                            .kerning(-0.2)
                            .lineSpacing(4)
                            .foregroundColor(.Nexus.ink)
                    }
                case .numbered(let text, let index):
                    HStack(alignment: .top, spacing: 9) {
                        Text("\(index).")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.Nexus.faint)
                        inline(text)
                            .font(.system(size: 15))
                            .kerning(-0.2)
                            .lineSpacing(4)
                            .foregroundColor(.Nexus.ink)
                    }
                case .paragraph(let text):
                    inline(text)
                        .font(.system(size: 15))
                        .kerning(-0.2)
                        .lineSpacing(6)
                        .foregroundColor(.Nexus.ink)
                case .rule:
                    Rectangle().fill(Color.Nexus.hair).frame(height: 1).padding(.vertical, 4)
                case .table(let header, let rows):
                    // Phones can't fit a real table; render each row as a
                    // compact card: first cell as the row label, the rest as
                    // "Header: value" lines. Never show raw pipes.
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(rows.indices, id: \.self) { r in
                            VStack(alignment: .leading, spacing: 3) {
                                if let first = rows[r].first {
                                    inline(first)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.Nexus.ink)
                                }
                                ForEach(Array(rows[r].dropFirst().enumerated()), id: \.offset) { c, cell in
                                    let h = header.count > c + 1 ? header[c + 1] : ""
                                    (Text(h.isEmpty ? "" : "\(h): ").font(.system(size: 13.5, weight: .medium)).foregroundColor(.Nexus.muted)
                                     + inline(cell).font(.system(size: 13.5)).foregroundColor(.Nexus.ink))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(Color.Nexus.surface2.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Inline markdown (bold/italic/links); falls back to plain text mid-stream
    /// when a `**` pair is still unclosed.
    private func inline(_ text: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attributed)
        }
        return Text(text)
    }

    // Compiled once — building regex literals inside the parse loop is
    // measurably expensive and this parser can run in scroll-critical paths.
    private static let headingRx = /(#{1,4})\s+(.+)/
    private static let bulletRx = /[-*•]\s+(.+)/
    private static let numberedRx = /(\d+)[.)]\s+(.+)/

    private var blocks: [Block] {
        var result: [Block] = []
        var paragraph: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            result.append(.paragraph(paragraph.joined(separator: " ")))
            paragraph = []
        }

        var tableHeader: [String]? = nil
        var tableRows: [[String]] = []
        func flushTable() {
            if let h = tableHeader, !tableRows.isEmpty { result.append(.table(header: h, rows: tableRows)) }
            else if let h = tableHeader { result.append(.paragraph(h.joined(separator: " · "))) }
            tableHeader = nil; tableRows = []
        }
        func tableCells(_ line: String) -> [String] {
            var s = Substring(line)
            if s.hasPrefix("|") { s = s.dropFirst() }
            if s.hasSuffix("|") { s = s.dropLast() }
            return s.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
        }

        for rawLine in content.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            // Markdown table rows: "| a | b |". The "|---|---|" separator is dropped.
            if line.hasPrefix("|") && line.count > 1 {
                flushParagraph()
                let cells = tableCells(line)
                if cells.allSatisfy({ $0.allSatisfy { $0 == "-" || $0 == ":" } && !$0.isEmpty }) { continue }
                if tableHeader == nil { tableHeader = cells } else { tableRows.append(cells) }
                continue
            } else if tableHeader != nil {
                flushTable()
            }
            if line.isEmpty {
                flushParagraph()
            } else if line.count >= 3 && line.allSatisfy({ $0 == "-" || $0 == "*" || $0 == "_" }) {
                flushParagraph()
                result.append(.rule)
            } else if let match = line.wholeMatch(of: Self.headingRx) {
                flushParagraph()
                result.append(.heading(String(match.2), level: match.1.count))
            } else if let match = line.wholeMatch(of: Self.bulletRx) {
                flushParagraph()
                result.append(.bullet(String(match.1)))
            } else if let match = line.wholeMatch(of: Self.numberedRx) {
                flushParagraph()
                result.append(.numbered(String(match.2), index: String(match.1)))
            } else {
                paragraph.append(line)
            }
        }
        flushTable()
        flushParagraph()
        return result
    }
}

// MARK: - Citation chips

private struct CitationChipsRow: View {
    let sources: [CitedSource]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: NexusSpacing.xs) {
                ForEach(sources) { src in
                    CitationChip(source: src)
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

struct CitationChip: View {
    let source: CitedSource

    @State private var isPressed = false

    var body: some View {
        Button {
            guard let url = URL(string: source.url) else { return }
            UIApplication.shared.open(url)
        } label: {
            HStack(spacing: 4) {
                Text("[\(source.index)]")
                    .font(.Nexus.overline)
                    .foregroundColor(.Nexus.accent)
                    .kerning(NexusKerning.normal)
                Text(source.title)
                    .font(.Nexus.overline)
                    .foregroundColor(.Nexus.muted)
                    .lineLimit(1)
                    .kerning(NexusKerning.normal)
            }
            .padding(.horizontal, NexusSpacing.sm)
            .padding(.vertical, 4)
            .background(Color.Nexus.bloom.opacity(0.4))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.Nexus.accent.opacity(0.22), lineWidth: NexusBorder.hair)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? NexusScale.pressLight : 1)
        .animation(NexusAnimation.press, value: isPressed)
        .onLongPressGesture(minimumDuration: 0, pressing: { p in isPressed = p }, perform: {})
    }
}

// MARK: - Echo-pulse wait state
//
// The Echo Ember mark, pulsing — the AI "thinking" / loading animation. Matches
// the static EchoMark (same geometry + gradients) so the splash never fades into
// a different-looking loader. Motion per BRAND.md §Echo pulse (1.8s loop): node
// breathes, inner/outer arcs pulse opacity+scale on staggered delays, and a
// ghost ripple expands. TimelineView drives the Canvas per-frame.
struct EchoPulseView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    private static let period: Double = 1.8

    var body: some View {
        if reduceMotion {
            EchoMark(size: 36)        // static mark when motion is reduced
        } else {
            TimelineView(.animation) { timeline in
                Canvas { ctx, size in Self.draw(&ctx, size, timeline.date, EmberPalette.current(scheme)) }
                    .frame(width: 36, height: 36)
            }
        }
    }

    /// Keyframe interpolation with smoothstep easing between stops.
    private static func kf(_ x: Double, _ stops: [(Double, Double)]) -> Double {
        let p = x - floor(x)
        for i in 0..<(stops.count - 1) {
            let (p0, v0) = stops[i]; let (p1, v1) = stops[i + 1]
            if p >= p0 && p <= p1 {
                let u = (p - p0) / max(p1 - p0, 1e-6)
                return v0 + (v1 - v0) * (u * u * (3 - 2 * u))
            }
        }
        return stops.last!.1
    }

    private static func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ date: Date, _ pal: EmberPalette) {
        let s = size.width / 48.0
        let t = date.timeIntervalSinceReferenceDate
        let p = (t / period).truncatingRemainder(dividingBy: 1)
        func shifted(_ delay: Double) -> Double {
            let v = (p - delay / period).truncatingRemainder(dividingBy: 1)
            return v < 0 ? v + 1 : v
        }

        var innerL = Path(); innerL.addArc(center: CGPoint(x: 26.05 * s, y: 24 * s), radius: 11 * s, startAngle: .degrees(226.6), endAngle: .degrees(133.4), clockwise: true)
        var innerR = Path(); innerR.addArc(center: CGPoint(x: 21.95 * s, y: 24 * s), radius: 11 * s, startAngle: .degrees(313.4), endAngle: .degrees(46.6), clockwise: false)
        var outerL = Path(); outerL.addArc(center: CGPoint(x: 23.298 * s, y: 24 * s), radius: 17.5 * s, startAngle: .degrees(236), endAngle: .degrees(124), clockwise: true)
        var outerR = Path(); outerR.addArc(center: CGPoint(x: 24.702 * s, y: 24 * s), radius: 17.5 * s, startAngle: .degrees(304), endAngle: .degrees(56), clockwise: false)

        let ember = GraphicsContext.Shading.linearGradient(
            Gradient(stops: [.init(color: pal.inner[0], location: 0), .init(color: pal.inner[1], location: 0.55), .init(color: pal.inner[2], location: 1)]),
            startPoint: CGPoint(x: 12 * s, y: 10 * s), endPoint: CGPoint(x: 36 * s, y: 38 * s))
        let outer = GraphicsContext.Shading.linearGradient(
            Gradient(stops: [.init(color: pal.outer[0], location: 0), .init(color: pal.outer[1], location: 1)]),
            startPoint: CGPoint(x: 10 * s, y: 8 * s), endPoint: CGPoint(x: 38 * s, y: 40 * s))
        let center = CGPoint(x: 24 * s, y: 24 * s)

        func layer(_ scale: Double, _ opacity: Double, _ draw: (inout GraphicsContext) -> Void) {
            ctx.drawLayer { l in
                l.opacity = opacity
                l.translateBy(x: center.x, y: center.y); l.scaleBy(x: scale, y: scale); l.translateBy(x: -center.x, y: -center.y)
                draw(&l)
            }
        }

        // Ghost ripple (behind) — expanding third pair.
        let pg = shifted(0.5)
        let ghostOp = kf(pg, [(0, 0), (0.4, 0.5), (0.8, 0), (1, 0)])
        if ghostOp > 0.01 {
            var gL = Path(); gL.addArc(center: CGPoint(x: 22.6 * s, y: 24 * s), radius: 21 * s, startAngle: .degrees(236), endAngle: .degrees(124), clockwise: true)
            var gR = Path(); gR.addArc(center: CGPoint(x: 25.4 * s, y: 24 * s), radius: 21 * s, startAngle: .degrees(304), endAngle: .degrees(56), clockwise: false)
            layer(kf(pg, [(0, 0.9), (1, 1.06)]), ghostOp) { l in
                l.stroke(gL, with: outer, style: StrokeStyle(lineWidth: 1.6 * s, lineCap: .round))
                l.stroke(gR, with: outer, style: StrokeStyle(lineWidth: 1.6 * s, lineCap: .round))
            }
        }

        // Outer arcs (delay .32), base opacity 0.6.
        let po = shifted(0.32)
        layer(kf(po, [(0, 0.94), (0.35, 1.04), (1, 1)]), 0.6 * kf(po, [(0, 0.35), (0.35, 1), (0.7, 0.5), (1, 0.35)])) { l in
            l.stroke(outerL, with: outer, style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round))
            l.stroke(outerR, with: outer, style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round))
        }

        // Inner arcs (delay .12).
        let pin = shifted(0.12)
        layer(kf(pin, [(0, 0.94), (0.35, 1.04), (1, 1)]), kf(pin, [(0, 0.35), (0.35, 1), (0.7, 0.5), (1, 0.35)])) { l in
            l.stroke(innerL, with: ember, style: StrokeStyle(lineWidth: 3.2 * s, lineCap: .round))
            l.stroke(innerR, with: ember, style: StrokeStyle(lineWidth: 3.2 * s, lineCap: .round))
        }

        // Pearl node — breathing.
        let dotR = 4.4 * s
        let node = Path(ellipseIn: CGRect(x: 24 * s - dotR, y: 24 * s - dotR, width: dotR * 2, height: dotR * 2))
        let pearl = GraphicsContext.Shading.radialGradient(
            Gradient(stops: [.init(color: pal.pearl[0], location: 0), .init(color: pal.pearl[1], location: 0.45), .init(color: pal.pearl[2], location: 1)]),
            center: CGPoint(x: 22.68 * s, y: 22.24 * s), startRadius: 0, endRadius: 6.6 * s)
        layer(kf(p, [(0, 1), (0.3, 1.22), (0.6, 0.94), (1, 1)]), 1) { l in
            l.fill(node, with: pearl)
            let hl = Path(ellipseIn: CGRect(x: (22.7 - 1.4) * s, y: (22.5 - 0.9) * s, width: 2.8 * s, height: 1.8 * s))
            l.fill(hl, with: .color(.white.opacity(0.75)))
        }
    }
}

// MARK: - Starter prompts (wrapping pills, per prototype /flows/qa)
//
// Prototype spec: chips wrap left-aligned as full-question pills (13.5/500,
// surface bg, hairline border) — never a truncating horizontal scroll row.

private struct StarterPromptsRow: View {
    let prompts: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.xs) {
            ForEach(prompts, id: \.self) { prompt in
                StarterChip(label: prompt) { onSelect(prompt) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StarterChip: View {
    let label: String
    var nowrap: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13.5, weight: .medium))
                .kerning(-0.15)
                .foregroundColor(.Nexus.ink)
                .multilineTextAlignment(.leading)
                .lineLimit(nowrap ? 1 : nil)
                .fixedSize(horizontal: nowrap, vertical: true)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(Color.Nexus.cardBackground)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.Nexus.border, lineWidth: NexusBorder.hair))
        }
        // ButtonStyle press — a zero-duration long-press gesture here would
        // steal the tap (same class as the HomeView card bug, 2026-07-11)
        .buttonStyle(PressableCardStyle())
    }
}

// MARK: - Composer

private struct ChatComposer: View {
    @ObservedObject var vm: NexusViewModel
    /// Bound to NexusTabView's @FocusState so the parent can dismiss the
    /// keyboard by setting composerFocused = false from a tap-outside gesture.
    var focused: FocusState<Bool>.Binding

    @StateObject private var speech = SpeechRecognizer()
    @State private var dictating = false
    @State private var baseText = ""

    private var canSend: Bool {
        !vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && vm.phase == .idle
    }

    /// Notion pattern (review 2026-07-14): resting = one-line oval; on focus
    /// the box GROWS into a taller glass card with a send row beneath.
    ///
    /// CRITICAL: this is ONE view tree that morphs — never an if/else swap
    /// between two layouts. The swap gave the freshly-focused TextField a new
    /// identity, destroying first responder the moment you tapped ("can't
    /// type into the chat box", 2026-07-15). The TextField below exists in
    /// exactly one place; only spacing, shape, and the send row animate.
    private var isExpanded: Bool { focused.wrappedValue || !vm.inputText.isEmpty || dictating }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? NexusSpacing.sm : 0) {
            HStack(alignment: .bottom, spacing: NexusSpacing.sm) {
                // THE text field — single identity, always present
                ZStack(alignment: .leading) {
                    if vm.inputText.isEmpty {
                        Text("Ask about \"\(vm.collection.name)\"…")
                            .font(.Nexus.bodySmall)
                            .foregroundColor(.Nexus.ghost)
                            .padding(.horizontal, 6)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $vm.inputText, axis: .vertical)
                        .font(.Nexus.bodySmall)
                        .foregroundColor(.Nexus.ink)
                        .focused(focused)
                        .lineLimit(1...6)
                        .submitLabel(.send)
                        .onSubmit {
                            if canSend { vm.send(); focused.wrappedValue = false }
                        }
                        .padding(.horizontal, 6)
                }
                .padding(.horizontal, NexusSpacing.sm)
                .padding(.vertical, NexusSpacing.sm + 2)

                // Waveform sits inline while resting; drops to the send row when expanded
                if !isExpanded {
                    waveformCircle
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }

            if isExpanded {
                if dictating {
                    DictationBar(speech: speech, onCancel: cancelDictation, onConfirm: confirmDictation)
                        .frame(height: 38)
                        .transition(.opacity)
                } else {
                    HStack(spacing: NexusSpacing.sm) {
                        waveformCircle
                        Spacer()
                        Button {
                            if canSend { vm.send(); focused.wrappedValue = false }
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 38, height: 38)
                                // Plum: sending to Nexus is an AI moment — the one
                                // accent belongs here (matches FRE create + link-sheet
                                // Save). Ink is reserved for the audio glyph.
                                .background(canSend ? Color.Nexus.accent : Color.Nexus.ghost)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSend)
                        .animation(NexusAnimation.element, value: canSend)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .padding(isExpanded ? NexusSpacing.md : NexusSpacing.sm)
        .background(composerBackdrop)
        .overlay(
            RoundedRectangle(cornerRadius: isExpanded ? 26 : 30, style: .continuous)
                .stroke(Color.Nexus.border, lineWidth: NexusBorder.hair)
        )
        .shadow(color: .black.opacity(isExpanded ? 0.08 : 0.04), radius: isExpanded ? 16 : 8, y: isExpanded ? 4 : 2)
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: isExpanded)
        .onChange(of: speech.transcript) { _, t in
            guard dictating else { return }
            let sep = baseText.isEmpty ? "" : " "
            vm.inputText = t.isEmpty ? baseText : baseText + sep + t
        }
    }

    // Liquid Glass backdrop when expanded (floating layer, DESIGN_LANGUAGE §3);
    // solid card at rest. No explicit fill under glass (defeats it, 2026-07-11).
    @ViewBuilder
    private var composerBackdrop: some View {
        if isExpanded {
            if #available(iOS 26.0, *) {
                Color.clear.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        } else {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.Nexus.cardBackground)
        }
    }

    // Functional voice dictation (Speech framework) — was a decorative waveform.
    private var waveformCircle: some View {
        MicCircle(diameter: 36) { startDictation() }
    }

    private func startDictation() {
        Task {
            guard await speech.requestAuthorization() else { return }
            baseText = vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            focused.wrappedValue = false
            Haptics.impact(.medium)
            withAnimation(NexusAnimation.element) { dictating = true }
            speech.start()
        }
    }

    private func confirmDictation() {
        speech.stop()
        withAnimation(NexusAnimation.element) { dictating = false }
    }

    private func cancelDictation() {
        speech.cancel()
        vm.inputText = baseText
        withAnimation(NexusAnimation.element) { dictating = false }
    }
}

// MARK: - Error banner

private struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: NexusSpacing.sm) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#C0392B"))

            Text(message)
                .font(.Nexus.bodySmall)
                .foregroundColor(.Nexus.ink)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.Nexus.ghost)
            }
        }
        .padding(.horizontal, NexusSpacing.standard)
        .padding(.vertical, NexusSpacing.sm + 2)
        .background(Color.Nexus.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.base))
        .overlay(
            RoundedRectangle(cornerRadius: NexusRadius.base)
                .stroke(Color(hex: "#C0392B").opacity(0.2), lineWidth: NexusBorder.base)
        )
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        .padding(.horizontal, NexusSpacing.sideGutter)
        .padding(.top, NexusSpacing.sm)
    }
}
