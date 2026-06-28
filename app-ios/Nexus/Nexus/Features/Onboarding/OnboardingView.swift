import Combine
import SwiftUI

// MARK: - Entry point

/// Full-screen onboarding flow shown on first launch (before Home).
///
/// Steps:
///   0 — WelcomeScreen   (brand mark + tagline + "Get started")
///   1 — TopicsScreen    ("What are you curious about?" + topic chips)
///   2 — CollectionPrompt("Your first collection" + creation CTAs)
///
/// Integration: shown from NexusApp.RootView when
/// OnboardingViewModel.hasCompletedOnboarding == false.
struct OnboardingView: View {
    @StateObject private var vm = OnboardingViewModel()

    /// Called when the user taps "Research a topic" or "Start with a link"
    /// on the final screen, triggering navigation to the main app.
    ///
    /// - Parameter launchResearch: true → open ResearchFlowView immediately on Home.
    var onComplete: (_ launchResearch: Bool) -> Void

    var body: some View {
        ZStack {
            NexusBackground()

            // Step container — slides horizontally
            TabView(selection: $vm.step) {
                WelcomeScreen(vm: vm)
                    .tag(0)
                    .gesture(DragGesture())  // disable swipe-to-advance; only use buttons

                TopicsScreen(vm: vm)
                    .tag(1)
                    .gesture(DragGesture())

                CollectionPromptScreen(vm: vm, onComplete: onComplete)
                    .tag(2)
                    .gesture(DragGesture())
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(NexusAnimation.pageForward, value: vm.step)

            // Step dots — bottom of screen
            VStack {
                Spacer()
                StepDots(current: vm.step, total: 3)
                    .padding(.bottom, NexusSpacing.safeBottom + NexusSpacing.xxl)
            }
        }
    }
}

// MARK: - Step dots

private struct StepDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: NexusSpacing.sm) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.Nexus.accent : Color.Nexus.border)
                    .frame(width: i == current ? 20 : 6, height: 6)
                    .animation(NexusAnimation.pivot, value: current)
            }
        }
    }
}

// MARK: - Screen 1: Welcome

private struct WelcomeScreen: View {
    @ObservedObject var vm: OnboardingViewModel
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: NexusSpacing.xxxl) {
                // Brand mark — canonical Echo mark from design system
                EchoMark(color: Color.Nexus.accent, size: 60)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(
                        .timingCurve(0.2, 0.8, 0.2, 1.0, duration: NexusDuration.slow),
                        value: appeared
                    )

                // Wordmark + tagline
                VStack(spacing: NexusSpacing.md) {
                    Text("Nexus")
                        .font(.Nexus.displayMedium)
                        .foregroundColor(.Nexus.ink)
                        .kerning(NexusKerning.tightest)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)
                        .animation(
                            .timingCurve(0.2, 0.8, 0.2, 1.0, duration: NexusDuration.slow)
                                .delay(0.08),
                            value: appeared
                        )

                    Text("Your AI research companion.\nCurate, explore, understand.")
                        .font(.Nexus.bodyMedium)
                        .foregroundColor(.Nexus.muted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 6)
                        .animation(
                            .timingCurve(0.2, 0.8, 0.2, 1.0, duration: NexusDuration.slow)
                                .delay(0.14),
                            value: appeared
                        )
                }
            }

            Spacer()
            Spacer()

            // CTA
            NexusPrimaryButton(label: "Get started", icon: "arrow.right") {
                vm.advance()
            }
            .opacity(appeared ? 1 : 0)
            .animation(
                .timingCurve(0.2, 0.8, 0.2, 1.0, duration: NexusDuration.slow).delay(0.22),
                value: appeared
            )
            .padding(.horizontal, NexusSpacing.sideGutter + NexusSpacing.sm)
            .padding(.bottom, NexusSpacing.safeBottom + NexusSpacing.xl + NexusSpacing.xxl)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Echo mark (brand glyph)


// MARK: - Screen 2: Topic picker

