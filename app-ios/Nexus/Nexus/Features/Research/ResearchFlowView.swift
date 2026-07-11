import Combine
import SwiftUI

// MARK: - Constants

private let freTopics = [
    "the US–Iran conflict",
    "second-brain tools",
    "how memory works",
    "the AI platform shift",
    "anything you're curious about",
]

private let freTrending = [
    "US–Iran conflict",
    "AI platform shifts",
    "Ozempic & longevity",
    "Vision Pro 2",
]

private let frePhrasesSearching = [
    "Researching…",
    "Finding authoritative sources…",
    "Reading everything…",
    "Picking the best pieces…",
    "Almost ready…",
]

// MARK: - Entry point

struct ResearchFlowView: View {
    @StateObject private var vm = ResearchViewModel()
    var onComplete: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    private var sheetVisible: Bool {
        switch vm.phase {
        case .searching, .reviewing, .confirming: return true
        default: return false
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // ── Input screen — scales back when the sheet rises ──
                FREInputScreen(vm: vm)
                    .scaleEffect(sheetVisible ? 0.945 : 1.0)
                    .clipShape(RoundedRectangle(cornerRadius: sheetVisible ? 22 : 0, style: .continuous))
                    .animation(.spring(response: 0.52, dampingFraction: 0.86), value: sheetVisible)

                // ── Scrim ──
                Color.black
                    .opacity(sheetVisible ? 0.22 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.38), value: sheetVisible)

                // ── Sources sheet ──
                FRESourcesSheet(vm: vm)
                    .frame(height: geo.size.height * 0.905)
                    .background(NexusBackground())
                    .clipShape(.rect(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.20), radius: 40, x: 0, y: -12)
                    .offset(y: sheetVisible ? 0 : geo.size.height + 40)
                    .animation(.spring(response: 0.48, dampingFraction: 0.86), value: sheetVisible)

                // ── Error banner — errors were previously INVISIBLE: the sheet
                // slid away with no feedback and looked like a phantom dismissal
                // (2026-07-11, three stacked backend persist bugs).
                if case .error(let message) = vm.phase {
                    VStack {
                        FREErrorBanner(message: message) { vm.retry() }
                            .padding(.horizontal, NexusSpacing.sideGutter)
                            .padding(.top, NexusSpacing.safeTop + 8)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: sheetVisible)
            // Prevent keyboard appearance from changing geo.size, which would
            // cascade re-renders through FREInputScreen while the user types.
            .ignoresSafeArea(.keyboard)
        }
        .ignoresSafeArea()
        .onChange(of: vm.phase) { _, phase in
            if case .done(let id) = phase {
                dismiss()
                onComplete(id)
            }
        }
    }
}

// MARK: - Input screen

private struct FREInputScreen: View {
    @ObservedObject var vm: ResearchViewModel
    @EnvironmentObject private var authManager: AuthManager
    @State private var showAvatarMenu = false
    // Local state scopes TextField rerenders to FREComposer only — avoids
    // rerendering the entire screen on every keystroke.
    @State private var composerText = ""
    // Link sheet presentation
    @State private var linkSheetContentType: DetectedContentType? = nil

    var body: some View {
        ZStack(alignment: .top) {
            NexusBackground()

            // Main content — vertically centered with safe area clearance
            VStack(spacing: 0) {
                Spacer().frame(height: NexusSpacing.safeTop)
                Spacer()

                VStack(alignment: .leading, spacing: 0) {
                    // Kicker
                    Text("NEW COLLECTION")
                        .font(.system(size: 11.5, weight: .semibold))
                        .kerning(0.8)
                        .foregroundColor(.Nexus.ghost)
                        .padding(.bottom, 14)

                    // Headline + rotating word
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start a collection on")
                            .font(.system(size: 29, weight: .bold))
                            .foregroundColor(.Nexus.muted)
                            .kerning(-0.8)
                        FRERotatingWord(words: freTopics)
                            .font(.system(size: 29, weight: .bold))
                            .foregroundColor(.Nexus.ink)
                            .kerning(-0.8)
                    }
                    .lineSpacing(2)
                    .padding(.bottom, 24)

                    // Composer — driven by local state; syncs to vm only on submit
                    FREComposer(text: $composerText) {
                        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        vm.topic = trimmed
                        vm.startResearch()
                    }
                    .padding(.bottom, 20)
                    .onChange(of: vm.topic) { _, newTopic in
                        if newTopic.isEmpty { composerText = "" }
                    }

                    // Trending chips
                    FRETrendingChips(onSelect: { topic in
                        vm.topic = topic
                        vm.startResearch()
                    })
                    .padding(.bottom, 26)

                    // Or start with a link
                    FRELinkButtons { contentType in
                        linkSheetContentType = contentType
                    }
                }
                .padding(.horizontal, NexusSpacing.sideGutter + 4)

                Spacer()
                Spacer()
            }

            // Avatar button — top right
            HStack {
                Spacer()
                FREAvatarButton(active: showAvatarMenu) {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                        showAvatarMenu = true
                    }
                }
                .padding(.trailing, NexusSpacing.standard)
                .padding(.top, NexusSpacing.safeTop + 6)
            }

