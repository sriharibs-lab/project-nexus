import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.Nexus.pageBackground.ignoresSafeArea()

                if vm.isLoading {
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
        }
        .navigationDestination(for: NexusCollection.self) { collection in
            CollectionView(collection: collection)
        }
    }

    private var emptyState: some View {
        VStack(spacing: NexusSpacing.md) {
            Text("No collections yet")
                .font(.Nexus.headingSmall)
                .foregroundColor(.Nexus.ink)
            Text("Create a collection to start saving and understanding content.")
                .font(.Nexus.bodyMedium)
                .foregroundColor(.Nexus.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, NexusSpacing.xl)
        }
    }
}

private struct CollectionCard: View {
    let collection: NexusCollection

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: NexusSpacing.xs) {
                Text(collection.name)
                    .font(.Nexus.labelLarge)
                    .foregroundColor(.Nexus.ink)
                    .kerning(NexusKerning.normal)
                Text("\(collection.sourceCount) source\(collection.sourceCount == 1 ? "" : "s")")
                    .font(.Nexus.caption)
                    .foregroundColor(.Nexus.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.Nexus.ghost)
        }
        .padding(NexusSpacing.standard)
        .background(Color.Nexus.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: NexusRadius.lg)
                .stroke(Color.Nexus.border, lineWidth: NexusBorder.hair)
        )
    }
}