private struct TopicsScreen: View {
    @ObservedObject var vm: OnboardingViewModel
    @FocusState private var customFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: NexusSpacing.sm) {
                Text("What are you\ncurious about?")
                    .font(.Nexus.headingLarge)
                    .foregroundColor(.Nexus.ink)
                    .kerning(NexusKerning.tighter)
                    .lineSpacing(2)

                Text("Pick topics you want to explore. Nexus will learn your interests over time.")
                    .font(.Nexus.bodySmall)
                    .foregroundColor(.Nexus.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, NexusSpacing.sideGutter + NexusSpacing.sm)
            .padding(.top, NexusSpacing.safeTop + NexusSpacing.xl)
            .padding(.bottom, NexusSpacing.xl)

            // Scrollable topic chips
            ScrollView {
                // Flowing chip layout using a lazy grid
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 120, maximum: 200), spacing: NexusSpacing.sm)],
                    spacing: NexusSpacing.sm
                ) {
                    ForEach(OnboardingViewModel.suggestedTopics, id: \.self) { topic in
                        TopicChip(
                            label: topic,
                            isSelected: vm.selectedTopics.contains(topic)
                        ) {
                            withAnimation(NexusAnimation.element) {
                                vm.toggleTopic(topic)
                            }
                        }
                    }
                }
                .padding(.horizontal, NexusSpacing.sideGutter + NexusSpacing.sm)
                .padding(.bottom, NexusSpacing.xl)

                // Custom topic field
                VStack(alignment: .leading, spacing: NexusSpacing.sm) {
                    Text("ADD YOUR OWN")
                        .font(.Nexus.overline)
                        .foregroundColor(.Nexus.ghost)
                        .kerning(NexusKerning.wide)

                    ZStack(alignment: .leading) {
                        if vm.customTopic.isEmpty {
                            Text("e.g. Ancient Rome, Behavioral economics…")
                                .font(.Nexus.bodySmall)
                                .foregroundColor(.Nexus.ghost)
                        }
                        TextField("", text: $vm.customTopic)
                            .font(.Nexus.bodySmall)
                            .foregroundColor(.Nexus.ink)
                            .focused($customFocused)
                            .submitLabel(.done)
                    }
                    .padding(.horizontal, NexusSpacing.standard)
                    .padding(.vertical, NexusSpacing.md)
                    .background(Color.Nexus.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: NexusRadius.md)
                            .stroke(
                                customFocused ? Color.Nexus.accent.opacity(0.6) : Color.Nexus.border,
                                lineWidth: customFocused ? NexusBorder.base : NexusBorder.hair
                            )
                    )
                    .animation(NexusAnimation.element, value: customFocused)
                }
                .padding(.horizontal, NexusSpacing.sideGutter + NexusSpacing.sm)
                .padding(.bottom, NexusSpacing.xl + NexusSpacing.buttonHeight + NexusSpacing.xxl + NexusSpacing.safeBottom)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .overlay(alignment: .bottom) {
            // Sticky Continue button
            VStack(spacing: 0) {
                LinearGradient(
                    gradient: Gradient(colors: [Color.Nexus.pageBackground.opacity(0), Color.Nexus.pageBackground]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: NexusSpacing.xl)

                NexusPrimaryButton(
                    label: "Continue",
                    icon: "arrow.right",
                    isEnabled: vm.canProceedFromTopics
                ) {
                    vm.advance()
                }
                .padding(.horizontal, NexusSpacing.sideGutter + NexusSpacing.sm)
                .padding(.bottom, NexusSpacing.safeBottom + NexusSpacing.xl + NexusSpacing.xxl)
                .background(Color.Nexus.pageBackground)
            }
        }
    }
}

// MARK: - Topic chip

private struct TopicChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: NexusSpacing.xs) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                Text(label)
                    .font(.Nexus.labelSmall)
                    .foregroundColor(isSelected ? .white : .Nexus.ink)
                    .kerning(NexusKerning.normal)
                    .lineLimit(1)
            }
            .padding(.horizontal, NexusSpacing.md)
            .padding(.vertical, NexusSpacing.sm)
            .frame(maxWidth: .infinity)
            .background(
                isSelected
                    ? Color.Nexus.accent
                    : Color.Nexus.cardBackground
            )
            .clipShape(RoundedRectangle(cornerRadius: NexusRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: NexusRadius.sm)
                    .stroke(
                        isSelected ? Color.Nexus.accent : Color.Nexus.border,
                        lineWidth: NexusBorder.hair
                    )
            )
            .scaleEffect(isPressed ? NexusScale.pressLight : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            withAnimation(NexusAnimation.press) { isPressed = pressing }
        }, perform: {})
    }
}

// MARK: - Screen 3: Collection prompt