            // Scrim — transparent, tap to close the menu
            if showAvatarMenu {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            showAvatarMenu = false
                        }
                    }
            }

            // Avatar bloom menu — snaps from the top-right corner, Notion-style
            VStack {
                HStack {
                    Spacer()
                    FREAvatarMenuCard {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                            showAvatarMenu = false
                        }
                    }
                    .padding(.trailing, NexusSpacing.standard)
                }
                Spacer()
            }
            .padding(.top, NexusSpacing.safeTop + 6 + 32 + 8)
            .scaleEffect(showAvatarMenu ? 1 : 0.5, anchor: .topTrailing)
            .opacity(showAvatarMenu ? 1 : 0)
            .animation(.spring(response: 0.42, dampingFraction: 0.64), value: showAvatarMenu)
            .allowsHitTesting(showAvatarMenu)
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
        )
        // Link URL sheet — presented when user taps Website / PDF / YouTube
        .sheet(item: $linkSheetContentType) { contentType in
            LinkURLSheetView(
                initialContentType: contentType,
                // FRE has no collection context yet; picker is hidden
                // (collections: []) so user will assign on next visit.
                // A future task can wire a real collection picker here.
                collections: [],
                onComplete: { _, _ in
                    // Sheet auto-dismisses via dismiss() inside LinkURLSheetView.
                    // No FRE navigation needed — user returns to the input screen.
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden) // custom grabber rendered in the sheet
        }
    }
}

// MARK: - Error banner

private struct FREErrorBanner: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: NexusSpacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.Nexus.destructive)
            Text(message)
                .font(.system(size: 13.5))
                .kerning(-0.1)
                .foregroundColor(.Nexus.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Retry", action: onRetry)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(.Nexus.accent)
        }
        .padding(.horizontal, NexusSpacing.md)
        .padding(.vertical, 11)
        .background(Color.Nexus.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.Nexus.destructive.opacity(0.35), lineWidth: NexusBorder.base)
        )
        .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 5)
    }
}

// MARK: - Rotating word

private struct FRERotatingWord: View {
    let words: [String]
    @State private var index = 0
    @State private var visible = true

    private let timer = Timer.publish(every: 2.2, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(words[index])
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 8)
            .onReceive(timer) { _ in
                withAnimation(.easeInOut(duration: 0.24)) { visible = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                    index = (index + 1) % words.count
                    withAnimation(.easeInOut(duration: 0.26)) { visible = true }
                }
            }
    }
}

// MARK: - Composer box

