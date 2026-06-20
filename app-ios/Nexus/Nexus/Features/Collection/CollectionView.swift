import SwiftUI

// Navigation value for pushing ItemDetailView from the Sources list.
// Wrapped in a dedicated struct so it is Hashable without polluting Item.
struct ItemDetailRoute: Hashable {
    let item: Item
    let collectionId: UUID
}

struct CollectionView: View {
    @StateObject private var vm: CollectionViewModel
    @State private var selectedTab: Tab = .nexus

    enum Tab: String, CaseIterable {
        case nexus   = "Nexus"
        case sources = "Sources"
    }

    init(collection: NexusCollection) {
        _vm = StateObject(wrappedValue: CollectionViewModel(collection: collection))
    }

    var body: some View {
        ZStack {
            Color.Nexus.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Liquid Glass floating tab capsule (DESIGN_LANGUAGE §3 + §8)
                // Floats above content — uses backdrop blur material, spring thumb.
                LiquidGlassTabCapsule(selectedTab: $selectedTab)
                    .padding(.horizontal, NexusSpacing.sideGutter)
                    .padding(.top, NexusSpacing.sm)
                    .padding(.bottom, NexusSpacing.xs)

                Rectangle()
                    .fill(Color.Nexus.hair)
                    .frame(height: NexusBorder.hair)

                tabContent
            }
        }
        .navigationTitle(vm.collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        // Non-fatal delete error: show an alert if the API call fails.
        .alert("Couldn't delete source", isPresented: Binding(
            get: { vm.deleteError != nil },
            set: { if !$0 { vm.deleteError = nil } }
        )) {
            Button("OK", role: .cancel) { vm.deleteError = nil }
        } message: {
            Text(vm.deleteError?.errorDescription ?? "Please try again.")
        }
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .nexus:
            NexusTabView(collection: vm.collection)
                .transition(.opacity)
        case .sources:
            SourcesTabView(
                items: vm.items,
                isLoading: vm.isLoading,
                collectionId: vm.collection.id,
                onDelete: { item in await vm.delete(item: item) },
                onRefresh: { await vm.load() }
            )
            .transition(.opacity)
        }
    }
}
