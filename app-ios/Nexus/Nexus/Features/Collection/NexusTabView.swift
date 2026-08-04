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

            // Suggested questions only make sense once there is something to ask about
            if hasAnySources {
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
        if !vm.messages.isEmpty, vm.phase != .streaming {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NexusSpacing.xs) {
                    ForEach(vm.starterPrompts, id: \.self) { prompt in
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
        let subs: [(String, String)] = [
            (#"\s*\[Sources?[^\]]*\]"#, ""),   // any [Source ...] citation token
            (#"\(\s*[,;]?\s*\)"#, ""),          // empty "()" / "( , )" left behind
            (#"\s+([.,;:!?])"#, "$1"),          // space before punctuation
            (#"\s{2,}"#, " "),                   // collapsed double spaces
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

        var id: String {
            switch self {
            case .heading(let t, let l): return "h\(l):\(t)"
            case .bullet(let t): return "b:\(t)"
            case .numbered(let t, let i): return "n\(i):\(t)"
            case .paragraph(let t): return "p:\(t)"
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

        for rawLine in content.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flushParagraph()
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
// Two concentric ring pairs animate outward from a small pulsing center node
// while the AI is generating a response. Radius and opacity animate in sequence.
// Uses Canvas for performance — no view allocation per frame.

// The brand mark broadcasting: the Echo arc pairs ripple outward from the
// center node — two staggered generations, 1.7s loop (design handoff §motion).
// TimelineView drives the Canvas per-frame; withAnimation on @State does
// NOTHING for Canvas (it doesn't interpolate) — the old version rendered a
// static dot + "Nexus is thinking…" label (bug 2026-07-15). No text: the
// mark itself is the wait state.
struct EchoPulseView: View {
    private static let period: Double = 1.7

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let cx = size.width / 2
                let cy = size.height / 2

                // Two staggered ripple generations of the mark's arc pairs
                for generation in 0..<2 {
                    let phase = ((t / Self.period) + Double(generation) * 0.5)
                        .truncatingRemainder(dividingBy: 1)
                    let radius = 5.5 + phase * 10.5
                    let alpha = (1 - phase) * (generation == 0 ? 0.6 : 0.42)

                    for side in [1.0, -1.0] {
                        let mid: Double = side > 0 ? 0 : 180
                        var arc = Path()
                        arc.addArc(
                            center: CGPoint(x: cx, y: cy),
                            radius: radius,
                            startAngle: .degrees(mid - 38),
                            endAngle: .degrees(mid + 38),
                            clockwise: false
                        )
                        ctx.stroke(
                            arc,
                            with: .color(.Nexus.accent.opacity(alpha)),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                    }
                }

                // Center node — gentle breathing
                let dotR = 3.4 + 0.7 * sin(t * 2 * .pi / 0.95)
                var dot = Path()
                dot.addEllipse(in: CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2))
                ctx.fill(dot, with: .color(.Nexus.accent.opacity(0.9)))
            }
            .frame(width: 36, height: 36)
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
    private var isExpanded: Bool { focused.wrappedValue || !vm.inputText.isEmpty }

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
                            if canSend { vm.send() }
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
                HStack(spacing: NexusSpacing.sm) {
                    waveformCircle
                    Spacer()
                    Button {
                        if canSend { vm.send() }
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
        .padding(isExpanded ? NexusSpacing.md : NexusSpacing.sm)
        .background(composerBackdrop)
        .overlay(
            RoundedRectangle(cornerRadius: isExpanded ? 26 : 30, style: .continuous)
                .stroke(Color.Nexus.border, lineWidth: NexusBorder.hair)
        )
        .shadow(color: .black.opacity(isExpanded ? 0.08 : 0.04), radius: isExpanded ? 16 : 8, y: isExpanded ? 4 : 2)
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: isExpanded)
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

    private var waveformCircle: some View {
        Image(systemName: "waveform")
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.Nexus.faint)
            .frame(width: 36, height: 36)
            .background(Color.Nexus.surface2)
            .clipShape(Circle())
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
