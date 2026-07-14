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

    // MARK: - Chat UI (shown when collection has sources)

    private var chatUI: some View {
        VStack(spacing: 0) {
            // Chat thread fills available space
            chatThread
            // Prompt chips or Echo pulse
            promptRow
                .padding(.horizontal, NexusSpacing.sideGutter)
                .padding(.bottom, NexusSpacing.sm)
            // Composer — receives the lifted FocusState binding so the parent
            // can dismiss the keyboard by flipping composerFocused = false.
            ChatComposer(vm: vm, focused: $composerFocused)
                .padding(.horizontal, NexusSpacing.sideGutter)
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
                     ? "\(readyCount) of \(items.count) sources ready — more arriving…"
                     : "Reading your sources…")
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

            Text("ASK")
                .font(.Nexus.overline)
                .foregroundColor(.Nexus.ghost)
                .kerning(NexusKerning.wide)
                .padding(.top, 28)

            StarterPromptsRow(prompts: vm.starterPrompts) { vm.sendStarter($0) }
                .padding(.top, 12)
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
                        .background(Color.Nexus.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.Nexus.hair, lineWidth: NexusBorder.hair)
                        )
                } else {
                    Text(strippedContent)
                        .font(.system(size: 15))
                        .kerning(-0.2)
                        .lineSpacing(6)
                        .foregroundColor(.Nexus.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Streaming cursor
                if message.isStreaming {
                    StreamingCursor()
                }

                // Citation chips beneath assistant response
                if message.role == .assistant && !message.citedSources.isEmpty {
                    CitationChipsRow(sources: message.citedSources)
                }
            }

            if message.role == .assistant { Spacer(minLength: NexusSpacing.xxxl) }
        }
        .animation(NexusAnimation.element, value: message.isStreaming)
    }

    // Strip [Source N] tokens from displayed text so chips handle them visually
    private var strippedContent: String {
        guard !message.citedSources.isEmpty else { return message.content }
        guard let regex = try? NSRegularExpression(pattern: #"\[Source \d+\]"#) else {
            return message.content
        }
        let range = NSRange(message.content.startIndex..., in: message.content)
        return regex.stringByReplacingMatches(
            in: message.content,
            range: range,
            withTemplate: ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

}

// MARK: - Streaming cursor

private struct StreamingCursor: View {
    @State private var opacity: Double = 1

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.Nexus.accent)
            .frame(width: 2, height: 14)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    opacity = 0
                }
            }
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

struct EchoPulseView: View {
    // Two independent animation phases, offset so rings are staggered.
    @State private var phase1: Double = 0
    @State private var phase2: Double = 0
    // Breathing pulse on the center node
    @State private var breathe: Bool = false

    var body: some View {
        HStack(spacing: NexusSpacing.md) {
            // The pulse animation itself
            Canvas { ctx, size in
                let cx = size.width / 2
                let cy = size.height / 2
                let maxR: Double = min(cx, cy) - 2

                // Draw two ring pairs with independent phases
                for (phase, opacity) in [(phase1, 0.6), (phase2, 0.4)] {
                    let r = maxR * phase
                    let alpha = (1 - phase) * opacity
                    var ring = Path()
                    ring.addEllipse(in: CGRect(
                        x: cx - r, y: cy - r, width: r * 2, height: r * 2
                    ))
                    ctx.stroke(ring, with: .color(.Nexus.accent.opacity(alpha)), lineWidth: 1.5)
                }

                // Center dot — breathing
                let dotR: Double = breathe ? 4.5 : 3.5
                var dot = Path()
                dot.addEllipse(in: CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2))
                ctx.fill(dot, with: .color(.Nexus.accent.opacity(breathe ? 1 : 0.7)))
            }
            .frame(width: 32, height: 32)
            .onAppear { startAnimations() }

            Text("Nexus is thinking…")
                .font(.Nexus.caption)
                .foregroundColor(.Nexus.ghost)
                .kerning(NexusKerning.normal)
        }
    }

    private func startAnimations() {
        // Ring 1: 0 → 1 over 1.4s, repeat
        withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
            phase1 = 1.0
        }
        // Ring 2: starts at 0.5 offset — staggered 0.7s delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                phase2 = 1.0
            }
        }
        // Center breathing
        withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
            breathe = true
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

    var body: some View {
        HStack(alignment: .bottom, spacing: NexusSpacing.sm) {
            // Text input
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
                    .lineLimit(1...5)
                    .submitLabel(.send)
                    .onSubmit {
                        if canSend { vm.send() }
                    }
                    .padding(.horizontal, 6)
            }
            .padding(.horizontal, NexusSpacing.sm)
            .padding(.vertical, NexusSpacing.sm + 2)
            .background(Color.Nexus.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: NexusRadius.xxl))
            .overlay(
                RoundedRectangle(cornerRadius: NexusRadius.xxl)
                    .stroke(focused.wrappedValue ? Color.Nexus.accent.opacity(0.5) : Color.Nexus.border,
                            lineWidth: NexusBorder.base)
            )

            // Send / mic button
            Button {
                if canSend { vm.send() }
            } label: {
                Image(systemName: canSend ? "arrow.up" : "waveform")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(canSend ? .white : .Nexus.faint)
                    .frame(width: 36, height: 36)
                    .background(canSend ? Color.Nexus.accent : Color.Nexus.surface2)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .animation(NexusAnimation.element, value: canSend)
            .disabled(vm.phase == .streaming)
        }
        .padding(NexusSpacing.sm)
        .background(Color.Nexus.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.xxl + 4))
        .overlay(
            RoundedRectangle(cornerRadius: NexusRadius.xxl + 4)
                .stroke(Color.Nexus.border, lineWidth: NexusBorder.hair)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
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
