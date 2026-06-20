import SwiftUI

// Navigation value for pushing ItemDetailView from the Sources list.
// Wrapped in a dedicated struct so it is Hashable without polluting Item.
struct ItemDetailRoute: Hashable {
    let item: Item
    let collectionId: UUID
}

// MARK: - NexusTabView stub
// The full NexusTabView (SSE chat, Echo-pulse, citation chips) lives in
// NexusTabView.swift (task 1C-007). This stub is present so CollectionView
// compiles in isolation; it will be superseded when 1C-007 merges.

private struct NexusTabView: View {
    let collection: NexusCollection

    var body: some View {
        VStack(spacing: NexusSpacing.lg) {
            Spacer()
            if let framing = collection.framingParagraph {
                Text(framing)
                    .font(.Nexus.bodyLarge)
                    .foregroundColor(.Nexus.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, NexusSpacing.xl)
            } else {
                Text("Ask anything about your sources in \"\(collection.name)\".")
                    .font(.Nexus.bodyLarge)
                    .foregroundColor(.Nexus.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, NexusSpacing.xl)
            }
            Spacer()
        }
    }
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
                tabPicker
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

    // MARK: - Tab picker (pill capsule style per DESIGN_LANGUAGE §8)

    private var tabPicker: some View {
        HStack(spacing: NexusSpacing.xs) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(NexusAnimation.pivot) { selectedTab = tab }
                } label: {
                    Text(tab.rawValue)
                        .font(.Nexus.labelMedium)
                        .kerning(NexusKerning.normal)
                        .foregroundColor(selectedTab == tab ? .Nexus.ink : .Nexus.muted)
                        .padding(.vertical, NexusSpacing.xs + 2)
                        .padding(.horizontal, NexusSpacing.md)
                        .background(
                            selectedTab == tab
                                ? Color.Nexus.surface2
                                : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
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
