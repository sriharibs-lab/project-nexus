import SwiftUI

// MARK: - Create tab (artifact studio)
//
// Ported from prototype /flows/qa Create pane (IA revision 2026-07-10:
// Ask · Create · Sources). Four creation actions as cards; tapping one
// shows a brief generating beat, then the artifact card appears in the
// list below. Artifacts are MOCKS for now — real generation lands with
// the Q&A quality phase (backend artifact endpoints not yet built).

enum ArtifactKind: String, CaseIterable, Identifiable {
    case audio, info, quiz, paper
    var id: String { rawValue }

    var label: String {
        switch self {
        case .audio: return "Audio summary"
        case .info:  return "Infographic"
        case .quiz:  return "Quiz me"
        case .paper: return "Write a paper"
        }
    }

    var icon: String {
        switch self {
        case .audio: return "waveform"
        case .info:  return "chart.line.uptrend.xyaxis"
        case .quiz:  return "checkmark.circle"
        case .paper: return "doc.text"
        }
    }
}

struct CreateTabView: View {
    let collection: NexusCollection
    let items: [Item]

    @State private var artifacts: [ArtifactKind] = []
    @State private var creating: ArtifactKind?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NexusSpacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: NexusSpacing.xs) {
                    Text("CREATE")
                        .font(.Nexus.overline)
                        .foregroundColor(.Nexus.ghost)
                        .kerning(NexusKerning.wide)
                    Text("Turn this collection into something new.")
                        .font(.Nexus.bodySmall)
                        .foregroundColor(.Nexus.muted)
                }

                // 2×2 creation grid
                LazyVGrid(columns: [GridItem(.flexible(), spacing: NexusSpacing.sm), GridItem(.flexible())], spacing: NexusSpacing.sm) {
                    ForEach(ArtifactKind.allCases) { kind in
                        CreateCard(kind: kind, isBusy: creating == kind) {
                            make(kind)
                        }
                        .disabled(creating != nil)
                    }
                }

                // Generating beat
                if let kind = creating {
                    HStack(spacing: NexusSpacing.sm) {
                        EchoPulseView()
                            .frame(width: 28, height: 28)
                        Text("Creating \(kind.label.lowercased())…")
                            .font(.Nexus.bodySmall)
                            .foregroundColor(.Nexus.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, NexusSpacing.sm)
                    .transition(.opacity)
                }

                // Artifacts list (newest first)
                if !artifacts.isEmpty {
                    VStack(alignment: .leading, spacing: NexusSpacing.sm) {
                        Text("IN THIS COLLECTION")
                            .font(.Nexus.overline)
                            .foregroundColor(.Nexus.ghost)
                            .kerning(NexusKerning.wide)
                            .padding(.top, NexusSpacing.sm)

                        ForEach(Array(artifacts.enumerated()), id: \.offset) { _, kind in
                            ArtifactCard(kind: kind, collection: collection, items: items)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
            }
            .padding(.horizontal, NexusSpacing.sideGutter)
            .padding(.top, NexusSpacing.lg)
            .padding(.bottom, NexusSpacing.xl) // capsule clearance via safeAreaInset in CollectionView
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.8), value: artifacts)
        .animation(.easeInOut(duration: 0.2), value: creating)
    }

    private func make(_ kind: ArtifactKind) {
        guard creating == nil else { return }
        creating = kind
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            artifacts.insert(kind, at: 0)
            creating = nil
        }
    }
}

// MARK: - Creation card

private struct CreateCard: View {
    let kind: ArtifactKind
    let isBusy: Bool
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: kind.icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.Nexus.accent)
                    .frame(width: 22)
                Text(kind.label)
                    .font(.system(size: 13.5, weight: .semibold))
                    .kerning(-0.2)
                    .foregroundColor(.Nexus.ink)
                Spacer(minLength: 0)
            }
            .padding(13)
            .background(Color.Nexus.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.Nexus.border, lineWidth: NexusBorder.hair)
            )
            .opacity(isBusy ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? NexusScale.pressLight : 1)
        .animation(NexusAnimation.press, value: pressed)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressed = $0 }, perform: {})
    }
}

// MARK: - Artifact cards (mock designs from collection-view.jsx NxArtifact)

private struct ArtifactCard: View {
    let kind: ArtifactKind
    let collection: NexusCollection
    let items: [Item]

    var body: some View {
        switch kind {
        case .audio: audio
        case .info:  info
        case .quiz:  quiz
        case .paper: paper
        }
    }

    private var card: some ShapeStyle { Color.Nexus.cardBackground }

    private var audio: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.Nexus.ink).frame(width: 40, height: 40)
                Image(systemName: "play.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .offset(x: 1)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Audio overview")
                    .font(.system(size: 14.5, weight: .semibold))
                    .kerning(-0.2)
                    .foregroundColor(.Nexus.ink)
                Text("Two hosts · 4:32")
                    .font(.system(size: 12.5))
                    .foregroundColor(.Nexus.faint)
            }
            Spacer()
            Image(systemName: "waveform")
                .font(.system(size: 17))
                .foregroundColor(.Nexus.muted)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.Nexus.border, lineWidth: NexusBorder.hair))
    }

    private var info: some View {
        VStack(spacing: 0) {
            VStack(spacing: 7) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 24))
                    .foregroundColor(.Nexus.ghost)
                Text("Generating preview…")
                    .font(.system(size: 12))
                    .foregroundColor(.Nexus.faint)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 116)
            .background(Color.Nexus.surface2)

            Text("\(collection.name) — in 5 numbers")
                .font(.system(size: 13.5, weight: .semibold))
                .kerning(-0.2)
                .foregroundColor(.Nexus.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.Nexus.border, lineWidth: NexusBorder.hair))
    }

    private var quiz: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("QUESTION 1 OF 5")
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.7)
                .foregroundColor(.Nexus.faint)
            Text("Which outlet published “\(items.first?.title ?? "the lead source")”?")
                .fixedSize(horizontal: false, vertical: true)
                .font(.system(size: 15, weight: .semibold))
                .kerning(-0.2)
                .foregroundColor(.Nexus.ink)
                .lineSpacing(3)
                .padding(.top, 7)
            VStack(spacing: 7) {
                ForEach(quizOptions, id: \.self) { option in
                    Text(option)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(.Nexus.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 13).padding(.vertical, 10)
                        .background(Color.Nexus.surface3)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.Nexus.hair, lineWidth: NexusBorder.hair))
                }
            }
            .padding(.top, 11)
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.Nexus.border, lineWidth: NexusBorder.hair))
    }

    private var quizOptions: [String] {
        // Domain from the item URL (Item has no publisher field)
        let domains = items.prefix(2).compactMap { item -> String? in
            guard let host = URL(string: item.url)?.host else { return nil }
            return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        }
        return domains.isEmpty ? ["The Atlantic", "Reuters"] : Array(domains)
    }

    private var paper: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "doc.text")
                    .font(.system(size: 12))
                Text("DRAFT OUTLINE")
                    .kerning(0.7)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.Nexus.faint)

            Text("\(collection.name): what the sources say")
                .font(.system(size: 15, weight: .semibold))
                .kerning(-0.2)
                .foregroundColor(.Nexus.ink)
                .padding(.top, 7)

            VStack(alignment: .leading, spacing: 5) {
                Text("I. The story so far")
                Text("II. Where the sources disagree")
                Text("III. What happens next")
            }
            .font(.system(size: 13))
            .foregroundColor(.Nexus.muted)
            .lineSpacing(2)
            .padding(.top, 9)
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.Nexus.border, lineWidth: NexusBorder.hair))
    }
}
