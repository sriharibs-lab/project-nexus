import SwiftUI

// MARK: - First-run welcome
//
// A short, premium intro shown once on first launch (gated by
// UserDefaults "nexus_seen_welcome" in RootView). Four steps explain what
// Nexus is and what you can do: Research → Save → Ask → Create. Cream +
// Ember brand, custom illustrations, staggered entrance animation per page.

struct WelcomeOnboardingView: View {
    let onFinish: () -> Void

    @State private var page: Int

    init(startPage: Int = 0, onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        _page = State(initialValue: startPage)
    }

    private struct Step {
        let kind: Illustration
        let title: String
        let subtitle: String
    }
    fileprivate enum Illustration { case research, save, ask, create }

    private let steps: [Step] = [
        .init(kind: .research,
              title: "Research anything",
              subtitle: "Start with a topic. Nexus searches the web and builds a collection of the best sources for you."),
        .init(kind: .save,
              title: "Everything in one place",
              subtitle: "Save articles, videos, podcasts, and threads — neatly organized into collections."),
        .init(kind: .ask,
              title: "Ask your sources",
              subtitle: "Chat with a collection and get clear answers grounded in what you saved — with citations."),
        .init(kind: .create,
              title: "Create something new",
              subtitle: "Turn any collection into a quiz, a written report, or an audio summary in a tap."),
    ]

    private var isLast: Bool { page == steps.count - 1 }

    var body: some View {
        ZStack {
            NexusBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip
                HStack {
                    Spacer()
                    Button("Skip") { finish() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.Nexus.faint)
                        .opacity(isLast ? 0 : 1)
                        .animation(.easeInOut(duration: 0.2), value: isLast)
                }
                .padding(.horizontal, NexusSpacing.sideGutter)
                .padding(.top, 8)
                .frame(height: 44)

                TabView(selection: $page) {
                    ForEach(steps.indices, id: \.self) { i in
                        OnboardingPage(
                            illustration: steps[i].kind,
                            title: steps[i].title,
                            subtitle: steps[i].subtitle,
                            isActive: page == i
                        )
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.4), value: page)

                // Dots
                HStack(spacing: 7) {
                    ForEach(steps.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? Color.Nexus.accent : Color.Nexus.borderStrong)
                            .frame(width: i == page ? 22 : 7, height: 7)
                            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: page)
                    }
                }
                .padding(.bottom, 22)

                // CTA
                Button(action: advance) {
                    Text(isLast ? "Get started" : "Continue")
                        .font(.system(size: 16.5, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            // Ember gradient (brand hues only) + a soft top sheen.
                            ZStack {
                                LinearGradient(
                                    colors: [Color(hex: "#7054AB"), Color(hex: "#9A5BB5"), Color(hex: "#B8569C")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing)
                                LinearGradient(
                                    colors: [Color.white.opacity(0.18), .clear],
                                    startPoint: .top, endPoint: .center)
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color(hex: "#7054AB").opacity(0.30), radius: 14, y: 6)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, NexusSpacing.sideGutter)
                .padding(.bottom, NexusSpacing.safeBottom + 16)
            }
        }
    }

    private func advance() {
        Haptics.impact(.light)
        if isLast { finish() }
        else { withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.4)) { page += 1 } }
    }

    private func finish() {
        Haptics.impact(.medium)
        onFinish()
    }
}

// MARK: - Page

private struct OnboardingPage: View {
    let illustration: WelcomeOnboardingView.Illustration
    let title: String
    let subtitle: String
    let isActive: Bool

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            illustrationView
                .frame(height: 300)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.92)
                .animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.6), value: appeared)

            Spacer(minLength: 0)

            VStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 30, weight: .bold))
                    .kerning(-0.6)
                    .foregroundColor(.Nexus.ink)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.5).delay(0.08), value: appeared)

                Text(subtitle)
                    .font(.system(size: 16))
                    .foregroundColor(.Nexus.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.5).delay(0.15), value: appeared)
            }
            .padding(.horizontal, NexusSpacing.sideGutter + 6)
            .frame(height: 170, alignment: .top)
        }
        .onAppear { if isActive { appeared = true } }
        .onChange(of: isActive) { _, active in
            if active { appeared = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { appeared = true } }
        }
    }

    @ViewBuilder
    private var illustrationView: some View {
        switch illustration {
        case .research: ResearchArt()
        case .save:     SaveArt()
        case .ask:      AskArt()
        case .create:   CreateArt()
        }
    }
}

// MARK: - Illustrations
//
// Premium pass (device review 2026-10): continuous ambient motion, layered
// depth, restrained Ember gradients. All motion is slow and easeful — ambience,
// not spectacle. Respects Reduce Motion (drift/orbit collapse to static).

