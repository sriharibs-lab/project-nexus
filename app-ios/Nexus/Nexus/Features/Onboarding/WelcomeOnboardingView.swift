import SwiftUI

// MARK: - First-run welcome
//
// A short, premium intro shown once on first launch (gated by
// UserDefaults "nexus_seen_welcome" in RootView). Three steps explain what
// Nexus is and what you can do: Research → Ask → Create — each a looping,
// choreographed scene that shows the product "taking shape" (typing →
// retrieval → synthesis / a back-and-forth / an infographic assembling).

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
    fileprivate enum Illustration { case research, ask, create }

    private let steps: [Step] = [
        .init(kind: .research,
              title: "Research anything",
              subtitle: "Start with a topic. Nexus finds the best sources and keeps them in one place."),
        .init(kind: .ask,
              title: "Ask your sources",
              subtitle: "Chat with a collection and get clear answers grounded in what you saved — with citations."),
        .init(kind: .create,
              title: "Create something new",
              subtitle: "Watch your sources become a quiz, a report, or an infographic."),
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
        case .research: ResearchArt(active: isActive)
        case .ask:      AskArt(active: isActive)
        case .create:   CreateArt(active: isActive)
        }
    }
}

// MARK: - Illustrations
//
// Three choreographed, looping scenes (founder brief 2026-10): "beautiful
// taking shape in front of the user's eyes." Every element derives its state
// from a shared SCENE CLOCK (elapsed seconds, modulo the loop) — deterministic,
// loops cleanly, no leaked timers, and pages that aren't active show their
// finished frame. Ember-only hues, layered depth, honors Reduce Motion.

// MARK: Scene clock + easing

private struct Choreo {
    let t: Double
    let loop: Double
    /// Linear 0…1 across [a, b].
    func lin(_ a: Double, _ b: Double) -> Double {
        min(max((t - a) / max(b - a, 0.0001), 0), 1)
    }
    /// Ease-out cubic 0…1 across [a, b].
    func p(_ a: Double, _ b: Double) -> Double {
        let x = lin(a, b); return 1 - pow(1 - x, 3)
    }
    /// Ease-out-back (slight overshoot) 0…1 across [a, b] — for pops.
    func pop(_ a: Double, _ b: Double) -> Double {
        let x = lin(a, b); let c1 = 1.70158, c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }
    /// Whole-scene opacity: fade in at start, fade out just before the loop resets.
    var fade: Double { min(lin(0, 0.3), 1 - lin(loop - 0.45, loop)) }
    func blink(_ period: Double = 1.0) -> Bool {
        (t / period).truncatingRemainder(dividingBy: 1) < 0.55
    }
}

private struct SceneClock<Content: View>: View {
    let loop: Double
    let finishedAt: Double
    let active: Bool
    @ViewBuilder let content: (Choreo) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    var body: some View {
        if reduceMotion || !active {
            content(Choreo(t: finishedAt, loop: loop))
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
                let e = tl.date.timeIntervalSince(start).truncatingRemainder(dividingBy: loop)
                content(Choreo(t: max(e, 0), loop: loop))
            }
            .onAppear { start = Date() }
        }
    }
}

// MARK: Shared styling

