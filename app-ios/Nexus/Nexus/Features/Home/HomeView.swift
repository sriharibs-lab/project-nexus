import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.Nexus.pageBackground.ignoresSafeArea()

                if vm.isLoading && vm.collections.isEmpty {
                    ProgressView()
                } else if vm.collections.isEmpty {
                    emptyState
                } else {
                    collectionList
                }
            }
            .navigationTitle("Nexus")
            .navigationBarTitleDisplayMode(.large)
            .task { await vm.load() }
        }
    }

    // MARK: - Collection list

    private var collectionList: some View {
        ScrollView {
            LazyVStack(spacing: NexusSpacing.sm) {
                ForEach(vm.collections) { collection in
                    NavigationLink(value: collection) {
                        CollectionCard(collection: collection)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, NexusSpacing.sideGutter)
            .padding(.top, NexusSpacing.sm)
            .padding(.bottom, NexusSpacing.xl)
        }
        .refreshable { await vm.load() }
        .navigationDestination(for: NexusCollection.self) { collection in
            CollectionView(collection: collection)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: NexusSpacing.lg) {
            VStack(spacing: NexusSpacing.sm) {
                Text("What are you curious about?")
                    .font(.Nexus.headingSmall)
                    .foregroundColor(.Nexus.ink)
                    .kerning(NexusKerning.tighter)
                    .multilineTextAlignment(.center)
                Text("Create your first collection to start saving and understanding content.")
                    .font(.Nexus.bodySmall)
                    .foregroundColor(.Nexus.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, NexusSpacing.xl)
            }
        }
    }
}

// MARK: - Collection card

/// Home screen card for one collection.
/// Shows: name, source count, creation mode badge (AI / user), relative timestamp.

private struct CollectionCard: View {
    let collection: NexusCollection

    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.sm) {
            // Top row: name + AI badge + chevron
            HStack(alignment: .top, spacing: NexusSpacing.sm) {
                Text(collection.name)
                    .font(.Nexus.labelLarge)
                    .foregroundColor(.Nexus.ink)
                    .kerning(NexusKerning.normal)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if collection.createdBy == .ai {
                    AIBadge()
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.Nexus.ghost)
            }

            // Optional description
            if let desc = collection.description, !desc.isEmpty {
                Text(desc)
                    .font(.Nexus.bodySmall)
                    .foregroundColor(.Nexus.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Footer: source count + relative time
            HStack(spacing: NexusSpacing.md) {
                Label(sourceCountLabel, systemImage: "doc.text")
                    .font(.Nexus.caption)
                    .foregroundColor(.Nexus.ghost)
                    .labelStyle(.titleAndIcon)

                Spacer()

                Text(relativeDate)
                    .font(.Nexus.caption)
                    .foregroundColor(.Nexus.ghost)
            }
        }
        .padding(NexusSpacing.standard)
        .background(Color.Nexus.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: NexusRadius.lg)
                .stroke(Color.Nexus.border, lineWidth: NexusBorder.hair)
        )
        .scaleEffect(isPressed ? NexusScale.pressLight : 1)
        .animation(NexusAnimation.press, value: isPressed)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }

    // MARK: Helpers

    private var sourceCountLabel: String {
        let n = collection.sourceCount
        return n == 1 ? "1 source" : "\(n) sources"
    }

    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: collection.updatedAt, relativeTo: Date())
    }
}

// MARK: - AI badge

/// Small pill indicating this collection was AI-seeded ("Research a topic" flow).
private struct AIBadge: View {
    var body: some View {
        Text("AI")
            .font(.Nexus.overline)
            .foregroundColor(.Nexus.accent)
            .kerning(NexusKerning.wide)
            .padding(.horizontal, NexusSpacing.sm)
            .padding(.vertical, 2)
            .background(Color.Nexus.bloom.opacity(0.5))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.Nexus.accent.opacity(0.2), lineWidth: NexusBorder.hair)
            )
    }
}