/// Ambient ember glow — two soft radial pools that slowly drift and breathe,
/// giving the scene living depth without adding color.
private struct EmberGlow: View {
    var size: CGFloat = 240
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color(hex: "#E8776A").opacity(0.20), .clear],
                center: .center, startRadius: 2, endRadius: size * 0.42
            )
            .frame(width: size, height: size)
            .offset(x: drift ? -18 : 14, y: drift ? 10 : -12)
            .scaleEffect(drift ? 1.08 : 0.96)

            RadialGradient(
                colors: [Color(hex: "#7054AB").opacity(0.16), .clear],
                center: .center, startRadius: 2, endRadius: size * 0.5
            )
            .frame(width: size * 1.15, height: size * 1.15)
            .offset(x: drift ? 16 : -12, y: drift ? -8 : 12)
            .scaleEffect(drift ? 0.97 : 1.06)
        }
        .blur(radius: 14)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 5.2).repeatForever(autoreverses: true)) { drift = true }
        }
    }
}

/// A floating white tile with layered depth (ambient + contact shadows) that
/// gently bobs on its own phase — shared by the illustration scenes.
private struct FloatingTile<Content: View>: View {
    var amplitude: CGFloat = 5
    var period: Double = 3.4
    var phase: Double = 0
    @ViewBuilder let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            content
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                content
                    .offset(y: sin((t + phase) * 2 * .pi / period) * amplitude)
            }
        }
    }
}

/// Step 1 — the Echo mark breathing at the center while source chips orbit
/// slowly around it (satellites being gathered in).
private struct ResearchArt: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private struct Chip { let icon: String; let fg: Color; let angle: Double }
    private let chips: [Chip] = [
        .init(icon: "doc.text.fill", fg: Color(hex: "#4A7ABB"), angle: 215),
        .init(icon: "play.rectangle.fill", fg: Color(hex: "#B84C3A"), angle: 325),
        .init(icon: "waveform", fg: Color(hex: "#4A8A5C"), angle: 145),
        .init(icon: "bubble.left.fill", fg: Color(hex: "#B8862A"), angle: 35),
    ]
    private let radius: CGFloat = 118

    var body: some View {
        ZStack {
            EmberGlow(size: 280)

            // Faint orbit ring — depth cue for the motion path.
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "#7054AB").opacity(0.18), Color(hex: "#E8776A").opacity(0.10)],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 7])
                )
                .frame(width: radius * 2, height: radius * 2)

            if reduceMotion {
                ForEach(chips.indices, id: \.self) { i in
                    chipView(chips[i])
                        .offset(x: radius * cos(chips[i].angle * .pi / 180),
                                y: radius * sin(chips[i].angle * .pi / 180))
                }
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let orbit = (t / 26.0) * 360.0   // one slow revolution / 26s
                    ZStack {
                        ForEach(chips.indices, id: \.self) { i in
                            let a = (chips[i].angle + orbit) * .pi / 180
                            chipView(chips[i])
                                .offset(x: radius * cos(a), y: radius * sin(a))
                        }
                    }
                }
            }

            // The mark itself, breathing (reuses the brand pulse).
            EchoPulseView()
                .scaleEffect(2.6)
                .frame(width: 100, height: 100)
        }
    }

    private func chipView(_ chip: Chip) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.Nexus.cardBackground)
            .frame(width: 52, height: 52)
            .shadow(color: Color(hex: "#5E3F9E").opacity(0.10), radius: 14, y: 6)
            .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
            .overlay(
                Image(systemName: chip.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(chip.fg)
            )
    }
}

/// Step 2 — a deck of saved source cards, each floating on its own phase.
private struct SaveArt: View {
    private let cards: [(String, Color, Color, CGFloat, Double)] = [
        ("play.rectangle.fill", Color(hex: "#B84C3A"), Color(hex: "#FCF0EE"), 118, 0.0),
        ("waveform", Color(hex: "#4A8A5C"), Color(hex: "#F0F7EE"), 92, 1.1),
        ("doc.text.fill", Color(hex: "#4A7ABB"), Color(hex: "#EEF3FB"), 134, 2.2),
    ]
    var body: some View {
        ZStack {
            EmberGlow(size: 260)
            VStack(spacing: 15) {
                ForEach(cards.indices, id: \.self) { i in
                    FloatingTile(amplitude: 4, period: 3.8, phase: cards[i].4) {
                        card(icon: cards[i].0, fg: cards[i].1, bg: cards[i].2, titleWidth: cards[i].3)
                    }
                }
            }
        }
    }
    private func card(icon: String, fg: Color, bg: Color, titleWidth: CGFloat) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(bg).frame(width: 40, height: 40)
                .overlay(Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundColor(fg))
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 3).fill(Color.Nexus.ink.opacity(0.82)).frame(width: titleWidth, height: 8)
                RoundedRectangle(cornerRadius: 3).fill(Color.Nexus.faint.opacity(0.45)).frame(width: titleWidth * 0.6, height: 7)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: 272)
        .background(Color.Nexus.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            // Gradient hairline — quiet Ember edge-light for depth.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "#7054AB").opacity(0.14), Color(hex: "#E8776A").opacity(0.10)],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
        .shadow(color: Color(hex: "#5E3F9E").opacity(0.10), radius: 16, y: 7)
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }
}

