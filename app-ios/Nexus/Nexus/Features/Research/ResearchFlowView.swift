import SwiftUI

// MARK: - Entry point

/// Full-screen "Research a topic" creation flow.
///
/// States:
///   .idle      → TopicInputView (type topic, tap Research)
///   .searching → SearchingView  ("Researching…" pulsing animation)
///   .reviewing → SourcesReviewView (sources appear, user toggles/confirms)
///   .confirming→ SourcesReviewView with disabled button + spinner
///   .done      → dismissed, caller navigates to the new collection
///   .error     → ErrorView with retry
///
/// Presented as a sheet from HomeView.
struct ResearchFlowView: View {
    @StateObject private var vm = ResearchViewModel()

    /// Called when the flow completes — caller navigates to the collection.
    var onComplete: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.Nexus.pageBackground.ignoresSafeArea()
                content
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if vm.phase == .idle || vm.phase == .searching {
                        Button("Cancel") { dismiss() }
                            .font(.Nexus.bodyMedium)
                            .foregroundColor(.Nexus.muted)
                    }
                }
            }
            .onChange(of: vm.phase) { phase in
                if case .done(let id) = phase {
                    dismiss()
                    onComplete(id)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.phase {
        case .idle:
            TopicInputView(vm: vm)
                .transition(.opacity)
        case .searching:
            SearchingView(topic: vm.topic)
                .transition(.opacity)
        case .reviewing, .confirming:
            SourcesReviewView(vm: vm)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
        case .done:
            // Transient: onChange fires dismiss() immediately.
            Color.Nexus.pageBackground.ignoresSafeArea()
        case .error(let msg):
            ErrorView(message: msg, vm: vm)
                .transition(.opacity)
        }
    }
}

// MARK: - 1. Topic input

private struct TopicInputView: View {
    @ObservedObject var vm: ResearchViewModel
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: NexusSpacing.xl) {
                // Headline
                VStack(alignment: .leading, spacing: NexusSpacing.sm) {
                    Text("Research a topic")
                        .font(.Nexus.headingLarge)
                        .foregroundColor(.Nexus.ink)
                        .kerning(NexusKerning.tighter)

                    Text("Nexus finds 8 authoritative sources and builds a collection you can explore.")
                        .font(.Nexus.bodySmall)
                        .foregroundColor(.Nexus.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Input field
                VStack(alignment: .leading, spacing: NexusSpacing.sm) {
                    ZStack(alignment: .leading) {
                        if vm.topic.isEmpty {
                            Text("e.g. Ozempic and longevity")
                                .font(.Nexus.bodyLarge)
                                .foregroundColor(.Nexus.ghost)
                        }
                        TextField("", text: $vm.topic, axis: .vertical)
                            .font(.Nexus.bodyLarge)
                            .foregroundColor(.Nexus.ink)
                            .focused($focused)
                            .submitLabel(.search)
                            .lineLimit(3)
                            .onSubmit {
                                if !vm.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    vm.startResearch()
                                }
                            }
                    }
                    .padding(NexusSpacing.standard)
                    .background(Color.Nexus.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: NexusRadius.md)
                            .stroke(focused ? Color.Nexus.accent.opacity(0.6) : Color.Nexus.border,
                                    lineWidth: focused ? NexusBorder.base : NexusBorder.hair)
                    )
                    .animation(NexusAnimation.element, value: focused)
                }

                // Research button
                Button {
                    vm.startResearch()
                } label: {
                    HStack(spacing: NexusSpacing.sm) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Research")
                            .font(.Nexus.labelLarge)
                            .kerning(NexusKerning.normal)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: NexusSpacing.buttonHeight)
                    .background(
                        vm.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.Nexus.ghost
                            : Color.Nexus.accent
                    )
                    .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md))
                    .animation(NexusAnimation.element,
                               value: vm.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .disabled(vm.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, NexusSpacing.sideGutter + NexusSpacing.sm)

            Spacer()
            Spacer()
        }
        .onAppear { focused = true }
    }
}

// MARK: - 2. Searching state

private struct SearchingView: View {
    let topic: String
    @State private var dotPhase: Int = 0

    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: NexusSpacing.xl) {
            Spacer()

            VStack(spacing: NexusSpacing.lg) {
                // Pulsing accent dot indicator
                HStack(spacing: NexusSpacing.sm) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(Color.Nexus.accent)
                            .frame(width: 8, height: 8)
                            .scaleEffect(dotPhase == i ? 1.4 : 0.8)
                            .opacity(dotPhase == i ? 1.0 : 0.35)
                            .animation(
                                .timingCurve(0.2, 0.8, 0.2, 1.0, duration: 0.4),
                                value: dotPhase
                            )
                    }
                }
                .onReceive(timer) { _ in
                    dotPhase = (dotPhase + 1) % 3
                }

                VStack(spacing: NexusSpacing.xs) {
                    Text("Researching…")
                        .font(.Nexus.headingSmall)
                        .foregroundColor(.Nexus.ink)
                        .kerning(NexusKerning.tighter)

                    Text("Finding the best sources for "\(topic)"")
                        .font(.Nexus.bodySmall)
                        .foregroundColor(.Nexus.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, NexusSpacing.xl)
                }
            }

            Spacer()
        }
    }
}

// MARK: - 3. Sources review

private struct SourcesReviewView: View {
    @ObservedObject var vm: ResearchViewModel
    @State private var isConfirmPressed = false