private struct FREComposer: View {
    @Binding var text: String
    let onSubmit: () -> Void
    @FocusState private var focused: Bool

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Placeholder or text input
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Research a topic\u{2026}")
                        .font(.system(size: 17))
                        .foregroundColor(.Nexus.ghost)
                        .kerning(-0.2)
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                }
                TextField("", text: $text, axis: .vertical)
                    .font(.system(size: 17))
                    .foregroundColor(.Nexus.ink)
                    .focused($focused)
                    .lineLimit(1...3)
                    .keyboardType(.default)
                    .onSubmit { if hasText { onSubmit() } }
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
            }
            .padding(.bottom, 16)
            .frame(minHeight: 28)

            // Bottom toolbar — both buttons share a 42pt frame so height never shifts
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.Nexus.surface2)
                        .frame(width: 32, height: 32)
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.Nexus.ink)
                }
                .frame(height: 42)  // anchor row to 42pt so mic→send swap doesn't shift height

                Spacer()

                ZStack {
                    if hasText {
                        Button(action: onSubmit) {
                            Circle()
                                .fill(Color.Nexus.accent)
                                .frame(width: 42, height: 42)
                                .overlay(
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                )
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Circle()
                            .fill(Color.Nexus.surface2)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "mic")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.Nexus.muted)
                            )
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 42, height: 42)
                .animation(NexusAnimation.element, value: hasText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Color.Nexus.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.xxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NexusRadius.xxl, style: .continuous)
                .stroke(focused ? Color.Nexus.borderStrong : Color.Nexus.border, lineWidth: NexusBorder.base)
        )
        .animation(NexusAnimation.element, value: focused)
        .onTapGesture { focused = true }
    }
}

// MARK: - Trending icon (matches ChatGPT Search mode style)

private struct TrendingIcon: View {
    var color: Color = Color.Nexus.faint
    var size: CGFloat = 13

    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            // Zigzag line: bottom-left → dip → upper-right (stock-trend style)
            var line = Path()
            line.move(to:    CGPoint(x: 0,        y: h * 0.82))
            line.addLine(to: CGPoint(x: w * 0.30, y: h * 0.38))
            line.addLine(to: CGPoint(x: w * 0.54, y: h * 0.60))
            line.addLine(to: CGPoint(x: w,        y: 0))
            ctx.stroke(line, with: .color(color),
                       style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
            // Arrowhead at tip
            var tip = Path()
            tip.move(to:    CGPoint(x: w,        y: 0))
            tip.addLine(to: CGPoint(x: w * 0.66, y: 0))
            tip.move(to:    CGPoint(x: w,        y: 0))
            tip.addLine(to: CGPoint(x: w,        y: h * 0.34))
            ctx.stroke(tip, with: .color(color),
                       style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size * 0.82)
    }
}

// MARK: - Trending chips

private struct FRETrendingChips: View {
    var onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let rows = stride(from: 0, to: freTrending.count, by: 2).map {
                Array(freTrending[$0..<min($0 + 2, freTrending.count)])
            }
            ForEach(rows, id: \.first) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { topic in
                        Button(action: { onSelect(topic) }) {
                            HStack(spacing: 6) {
                                TrendingIcon(color: .Nexus.faint, size: 13)
                                Text(topic)
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundColor(.Nexus.ink)
                                    .kerning(-0.1)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 13)
                            .frame(height: 34)
                            .background(Color.Nexus.cardBackground)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.Nexus.border, lineWidth: NexusBorder.base))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - "Or start with a link" buttons

private struct FRELinkButtons: View {
    // Callback receives the selected content-type hint so the sheet can pre-select it.
    let onSelect: (DetectedContentType) -> Void

    private let options: [(icon: String, label: String, type: DetectedContentType)] = [
        ("globe",          "Website", .website),
        ("doc",            "PDF",     .pdf),
        ("play.rectangle", "YouTube", .youtube),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Or start with a link")
                .font(.system(size: 13))
                .foregroundColor(.Nexus.faint)
                .kerning(-0.1)

            HStack(spacing: 7) {
                ForEach(options, id: \.label) { option in
                    Button(action: { onSelect(option.type) }) {
                        VStack(spacing: 5) {
                            Image(systemName: option.icon)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.Nexus.muted)
                            Text(option.label)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.Nexus.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.Nexus.cardBackground)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.Nexus.border, lineWidth: NexusBorder.base))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Avatar button

private struct FREAvatarButton: View {
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.Nexus.surface2)
                    .frame(width: 32, height: 32)
                    .overlay(Circle().stroke(Color.Nexus.border, lineWidth: NexusBorder.hair))
                Text("S")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.Nexus.muted)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(active ? 0.88 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: active)
    }
}

// MARK: - Avatar menu card