private struct CollectionPromptScreen: View {
    @ObservedObject var vm: OnboardingViewModel
    var onComplete: (_ launchResearch: Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: NexusSpacing.xxxl) {
                // Heading block
                VStack(alignment: .leading, spacing: NexusSpacing.md) {
                    Text("Create your first\ncollection")
                        .font(.Nexus.headingLarge)
                        .foregroundColor(.Nexus.ink)
                        .kerning(NexusKerning.tighter)
                        .lineSpacing(2)

                    Text("A collection is your personal research space. Nexus reads everything and answers your questions.")
                        .font(.Nexus.bodySmall)
                        .foregroundColor(.Nexus.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Selected topic pills (if any)
                if !vm.finalTopics.isEmpty {
                    VStack(alignment: .leading, spacing: NexusSpacing.sm) {
                        Text("YOUR INTERESTS")
                            .font(.Nexus.overline)
                            .foregroundColor(.Nexus.ghost)
                            .kerning(NexusKerning.wide)

                        // Wrapping chip row — limited to first 6 for visual cleanliness
                        FlowLayout(spacing: NexusSpacing.sm) {
                            ForEach(Array(vm.finalTopics.prefix(6)), id: \.self) { topic in
                                Text(topic)
                                    .font(.Nexus.caption)
                                    .foregroundColor(.Nexus.accent)
                                    .kerning(NexusKerning.normal)
                                    .padding(.horizontal, NexusSpacing.sm)
                                    .padding(.vertical, 4)
                                    .background(Color.Nexus.bloom.opacity(0.5))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.Nexus.accent.opacity(0.2), lineWidth: NexusBorder.hair)
                                    )
                            }
                        }
                    }
                }

                // Action cards
                VStack(spacing: NexusSpacing.sm) {
                    // Primary: research a topic
                    CollectionActionCard(
                        icon: "sparkles",
                        title: "Research a topic",
                        subtitle: "Nexus finds 8 authoritative sources and builds your collection.",
                        isPrimary: true
                    ) {
                        vm.complete()
                        onComplete(true)
                    }

                    // Secondary: start with a link
                    CollectionActionCard(
                        icon: "link",
                        title: "Start with a link",
                        subtitle: "Paste a URL and build your collection manually.",
                        isPrimary: false
                    ) {
                        vm.complete()
                        onComplete(false)
                    }
                }
            }
            .padding(.horizontal, NexusSpacing.sideGutter + NexusSpacing.sm)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Collection action card

private struct CollectionActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isPrimary: Bool
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: NexusSpacing.standard) {
                // Icon container
                ZStack {
                    RoundedRectangle(cornerRadius: NexusRadius.sm)
                        .fill(isPrimary ? Color.Nexus.accent : Color.Nexus.surface2)
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isPrimary ? .white : .Nexus.muted)
                }

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.Nexus.labelLarge)
                        .foregroundColor(.Nexus.ink)
                        .kerning(NexusKerning.normal)

                    Text(subtitle)
                        .font(.Nexus.bodySmall)
                        .foregroundColor(.Nexus.muted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.Nexus.ghost)
            }
            .padding(NexusSpacing.standard)
            .background(Color.Nexus.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: NexusRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: NexusRadius.lg)
                    .stroke(
                        isPrimary ? Color.Nexus.accent.opacity(0.25) : Color.Nexus.border,
                        lineWidth: isPrimary ? NexusBorder.base : NexusBorder.hair
                    )
            )
            .scaleEffect(isPressed ? NexusScale.pressLight : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            withAnimation(NexusAnimation.press) { isPressed = pressing }
        }, perform: {})
    }
}

// MARK: - Reusable primary button

private struct NexusPrimaryButton: View {
    let label: String
    let icon: String
    var isEnabled: Bool = true
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: NexusSpacing.sm) {
                Text(label)
                    .font(.Nexus.labelLarge)
                    .kerning(NexusKerning.normal)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: NexusSpacing.buttonHeight)
            .background(isEnabled ? Color.Nexus.accent : Color.Nexus.ghost)
            .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md))
            .scaleEffect(isPressed ? NexusScale.pressBase : 1.0)
            .animation(NexusAnimation.element, value: isEnabled)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            if isEnabled {
                withAnimation(NexusAnimation.press) { isPressed = pressing }
            }
        }, perform: {})
    }
}

// MARK: - Flow layout (chip wrapping)

/// A simple flow layout that wraps its children to new lines.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + spacing
                totalHeight = y
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
