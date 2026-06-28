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

    @StateObject private var vm: NexusViewModel

    init(collection: NexusCollection) {
        self.collection = collection
        _vm = StateObject(wrappedValue: NexusViewModel(collection: collection))
    }

    var body: some View {
        // When the collection has no sources yet, show a focused empty state.
        // The chat composer is hidden — there is nothing for the AI to reason over.
        // ARCH_BRIEF 1D-002: "Do not show the chat composer in this state."
        if collection.sourceCount == 0 {
            noSourcesEmptyState
        } else {
            chatUI
        }
    }

    // MARK: - No-sources empty state

    private var noSourcesEmptyState: some View {
        VStack {
            Spacer()
            EmptyStateView(
                icon: "text.magnifyingglass",
                title: "Add a source to get started",
                subtitle: "Nexus needs at least one source to answer questions. Switch to Sources and add a link."
            )
            Spacer()
        }
        .background(Color.Nexus.pageBackground)
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
            // Composer
            ChatComposer(vm: vm)
                .padding(.horizontal, NexusSpacing.sideGutter)
                .padding(.bottom, NexusSpacing.standard)
        }
        .background(NexusBackground())
        // simultaneousGesture avoids eating child taps (e.g. citation chips, send button).
        // Plain .onTapGesture would intercept those taps before they reach child views.
        .simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
        )
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
                    // Framing paragraph pinned at top
                    framingParagraph
                        .padding(.top, NexusSpacing.lg)

                    // Message bubbles
                    ForEach(vm.messages) { msg in
                        MessageBubble(message: msg, retrievedSources: vm.retrievedSources)
                            .id(msg.id)
                    }

                    // Invisible anchor for auto-scroll
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, NexusSpacing.sideGutter)
                .padding(.bottom, NexusSpacing.sm)
            }
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

    // MARK: - Framing paragraph

    @ViewBuilder
    private var framingParagraph: some View {
        let text: String = {
            if let f = collection.framingParagraph, !f.isEmpty { return f }
            let n = collection.sourceCount
            let countStr = n == 0 ? "sources" : (n == 1 ? "1 source" : "\(n) sources")
            return "This collection has \(countStr). Ask me anything about what you've saved here."
        }()

        VStack(alignment: .leading, spacing: NexusSpacing.xs) {
            // Echo mark accent line above framing
            HStack(spacing: NexusSpacing.xs) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.Nexus.accent)
                    .frame(width: 3, height: 18)
                Text("NEXUS")
                    .font(.Nexus.overline)
                    .foregroundColor(.Nexus.accent)
                    .kerning(NexusKerning.wide)
            }

            Text(text)
                .font(.Nexus.bodyMedium)
                .foregroundColor(.Nexus.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(NexusSpacing.standard)
        .background(Color.Nexus.bloom.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.base))
        .overlay(
            RoundedRectangle(cornerRadius: NexusRadius.base)
                .stroke(Color.Nexus.accent.opacity(0.18), lineWidth: NexusBorder.hair)
        )
    }

    // MARK: - Starter prompts / Echo pulse

    @ViewBuilder
    private var promptRow: some View {
        if vm.phase == .streaming {
            EchoPulseView()
                .frame(height: 44)
        } else {
            StarterPromptsRow(prompts: vm.starterPrompts) { vm.sendStarter($0) }
        }
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: ChatMessage
    let retrievedSources: [CitedSource]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user { Spacer(minLength: NexusSpacing.xxxl) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: NexusSpacing.xs) {
                // Text bubble
                Text(strippedContent)
                    .font(.Nexus.bodySmall)
                    .foregroundColor(message.role == .user ? .white : .Nexus.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, NexusSpacing.md)
                    .padding(.vertical, NexusSpacing.sm + 2)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: NexusRadius.md)
                            .stroke(bubbleBorder, lineWidth: NexusBorder.hair)
                    )

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

    private var bubbleBackground: Color {
        message.role == .user ? Color.Nexus.accent : Color.Nexus.cardBackground
    }

    private var bubbleBorder: Color {
        message.role == .user ? Color.clear : Color.Nexus.border
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

// MARK: - Starter prompts row

private struct StarterPromptsRow: View {
    let prompts: [String]
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: NexusSpacing.xs) {
                ForEach(prompts, id: \.self) { prompt in
                    StarterChip(label: prompt) { onSelect(prompt) }
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

private struct StarterChip: View {
    let label: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.Nexus.labelSmall)
                .foregroundColor(.Nexus.muted)
                .kerning(NexusKerning.normal)
                .lineLimit(1)
                .padding(.horizontal, NexusSpacing.md)
                .padding(.vertical, NexusSpacing.sm)
                .background(Color.Nexus.surface2)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.Nexus.border, lineWidth: NexusBorder.hair))
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? NexusScale.pressLight : 1)
        .animation(NexusAnimation.press, value: isPressed)
        .onLongPressGesture(minimumDuration: 0, pressing: { p in isPressed = p }, perform: {})
    }
}

// MARK: - Composer

private struct ChatComposer: View {
    @ObservedObject var vm: NexusViewModel
    @FocusState private var focused: Bool

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
                    .focused($focused)
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
                    .stroke(focused ? Color.Nexus.accent.opacity(0.5) : Color.Nexus.border,
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

// MARK: - Liquid Glass tab capsule
//
// Shared by CollectionView for the Nexus / Sources tab switcher.
// Floats above content, uses backdrop blur (iOS 26 Liquid Glass material).
// DESIGN_LANGUAGE §3: frost + tint/gloss + specular rim; radius 22–26; shadow.

struct LiquidGlassTabCapsule<Tab: RawRepresentable & CaseIterable & Hashable>: View
    where Tab.RawValue == String, Tab.AllCases: RandomAccessCollection
{
    @Binding var selectedTab: Tab
    var onTabChange: ((Tab) -> Void)? = nil

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(Tab.allCases), id: \.self) { tab in
                tabPill(tab)
            }
        }
        .padding(3)
        .background(glassBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            Color.white.opacity(0.1),
                            Color(red: 150/255, green: 170/255, blue: 1).opacity(0.15),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: NexusBorder.hair
                )
        )
        // Soft float shadow per DESIGN_LANGUAGE §3
        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 6)
        .shadow(color: Color.Nexus.accent.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func tabPill(_ tab: Tab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(NexusAnimation.pivot) {
                selectedTab = tab
                onTabChange?(tab)
            }
        } label: {
            Text(tab.rawValue)
                .font(.Nexus.labelMedium)
                .kerning(NexusKerning.normal)
                .foregroundColor(isSelected ? .Nexus.ink : .Nexus.muted)
                .padding(.vertical, NexusSpacing.xs + 2)
                .padding(.horizontal, NexusSpacing.standard)
                .background(
                    isSelected
                        ? Color.white.opacity(0.85)
                        : Color.clear,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .animation(NexusAnimation.pivot, value: isSelected)
    }

    // Liquid Glass background: frost + tint/gloss layers (§3)
    private var glassBackground: some ShapeStyle {
        // SwiftUI's .ultraThinMaterial approximates iOS 26 Liquid Glass frost layer.
        // We layer a gradient over it for the tint/gloss reflection.
        .ultraThinMaterial
    }
}