private func emberHairline() -> LinearGradient {
    LinearGradient(
        colors: [Color(hex: "#7054AB").opacity(0.16), Color(hex: "#E8776A").opacity(0.11)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// White card with Ember hairline + layered plum ambient / contact shadows.
private struct EmberCard: ViewModifier {
    var radius: CGFloat = 18
    func body(content: Content) -> some View {
        content
            .background(Color.Nexus.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(emberHairline(), lineWidth: 1))
            .shadow(color: Color(hex: "#5E3F9E").opacity(0.10), radius: 16, y: 7)
            .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }
}
private extension View {
    func emberCard(radius: CGFloat = 18) -> some View { modifier(EmberCard(radius: radius)) }
}

/// Ambient ember glow — two soft radial pools that slowly drift and breathe.
private struct EmberGlow: View {
    var size: CGFloat = 240
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: "#E8776A").opacity(0.20), .clear],
                           center: .center, startRadius: 2, endRadius: size * 0.42)
                .frame(width: size, height: size)
                .offset(x: drift ? -18 : 14, y: drift ? 10 : -12)
                .scaleEffect(drift ? 1.08 : 0.96)
            RadialGradient(colors: [Color(hex: "#7054AB").opacity(0.16), .clear],
                           center: .center, startRadius: 2, endRadius: size * 0.5)
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

/// The composer pill a "user" types into — character-by-character with a
/// blinking caret, then the Ember send dot pulses.
private struct TypingPill: View {
    let text: String
    let placeholder: String
    let typing: Double      // 0…1
    let caretOn: Bool
    let sendPulse: Double   // 0…1 (one pulse)
    var width: CGFloat = 282

    var body: some View {
        let n = Int((Double(text.count) * typing).rounded())
        let shown = String(text.prefix(n))
        HStack(spacing: 10) {
            HStack(spacing: 1) {
                if shown.isEmpty {
                    Text(placeholder).font(.system(size: 14.5)).foregroundColor(.Nexus.ghost)
                } else {
                    Text(shown).font(.system(size: 14.5, weight: .medium)).foregroundColor(.Nexus.ink).lineLimit(1)
                }
                Rectangle().fill(Color.Nexus.accent).frame(width: 2, height: 17)
                    .opacity(caretOn ? 1 : 0)
            }
            Spacer(minLength: 0)
            Circle()
                .fill(LinearGradient(colors: [Color(hex: "#7054AB"), Color(hex: "#E8776A")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 28, height: 28)
                .overlay(Image(systemName: "arrow.up").font(.system(size: 12, weight: .bold)).foregroundColor(.white))
                .scaleEffect(1 + 0.28 * sin(sendPulse * .pi))
                .shadow(color: Color(hex: "#7054AB").opacity(0.35 * sin(sendPulse * .pi)), radius: 10)
                .opacity(typing >= 0.999 ? 1 : 0.35)
        }
        .padding(.leading, 16).padding(.trailing, 9)
        .frame(width: width, height: 48)
        .emberCard(radius: 24)
    }
}

/// A 52pt source chip (white tile + colored glyph).
private struct SourceChip: View {
    let icon: String
    let fg: Color
    var size: CGFloat = 52
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(Color.Nexus.cardBackground)
            .frame(width: size, height: size)
            .overlay(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous).stroke(emberHairline(), lineWidth: 1))
            .shadow(color: Color(hex: "#5E3F9E").opacity(0.10), radius: 12, y: 5)
            .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
            .overlay(Image(systemName: icon).font(.system(size: size * 0.38, weight: .semibold)).foregroundColor(fg))
    }
}

// MARK: Step 1 — Research: type → sources fly in → settle into a collection

private struct ResearchArt: View {
    let active: Bool
    private struct Chip { let icon: String; let fg: Color; let from: CGSize; let scatter: CGSize; let slot: CGFloat }
    private let chips: [Chip] = [
        .init(icon: "doc.text.fill",        fg: Color(hex: "#4A7ABB"), from: CGSize(width: -240, height: -150), scatter: CGSize(width: -96, height: -30), slot: -80),
        .init(icon: "play.rectangle.fill",  fg: Color(hex: "#B84C3A"), from: CGSize(width: 0,    height: -240), scatter: CGSize(width: -4,  height: -56), slot: -40),
        .init(icon: "waveform",             fg: Color(hex: "#4A8A5C"), from: CGSize(width: 240,  height: -150), scatter: CGSize(width: 92,  height: -30), slot: 0),
        .init(icon: "bubble.left.fill",     fg: Color(hex: "#B8862A"), from: CGSize(width: -240, height: 80),   scatter: CGSize(width: -52, height: 14),  slot: 40),
        .init(icon: "text.quote",           fg: Color(hex: "#7054AB"), from: CGSize(width: 240,  height: 80),   scatter: CGSize(width: 50,  height: 14),  slot: 80),
    ]
    private let typed = "The attention economy"
    private let containerY: CGFloat = 86
    private let slotY: CGFloat = 88

    var body: some View {
        SceneClock(loop: 9.8, finishedAt: 7.6, active: active) { c in
            ZStack {
                EmberGlow(size: 280)
                TypingPill(text: typed, placeholder: "Research a topic…",
                           typing: c.p(0.4, 2.1), caretOn: c.t < 2.5 && c.blink(0.9),
                           sendPulse: c.lin(2.25, 2.75))
                    .offset(y: -118)
                container(c).offset(y: containerY)
                ForEach(chips.indices, id: \.self) { i in chip(i, c) }
            }
            .opacity(c.fade)
        }
    }

    private func landedCount(_ c: Choreo) -> Int {
        chips.indices.filter { c.t >= 5.0 + Double($0) * 0.18 + 0.6 }.count
    }

    private func chip(_ i: Int, _ c: Choreo) -> some View {
        let ch = chips[i]
        let s0 = 2.75 + Double(i) * 0.32                 // fly-in
        let fly = c.p(s0, s0 + 0.75)
        let s1 = 5.0 + Double(i) * 0.18                  // converge
        let conv = c.p(s1, s1 + 0.65)
        let x = ch.from.width  + (ch.scatter.width  - ch.from.width)  * fly + (ch.slot - ch.scatter.width) * conv
        let y = ch.from.height + (ch.scatter.height - ch.from.height) * fly + (slotY - ch.scatter.height) * conv
        let size: CGFloat = 52 - 24 * conv               // 52 → 28 as it settles
        let spark = sin(c.lin(s0 + 0.55, s0 + 1.0) * .pi)   // flash on arrival
        return ZStack {
            Circle()
                .stroke(Color(hex: "#E8776A").opacity(0.55 * spark), lineWidth: 2)
                .frame(width: size + 14 + 16 * spark, height: size + 14 + 16 * spark)
            SourceChip(icon: ch.icon, fg: ch.fg, size: size)
        }
        .opacity(c.lin(s0, s0 + 0.15))
        .offset(x: x, y: y)
    }

    private func container(_ c: Choreo) -> some View {
        let draw = c.p(4.7, 5.5)
        let fill = c.p(4.9, 5.4)
        let titleIn = c.p(5.3, 5.7)
        let seal = 1 + 0.22 * sin(c.lin(6.3, 6.95) * .pi)
        let n = landedCount(c)
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.Nexus.cardBackground)
                .opacity(fill)
                .shadow(color: Color(hex: "#5E3F9E").opacity(0.10 * fill), radius: 16, y: 7)
                .shadow(color: .black.opacity(0.04 * fill), radius: 3, y: 1)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .trim(from: 0, to: draw)
                .stroke(emberHairline(), lineWidth: 1.2)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    EchoMark(size: 18).scaleEffect(seal)
                    Text("The attention economy")
                        .font(.system(size: 14.5, weight: .semibold)).kerning(-0.2)
                        .foregroundColor(.Nexus.ink)
                    Spacer()
                }
                .opacity(titleIn)
                .offset(x: -6 * (1 - titleIn))
                Spacer()
                // slot placeholders the chips settle into
                HStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { _ in
                        Circle().stroke(Color.Nexus.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                            .frame(width: 28, height: 28)
                    }
                }
                .frame(maxWidth: .infinity)
                .opacity(fill)
                Spacer()
                Text(n == 0 ? "Gathering sources…" : "\(n) source\(n == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.Nexus.faint)
                    .opacity(titleIn)
                    .contentTransition(.numericText())
            }
            .padding(14)
        }
        .frame(width: 272, height: 112)
    }
}