/// Step 3 — a grounded answer "typing in": skeleton lines sweep in one after
/// another, then the citation chips pop. Loops gently.
private struct AskArt: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cycle = 0           // bump to replay
    @State private var lineProgress: [CGFloat] = [0, 0, 0]
    @State private var chipsShown = false

    private let lineWidths: [CGFloat] = [248, 248, 150]

    var body: some View {
        ZStack {
            EmberGlow(size: 260)
            VStack(alignment: .leading, spacing: 14) {
                // user bubble
                HStack {
                    Spacer()
                    Text("What's the key takeaway?")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(.Nexus.ink)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color.Nexus.bloom.opacity(0.75), Color.Nexus.bloom.opacity(0.45)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color(hex: "#5E3F9E").opacity(0.08), radius: 8, y: 3)
                }
                // answer card
                FloatingTile(amplitude: 3.5, period: 4.2, phase: 0.8) {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(lineWidths.indices, id: \.self) { i in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.Nexus.surface2)
                                    .frame(width: lineWidths[i], height: 8)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.Nexus.ink.opacity(0.8))
                                    .frame(width: lineWidths[i] * lineProgress[i], height: 8)
                            }
                        }
                        HStack(spacing: 6) {
                            ForEach(1...2, id: \.self) { n in
                                Text("\(n)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.Nexus.accent)
                                    .frame(width: 20, height: 20)
                                    .background(Color.Nexus.accent.opacity(0.12))
                                    .clipShape(Circle())
                                    .scaleEffect(chipsShown ? 1 : 0.3)
                                    .opacity(chipsShown ? 1 : 0)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.65).delay(Double(n) * 0.1), value: chipsShown)
                            }
                            Text("Sources")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(.Nexus.faint)
                                .opacity(chipsShown ? 1 : 0)
                                .animation(.easeIn(duration: 0.3).delay(0.3), value: chipsShown)
                        }
                        .padding(.top, 2)
                    }
                    .padding(16)
                    .background(Color.Nexus.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "#7054AB").opacity(0.14), Color(hex: "#E8776A").opacity(0.10)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color(hex: "#5E3F9E").opacity(0.10), radius: 16, y: 7)
                    .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
                }
            }
            .frame(width: 280)
        }
        .onAppear { playTyping() }
    }

    private func playTyping() {
        if reduceMotion {
            lineProgress = [1, 1, 1]; chipsShown = true
            return
        }
        lineProgress = [0, 0, 0]; chipsShown = false
        for i in 0..<3 {
            withAnimation(.easeOut(duration: 0.55).delay(0.25 + Double(i) * 0.45)) {
                lineProgress[i] = 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { chipsShown = true }
    }
}

/// Step 4 — the Create artifact tiles popping in with a stagger, then
/// floating on independent phases.
private struct CreateArt: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = [false, false, false, false]

    private let tiles: [(String, String, Color, Color, Double)] = [
        ("checkmark.circle.fill", "Quiz", Color(hex: "#B8862A"), Color(hex: "#FDF5E8"), 0.0),
        ("doc.text.fill", "Report", Color(hex: "#4A7ABB"), Color(hex: "#EEF3FB"), 1.3),
        ("waveform", "Audio", Color(hex: "#7054AB"), Color(hex: "#F0ECF9"), 2.1),
        ("chart.bar.fill", "Infographic", Color(hex: "#4A8A5C"), Color(hex: "#F0F7EE"), 0.7),
    ]
    private let cols = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ZStack {
            EmberGlow(size: 260)
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(tiles.indices, id: \.self) { i in
                    FloatingTile(amplitude: 3.5, period: 4.0, phase: tiles[i].4) {
                        tile(i)
                    }
                    .scaleEffect(shown[i] ? 1 : 0.6)
                    .opacity(shown[i] ? 1 : 0)
                }
            }
            .frame(width: 280)
        }
        .onAppear {
            if reduceMotion { shown = [true, true, true, true]; return }
            for i in 0..<4 {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.68).delay(0.15 + Double(i) * 0.09)) {
                    shown[i] = true
                }
            }
        }
    }

    private func tile(_ i: Int) -> some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tiles[i].3).frame(width: 48, height: 48)
                .overlay(Image(systemName: tiles[i].0).font(.system(size: 22, weight: .semibold)).foregroundColor(tiles[i].2))
            Text(tiles[i].1)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(.Nexus.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.Nexus.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "#7054AB").opacity(0.12), Color(hex: "#E8776A").opacity(0.09)],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
        .shadow(color: Color(hex: "#5E3F9E").opacity(0.09), radius: 14, y: 6)
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }
}

#if DEBUG
#Preview { WelcomeOnboardingView(onFinish: {}) }
#endif
