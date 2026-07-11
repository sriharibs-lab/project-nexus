import Combine
import SwiftUI

// Navigation value for pushing ItemDetailView from the Sources list.
// Wrapped in a dedicated struct so it is Hashable without polluting Item.
struct ItemDetailRoute: Hashable {
    let item: Item
    let collectionId: UUID
}

struct CollectionView: View {
    @StateObject private var vm: CollectionViewModel
    // IA revision 2026-07-10 (prototype review): three tabs — Ask · Create · Sources
    @State private var selectedTab: String = "ask"
    // Link URL sheet — presented by the + toolbar button on the Sources tab
    @State private var linkSheetContentType: DetectedContentType? = nil

    private static let tabs: [GlassTabItem] = [
        GlassTabItem(key: "ask",     label: "Ask",     icon: "echo",             iconSelected: "echo"),
        GlassTabItem(key: "create",  label: "Create",  icon: "square.and.pencil", iconSelected: "square.and.pencil"),
        GlassTabItem(key: "sources", label: "Sources", icon: "rectangle.stack",  iconSelected: "rectangle.stack.fill"),
    ]

    init(collection: NexusCollection, initialTab: String = "ask") {
        _vm = StateObject(wrappedValue: CollectionViewModel(collection: collection))
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            NexusBackground()

            tabContent
                // Capsule zone is unsafe area — composers/lists float above it
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 84)
                }

            // Bottom floating glass capsule (DESIGN_LANGUAGE §3 + §8):
            // 24pt above the home indicator, content scrolls underneath.
            GlassTabBar(tabs: Self.tabs, selection: $selectedTab)
                .padding(.bottom, 24)
        }
        .navigationTitle(vm.collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // "+" button in Sources tab → open link sheet pre-scoped to this collection
            if selectedTab == "sources" {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        linkSheetContentType = .website
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.Nexus.accent)
                            .frame(width: NexusSpacing.hitTarget, height: NexusSpacing.hitTarget)
                    }
                }
            }
        }
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
        // Link sheet pre-scoped to this collection
        .sheet(item: $linkSheetContentType) { contentType in
            LinkURLSheetView(
                initialContentType: contentType,
                collections: [],
                preselectedCollectionId: vm.collection.id,
                onComplete: { _, _ in
                    // Refresh the sources list so the new item appears.
                    Task { await vm.load() }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case "ask":
            NexusTabView(collection: vm.collection, items: vm.items)
                .transition(.opacity)
        case "create":
            CreateTabView(collection: vm.collection, items: vm.items)
                .transition(.opacity)
        default:
            SourcesTabView(
                items: vm.items,
                isLoading: vm.isLoading,
                collectionId: vm.collection.id,
                error: vm.error,
                onDelete: { item in await vm.delete(item: item) },
                onRefresh: { await vm.load() }
            )
            .transition(.opacity)
        }
    }
}