private struct FREAvatarMenuCard: View {
    let onClose: () -> Void
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: avatar + name + email
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.Nexus.bloom)
                        .frame(width: 36, height: 36)
                    Text("S")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.Nexus.accent)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Srihari")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(UIColor.label))
                    Text("srihari.scorp@gmail.com")
                        .font(.system(size: 12))
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 8)

            ForEach(["Account", "Settings", "Feedback"], id: \.self) { label in
                AvatarMenuRow(label: label, action: onClose)
            }

            Divider().padding(.horizontal, 8)

            // Sign out — same visual weight as other rows, not red
            AvatarMenuRow(label: "Sign out") {
                onClose()
                authManager.signOut()
            }
        }
        .frame(width: 210)
        .background(
            ZStack {
                // frosted glass base
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.thinMaterial)
                // white wash so the glass reads clearly on the light plum background
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.62))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(UIColor.separator), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.14), radius: 20, x: 0, y: 8)
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
    }
}

private struct AvatarMenuRow: View {
    let label: String
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14.5, weight: .regular))
                .foregroundColor(Color(UIColor.label))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
                .background(pressed ? Color(UIColor.systemGray5) : Color.clear)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

// MARK: - Sources sheet (searching → reviewing)

private struct FRESourcesSheet: View {
    @ObservedObject var vm: ResearchViewModel

    private var isReviewing: Bool {
        if case .reviewing = vm.phase { return true }
        if case .confirming = vm.phase { return true }
        return false
    }
    private var isConfirming: Bool {
        if case .confirming = vm.phase { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            // Grabber pill
            Capsule()
                .fill(Color.Nexus.borderStrong.opacity(0.8))
                .frame(width: 36, height: 5)
                .padding(.top, 9)
                .padding(.bottom, 2)

            // Header
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(vm.topic)
                        .font(.system(size: 23, weight: .bold))
                        .foregroundColor(.Nexus.ink)
                        .kerning(-0.6)
                        .lineLimit(1)

                    if isReviewing {
                        HStack(spacing: 7) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.Nexus.ink)
                            Text("Found \(vm.sources.count) sources — tap to deselect any")
                                .font(.system(size: 13.5))
                                .foregroundColor(.Nexus.muted)
                                .kerning(-0.1)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        FRESearchingPhrase()
                            .transition(.opacity)
                    }
                }

                Spacer()

                // Close button
                Button(action: { vm.retry() }) {
                    ZStack {
                        Circle()
                            .fill(Color.Nexus.surface2)
                            .frame(width: 30, height: 30)
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.Nexus.muted)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .padding(.horizontal, NexusSpacing.standard)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .animation(NexusAnimation.element, value: isReviewing)

            // Sources list
            ScrollView {
                LazyVStack(spacing: 9) {
                    ForEach(Array(vm.sources.enumerated()), id: \.element.id) { idx, source in
                        FRESourceRow(
                            source: source,
                            isSelected: source.isSelected,
                            onToggle: { withAnimation(NexusAnimation.element) { vm.toggleSource(id: source.id) } }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                    // Shimmer placeholders while loading
                    if !isReviewing {
                        ForEach(0..<max(0, 6 - vm.sources.count), id: \.self) { _ in
                            FREShimmerRow()
                        }
                    }
                }
                .padding(.horizontal, NexusSpacing.standard)
                .padding(.top, 12)
                .padding(.bottom, isReviewing ? 110 : 20)
                .animation(NexusAnimation.element, value: vm.sources.count)
            }

            Spacer(minLength: 0)
        }
        // CTA pinned at bottom, slides up when reviewing
        .overlay(alignment: .bottom) {
            if isReviewing {
                FREConfirmBar(vm: vm, isConfirming: isConfirming)
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(NexusAnimation.element, value: isReviewing)
    }
}

// MARK: - Searching phrase animator

private struct FRESearchingPhrase: View {
    @State private var phraseIndex = 0
    @State private var phraseVisible = true

    private let timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 9) {
            // Spinner
            FRESpinner()
            Text(frePhrasesSearching[phraseIndex])
                .font(.system(size: 13.5))
                .foregroundColor(.Nexus.muted)
                .kerning(-0.1)
                .opacity(phraseVisible ? 1 : 0)
                .offset(y: phraseVisible ? 0 : 4)
                .animation(.easeInOut(duration: 0.22), value: phraseVisible)
        }
        .onReceive(timer) { _ in
            withAnimation { phraseVisible = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                phraseIndex = (phraseIndex + 1) % frePhrasesSearching.count
                withAnimation { phraseVisible = true }
            }
        }
    }
}

// MARK: - Spinner

private struct FRESpinner: View {
    @State private var rotating = false

