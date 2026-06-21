import SwiftUI

// MARK: - LoadingStateView
//
// Reusable loading state using shimmer skeleton cards.
//
// Uses .redacted(.placeholder) on placeholder card shapes
// combined with a shimmer overlay for on-brand polish.
//
// Usage:
//   LoadingStateView()                     // default: 3 skeleton cards
//   LoadingStateView(cardCount: 5)         // custom count
//
// Design rules (DESIGN_LANGUAGE.md):
//   • Inline surface: solid fill + hairline border (not glass)
//   • Shimmer direction: leading → trailing with plum-tinted highlight
//   • No heavy shadows — quiet and legible

struct LoadingStateView: View {
    var cardCount: Int = 3

    var body: some View {
        ScrollView {
            LazyVStack(spacing: NexusSpacing.sm) {
                ForEach(0..<cardCount, id: \.self) { _ in
                    SkeletonCard()
                }
            }
            .padding(.horizontal, NexusSpacing.sideGutter)
            .padding(.top, NexusSpacing.sm)
            .padding(.bottom, NexusSpacing.xl)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - SkeletonCard

private struct SkeletonCard: View {
    @State private var shimmerPhase: CGFloat = -1

    var body: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.sm) {
            // Header row: icon placeholder + two text lines
            HStack(alignment: .top, spacing: NexusSpacing.md) {
                // Icon badge placeholder
                RoundedRectangle(cornerRadius: NexusRadius.xs)
                    .fill(Color.Nexus.surface2)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: NexusSpacing.xs) {
                    // Title line — full width
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.Nexus.surface2)
                        .frame(height: 13)
                    // Domain / subtitle line — shorter
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.Nexus.surface2)
                        .frame(width: 100, height: 10)
                }
            }

            // Summary lines
            VStack(alignment: .leading, spacing: NexusSpacing.xs) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.Nexus.surface2)
                    .frame(height: 11)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.Nexus.surface2)
                    .frame(height: 11)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.Nexus.surface2)
                    .frame(width: 180, height: 11)
            }

            // Tags row placeholder
            HStack(spacing: NexusSpacing.xs) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule()
                        .fill(Color.Nexus.surface2)
                        .frame(width: 52, height: 22)
                }
            }
        }
        .padding(NexusSpacing.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Nexus.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.base))
        .overlay(
            RoundedRectangle(cornerRadius: NexusRadius.base)
                .stroke(Color.Nexus.border, lineWidth: NexusBorder.hair)
        )
        // Shimmer overlay
        .overlay(
            GeometryReader { geo in
                shimmerOverlay(width: geo.size.width)
            }
            .clipShape(RoundedRectangle(cornerRadius: NexusRadius.base))
        )
        .onAppear {
            withAnimation(
                .linear(duration: 1.2).repeatForever(autoreverses: false)
            ) {
                shimmerPhase = 1
            }
        }
    }

    private func shimmerOverlay(width: CGFloat) -> some View {
        LinearGradient(
            stops: [
                .init(color: Color.clear, location: 0),
                .init(color: Color.Nexus.bloom.opacity(0.35), location: 0.45),
                .init(color: Color.white.opacity(0.4), location: 0.5),
                .init(color: Color.Nexus.bloom.opacity(0.35), location: 0.55),
                .init(color: Color.clear, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: width * 2)
        // Slide from -width to +width across the card
        .offset(x: shimmerPhase * width * 2 - width)
    }
}
