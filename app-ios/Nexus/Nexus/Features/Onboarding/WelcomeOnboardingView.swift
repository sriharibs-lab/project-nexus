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
                        .background(Color.Nexus.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.Nexus.accent.opacity(0.25), radius: 12, y: 5)
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

/// A soft ember glow behind content.
private struct EmberGlow: View {
    var size: CGFloat = 220
    var body: some View {
        RadialGradient(
            colors: [Color(hex: "#E8776A").opacity(0.18), Color(hex: "#7054AB").opacity(0.10), .clear],
            center: .center, startRadius: 2, endRadius: size / 2
        )
        .frame(width: size, height: size)
        .blur(radius: 6)
    }
}

/// Step 1 — the Echo mark with sources gathering around it.
private struct ResearchArt: View {
    private let chips: [(String, Color, Color, CGSize)] = [
        ("doc.text.fill", Color(hex: "#4A7ABB"), Color(hex: "#EEF3FB"), CGSize(width: -96, height: -84)),
        ("play.rectangle.fill", Color(hex: "#B84C3A"), Color(hex: "#FCF0EE"), CGSize(width: 104, height: -56)),
        ("waveform", Color(hex: "#4A8A5C"), Color(hex: "#F0F7EE"), CGSize(width: -104, height: 72)),
        ("bubble.left.fill", Color(hex: "#B8862A"), Color(hex: "#FDF5E8"), CGSize(width: 92, height: 86)),
    ]
    var body: some View {
        ZStack {
            EmberGlow(size: 260)
            ForEach(chips.indices, id: \.self) { i in
                sourceChip(icon: chips[i].0, fg: chips[i].1, bg: chips[i].2)
                    .offset(chips[i].3)
            }
            EchoMark(size: 92)
        }
    }
    private func sourceChip(icon: String, fg: Color, bg: Color) -> some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(Color.Nexus.cardBackground)
            .frame(width: 54, height: 54)
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(fg)
            )
    }
}

/// Step 2 — a clean deck of saved source cards.
private struct SaveArt: View {
    private let cards: [(String, Color, Color, CGFloat)] = [
        ("play.rectangle.fill", Color(hex: "#B84C3A"), Color(hex: "#FCF0EE"), 118),
        ("waveform", Color(hex: "#4A8A5C"), Color(hex: "#F0F7EE"), 92),
        ("doc.text.fill", Color(hex: "#4A7ABB"), Color(hex: "#EEF3FB"), 134),
    ]
    var body: some View {
        ZStack {
            EmberGlow(size: 250)
            VStack(spacing: 14) {
                ForEach(cards.indices, id: \.self) { i in
                    card(icon: cards[i].0, fg: cards[i].1, bg: cards[i].2, titleWidth: cards[i].3)
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
        .shadow(color: .black.opacity(0.07), radius: 11, y: 4)
    }
}

/// Step 3 — a grounded answer with a citation.
private struct AskArt: View {
    var body: some View {
        ZStack {
            EmberGlow(size: 240)
            VStack(alignment: .leading, spacing: 14) {
                // user bubble
                HStack {
                    Spacer()
                    Text("What's the key takeaway?")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(.Nexus.ink)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color.Nexus.bloom.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                // answer card
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.Nexus.ink.opacity(0.8)).frame(height: 8)
                    RoundedRectangle(cornerRadius: 3).fill(Color.Nexus.ink.opacity(0.8)).frame(height: 8)
                    RoundedRectangle(cornerRadius: 3).fill(Color.Nexus.ink.opacity(0.8)).frame(width: 150, height: 8)
                    HStack(spacing: 6) {
                        ForEach(1...2, id: \.self) { n in
                            Text("\(n)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.Nexus.accent)
                                .frame(width: 20, height: 20)
                                .background(Color.Nexus.accent.opacity(0.12))
                                .clipShape(Circle())
                        }
                        Text("Sources")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(.Nexus.faint)
                    }
                    .padding(.top, 2)
                }
                .padding(16)
                .background(Color.Nexus.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 14, y: 5)
            }
            .frame(width: 280)
        }
    }
}

/// Step 4 — the Create artifact tiles.
private struct CreateArt: View {
    private let tiles: [(String, String, Color, Color)] = [
        ("checkmark.circle.fill", "Quiz", Color(hex: "#B8862A"), Color(hex: "#FDF5E8")),
        ("doc.text.fill", "Report", Color(hex: "#4A7ABB"), Color(hex: "#EEF3FB")),
        ("waveform", "Audio", Color(hex: "#7054AB"), Color(hex: "#F0ECF9")),
        ("chart.bar.fill", "Infographic", Color(hex: "#4A8A5C"), Color(hex: "#F0F7EE")),
    ]
    private let cols = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
    var body: some View {
        ZStack {
            EmberGlow(size: 240)
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(tiles.indices, id: \.self) { i in
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
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
                }
            }
            .frame(width: 280)
        }
    }
}

#if DEBUG
#Preview { WelcomeOnboardingView(onFinish: {}) }
#endif