// MARK: Step 2 — Ask: a real back-and-forth that scrolls as it grows

private struct AskArt: View {
    let active: Bool

    var body: some View {
        SceneClock(loop: 11.4, finishedAt: 9.2, active: active) { c in
            ZStack {
                EmberGlow(size: 260)
                VStack(alignment: .leading, spacing: 12) {
                    userBubble("What's the key takeaway?", c, start: 0.3)
                    answerCard(c, start: 1.9, chips: [1, 2], widths: [248, 248, 150])
                    userBubble("How do the sources disagree?", c, start: 4.3)
                    answerCard(c, start: 6.0, chips: [3, 4], widths: [248, 196, 172])
                }
                .frame(width: 280)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 34)
                .offset(y: -c.p(3.95, 4.7) * 140)   // thread scrolls up for the 2nd exchange
            }
            .frame(height: 300)
            .clipped()
            .opacity(c.fade)
        }
    }

    private func userBubble(_ text: String, _ c: Choreo, start: Double) -> some View {
        let typing = c.p(start, start + 1.15)
        let n = Int((Double(text.count) * typing).rounded())
        let caret = c.t < start + 1.4 && c.blink(0.8)
        return HStack {
            Spacer()
            HStack(spacing: 1) {
                Text(String(text.prefix(n)))
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(.Nexus.ink)
                Rectangle().fill(Color.Nexus.accent).frame(width: 2, height: 15).opacity(caret ? 1 : 0)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(LinearGradient(colors: [Color.Nexus.bloom.opacity(0.78), Color.Nexus.bloom.opacity(0.46)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color(hex: "#5E3F9E").opacity(0.08), radius: 8, y: 3)
        }
        .opacity(c.lin(start, start + 0.2))
        .offset(y: 8 * (1 - c.p(start, start + 0.35)))
    }

    private func answerCard(_ c: Choreo, start: Double, chips: [Int], widths: [CGFloat]) -> some View {
        let appear = c.pop(start, start + 0.45)
        return VStack(alignment: .leading, spacing: 9) {
            ForEach(widths.indices, id: \.self) { i in
                let w = widths[i]
                let sweep = c.p(start + 0.3 + Double(i) * 0.4, start + 0.85 + Double(i) * 0.4)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.Nexus.surface2).frame(width: w, height: 8)
                    RoundedRectangle(cornerRadius: 3).fill(Color.Nexus.ink.opacity(0.8)).frame(width: w * sweep, height: 8)
                }
            }
            HStack(spacing: 6) {
                ForEach(chips.indices, id: \.self) { i in
                    let s = c.pop(start + 1.55 + Double(i) * 0.12, start + 1.95 + Double(i) * 0.12)
                    Text("\(chips[i])")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.Nexus.accent)
                        .frame(width: 20, height: 20)
                        .background(Color.Nexus.accent.opacity(0.12)).clipShape(Circle())
                        .scaleEffect(max(s, 0.001)).opacity(min(s * 1.5, 1))
                }
                Text("Sources").font(.system(size: 11.5, weight: .medium)).foregroundColor(.Nexus.faint)
                    .opacity(c.p(start + 1.9, start + 2.2))
            }
            .padding(.top, 2)
        }
        .padding(16)
        .emberCard(radius: 18)
        .scaleEffect(0.92 + 0.08 * appear)
        .opacity(min(appear * 1.4, 1))
    }
}