    private var isConfirming: Bool {
        if case .confirming = vm.phase { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: NexusSpacing.xs) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Found \(vm.sources.count) sources")
                            .font(.Nexus.headingSmall)
                            .foregroundColor(.Nexus.ink)
                            .kerning(NexusKerning.tighter)
                        Text("Deselect any you don't want")
                            .font(.Nexus.bodySmall)
                            .foregroundColor(.Nexus.muted)
                    }
                    Spacer()
                }
                .padding(.horizontal, NexusSpacing.sideGutter)
                .padding(.top, NexusSpacing.md)
                .padding(.bottom, NexusSpacing.sm)

                Rectangle()
                    .fill(Color.Nexus.hair)
                    .frame(height: NexusBorder.hair)
            }

            // Source list
            ScrollView {
                LazyVStack(spacing: NexusSpacing.sm) {
                    ForEach(vm.sources) { source in
                        SourceSuggestionRow(
                            source: source,
                            isSelected: source.isSelected
                        ) {
                            withAnimation(NexusAnimation.element) {
                                vm.toggleSource(id: source.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, NexusSpacing.sideGutter)
                .padding(.top, NexusSpacing.md)
                .padding(.bottom, NexusSpacing.xxl + NexusSpacing.buttonHeight + NexusSpacing.xl)
            }

            Spacer(minLength: 0)
        }
        .overlay(alignment: .bottom) {
            confirmBar
        }
    }

    private var confirmBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.Nexus.hair)
                .frame(height: NexusBorder.hair)

            HStack(spacing: NexusSpacing.md) {
                // Selection count badge
                let count = vm.selectedSources.count
                Text("\(count) selected")
                    .font(.Nexus.labelMedium)
                    .foregroundColor(.Nexus.muted)

                Spacer()

                Button {
                    Task { await vm.confirmSources() }
                } label: {
                    HStack(spacing: NexusSpacing.sm) {
                        if isConfirming {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Text("Add to collection")
                                .font(.Nexus.labelLarge)
                                .kerning(NexusKerning.normal)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, NexusSpacing.xl)
                    .frame(height: NexusSpacing.buttonHeight)
                    .background(vm.canConfirm && !isConfirming ? Color.Nexus.accent : Color.Nexus.ghost)
                    .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md))
                    .animation(NexusAnimation.element, value: isConfirming)
                }
                .disabled(!vm.canConfirm || isConfirming)
            }
            .padding(.horizontal, NexusSpacing.sideGutter)
            .padding(.vertical, NexusSpacing.md)
            .background(Color.Nexus.pageBackground)
        }
    }
}

// MARK: - Source suggestion row

private struct SourceSuggestionRow: View {
    let source: ResearchSource
    let isSelected: Bool
    let onToggle: () -> Void

    @State private var isPressed = false

    private var contentTypeIcon: String {
        switch source.contentType {
        case "video":   return "play.rectangle"
        case "podcast": return "mic"
        case "paper":   return "doc.text.fill"
        case "thread":  return "bubble.left.and.bubble.right"
        default:        return "doc.text"
        }
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: NexusSpacing.md) {
                // Selection toggle
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.Nexus.accent : Color.clear)
                        .frame(width: 22, height: 22)
                    Circle()
                        .stroke(isSelected ? Color.clear : Color.Nexus.border, lineWidth: NexusBorder.base)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .animation(NexusAnimation.element, value: isSelected)
                .padding(.top, 2)

                // Content
                VStack(alignment: .leading, spacing: NexusSpacing.xs) {
                    // Title + type icon
                    HStack(alignment: .top, spacing: NexusSpacing.xs) {
                        Text(source.title)
                            .font(.Nexus.labelMedium)
                            .foregroundColor(isSelected ? .Nexus.ink : .Nexus.ghost)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: contentTypeIcon)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.Nexus.ghost)
                    }

                    // Domain
                    if !source.domain.isEmpty {
                        Text(source.domain.uppercased())
                            .font(.Nexus.overline)
                            .foregroundColor(.Nexus.ghost)
                            .kerning(NexusKerning.wide)
                    }

                    // Rationale — shown only when selected
                    if isSelected && !source.rationale.isEmpty {
                        Text(source.rationale)
                            .font(.Nexus.bodySmall)
                            .foregroundColor(.Nexus.muted)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(NexusSpacing.standard)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.Nexus.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: NexusRadius.base))
            .overlay(
                RoundedRectangle(cornerRadius: NexusRadius.base)
                    .stroke(
                        isSelected ? Color.Nexus.accent.opacity(0.25) : Color.Nexus.border,
                        lineWidth: NexusBorder.hair
                    )
            )
            .opacity(isSelected ? 1.0 : 0.5)
            .scaleEffect(isPressed ? NexusScale.pressLight : 1)
        }
        .buttonStyle(.plain)
        .animation(NexusAnimation.element, value: isSelected)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            withAnimation(NexusAnimation.press) { isPressed = pressing }
        }, perform: {})
    }
}

// MARK: - Error view

private struct ErrorView: View {
    let message: String
    @ObservedObject var vm: ResearchViewModel

    var body: some View {
        VStack(spacing: NexusSpacing.xl) {
            Spacer()

            VStack(spacing: NexusSpacing.lg) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.Nexus.ghost)

                VStack(spacing: NexusSpacing.sm) {
                    Text("Something went wrong")
                        .font(.Nexus.headingSmall)
                        .foregroundColor(.Nexus.ink)
                        .kerning(NexusKerning.tighter)

                    Text(message)
                        .font(.Nexus.bodySmall)
                        .foregroundColor(.Nexus.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, NexusSpacing.xl)
                }

                Button("Try again") {
                    withAnimation(NexusAnimation.element) {
                        vm.retry()
                    }
                }
                .font(.Nexus.labelLarge)
                .foregroundColor(.Nexus.white)
                .padding(.horizontal, NexusSpacing.xl)
                .frame(height: NexusSpacing.buttonHeight)
                .background(Color.Nexus.accent)
                .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md))
            }

            Spacer()
        }
        .padding(.horizontal, NexusSpacing.sideGutter)
    }
}