    var body: some View {
        Circle()
            .trim(from: 0.08, to: 0.85)
            .stroke(Color.Nexus.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 15, height: 15)
            .rotationEffect(.degrees(rotating ? 360 : 0))
            .animation(.linear(duration: 0.75).repeatForever(autoreverses: false), value: rotating)
            .onAppear { rotating = true }
    }
}

// MARK: - Source row

private struct FRESourceRow: View {
    let source: ResearchSource
    let isSelected: Bool
    let onToggle: () -> Void

    @State private var pressed = false

    private var contentTypeIcon: String {
        switch source.contentType {
        case "video":   return "play.rectangle"
        case "podcast": return "mic"
        case "paper":   return "doc.text.fill"
        case "thread":  return "bubble.left.and.bubble.right"
        default:        return "globe"
        }
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .center, spacing: 12) {
                // Icon badge
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.Nexus.surface2)
                        .frame(width: 34, height: 34)
                    Image(systemName: contentTypeIcon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.Nexus.muted)
                }
                .opacity(isSelected ? 1 : 0.45)

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.title)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundColor(.Nexus.ink)
                        .kerning(-0.2)
                        .lineLimit(1)
                    Text("\(source.domain.isEmpty ? "Source" : source.domain) · \(source.contentType.isEmpty ? "Article" : source.contentType.capitalized)")
                        .font(.system(size: 12.5))
                        .foregroundColor(.Nexus.faint)
                }
                .opacity(isSelected ? 1 : 0.45)

                Spacer()

                // Checkmark circle
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? Color.Nexus.ink : Color.Nexus.borderStrong,
                            lineWidth: 1.5
                        )
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.Nexus.ink)
                            .scaleEffect(isSelected ? 1 : 0.5)
                    }
                }
                .animation(.spring(response: 0.22, dampingFraction: 0.65), value: isSelected)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(Color.Nexus.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: NexusRadius.base, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NexusRadius.base, style: .continuous)
                    .stroke(Color.Nexus.border, lineWidth: NexusBorder.base)
            )
            .scaleEffect(pressed ? 0.985 : 1.0)
            .animation(NexusAnimation.press, value: pressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

// MARK: - Shimmer placeholder row

private struct FREShimmerRow: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.Nexus.surface2)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.Nexus.surface2)
                    .frame(height: 13)
                    .padding(.trailing, 60)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.Nexus.surface2)
                    .frame(height: 11)
                    .padding(.trailing, 120)
            }

            Spacer()
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background(Color.Nexus.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.base, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NexusRadius.base, style: .continuous)
                .stroke(Color.Nexus.border, lineWidth: NexusBorder.base)
        )
        .opacity(animating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: animating)
        .onAppear { animating = true }
    }
}

// MARK: - Confirm bar (slides up on review)

private struct FREConfirmBar: View {
    @ObservedObject var vm: ResearchViewModel
    let isConfirming: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Gradient fade
            LinearGradient(
                colors: [Color.Nexus.pageEnd.opacity(0), Color.Nexus.pageEnd],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 40)

            Button(action: { Task { await vm.confirmSources() } }) {
                ZStack {
                    if isConfirming {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.85)
                    } else {
                        let count = vm.selectedSources.count
                        Text("Create collection · \(count) source\(count == 1 ? "" : "s")")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .kerning(-0.2)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(vm.canConfirm && !isConfirming ? Color.Nexus.accent : Color.Nexus.ghost)
                .clipShape(Capsule())
                .animation(NexusAnimation.element, value: isConfirming)
            }
            .disabled(!vm.canConfirm || isConfirming)
            .padding(.horizontal, NexusSpacing.standard)
            .padding(.bottom, NexusSpacing.xxl)
            .background(Color.Nexus.pageEnd)
        }
    }
}