// MARK: Step 3 — Create: type → shimmer → an infographic assembles

private struct CreateArt: View {
    let active: Bool
    private let typed = "Infographic: key numbers"
    private struct Stat { let target: Double; let fmt: (Double) -> String; let label: String; let bar: CGFloat }
    private let stats: [Stat] = [
        .init(target: 91,    fmt: { "\(Int($0.rounded()))" },                                   label: "years lived",      bar: 0.92),
        .init(target: 50000, fmt: { $0 >= 49_900 ? "50k+" : "\(Int(($0 / 1000).rounded()))k" }, label: "works created",    bar: 1.0),
        .init(target: 1937,  fmt: { "\(Int($0.rounded()))" },                                   label: "Guernica painted", bar: 0.78),
        .init(target: 4,     fmt: { "\(Int($0.rounded()))" },                                   label: "major periods",    bar: 0.5),
    ]
    private let cols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        SceneClock(loop: 10.6, finishedAt: 8.3, active: active) { c in
            ZStack {
                EmberGlow(size: 280)
                TypingPill(text: typed, placeholder: "Create something…",
                           typing: c.p(0.3, 1.9), caretOn: c.t < 2.3 && c.blink(0.9),
                           sendPulse: c.lin(2.05, 2.55))
                    .offset(y: -124)
                infographic(c).offset(y: 30)
            }
            .opacity(c.fade)
        }
    }

    private func infographic(_ c: Choreo) -> some View {
        let frameIn = c.p(2.3, 2.9)
        let shimmer = c.lin(2.55, 3.35)
        let titleIn = c.p(3.25, 3.65)
        let sourcesIn = c.pop(5.75, 6.15)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Picasso — in numbers")
                .font(.system(size: 15, weight: .bold)).kerning(-0.3)
                .foregroundColor(.Nexus.ink)
                .opacity(titleIn)
                .offset(x: -8 * (1 - titleIn))
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(stats.indices, id: \.self) { i in statTile(i, c) }
            }
            HStack(spacing: 6) {
                Image(systemName: "link").font(.system(size: 10, weight: .bold))
                Text("Sources · 6").font(.system(size: 11.5, weight: .semibold))
            }
            .foregroundColor(.Nexus.accent)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.Nexus.accent.opacity(0.10)).clipShape(Capsule())
            .scaleEffect(max(sourcesIn, 0.001)).opacity(min(sourcesIn * 1.5, 1))
        }
        .padding(14)
        .frame(width: 272)
        .background(Color.Nexus.cardBackground)
        .overlay(
            // Ember "generating" shimmer — one diagonal sweep across the empty card.
            LinearGradient(colors: [.clear, Color(hex: "#E8776A").opacity(0.22), Color(hex: "#7054AB").opacity(0.16), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: 140)
                .rotationEffect(.degrees(18))
                .offset(x: -260 + 520 * shimmer)
                .opacity(shimmer > 0 && shimmer < 1 ? 1 : 0)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).trim(from: 0, to: frameIn).stroke(emberHairline(), lineWidth: 1.2))
        .shadow(color: Color(hex: "#5E3F9E").opacity(0.10 * frameIn), radius: 16, y: 7)
        .shadow(color: .black.opacity(0.04 * frameIn), radius: 3, y: 1)
        .scaleEffect(0.96 + 0.04 * frameIn)
        .opacity(frameIn)
    }

    private func statTile(_ i: Int, _ c: Choreo) -> some View {
        let st = stats[i]
        let start = 3.6 + Double(i) * 0.35
        let popIn = c.pop(start, start + 0.45)
        let count = c.p(start + 0.1, start + 1.0)
        let bar = c.p(start + 0.25, start + 1.15)
        return VStack(alignment: .leading, spacing: 5) {
            Text(st.fmt(st.target * count))
                .font(.system(size: 20, weight: .bold, design: .rounded)).kerning(-0.5)
                .foregroundColor(.Nexus.ink)
                .monospacedDigit()
            Text(st.label).font(.system(size: 11, weight: .medium)).foregroundColor(.Nexus.faint)
            GeometryReader { g in
                Capsule().fill(Color.Nexus.surface2).frame(height: 4)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(LinearGradient(colors: [Color(hex: "#7054AB"), Color(hex: "#E8776A")], startPoint: .leading, endPoint: .trailing))
                            .frame(width: g.size.width * st.bar * bar, height: 4)
                    }
            }
            .frame(height: 4)
            .padding(.top, 3)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Nexus.surface2.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .scaleEffect(0.6 + 0.4 * max(popIn, 0))
        .opacity(min(popIn * 1.5, 1))
    }
}
