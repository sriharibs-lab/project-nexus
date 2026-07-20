import Combine
import SwiftUI
import UIKit

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
    // Tab bar hides while the keyboard is up (composer/search). Riding up with
    // the keyboard looked broken (#7); hiding beats a half-covered capsule.
    @State private var keyboardUp = false

    private static let tabs: [GlassTabItem] = [
        // Composite glyphs (review 2026-07-14): Ask = sparkle-on-chat-bubble,
        // Create = sparkle-on-image (Canva/Figma convention)
        GlassTabItem(key: "ask",     label: "Ask",     icon: "sparkleBubble", iconSelected: "sparkleBubble"),
        GlassTabItem(key: "create",  label: "Create",  icon: "sparklePhoto",  iconSelected: "sparklePhoto"),
        GlassTabItem(key: "sources", label: "Sources", icon: "rectangle.stack", iconSelected: "rectangle.stack.fill"),
    ]

    init(collection: NexusCollection, initialTab: String = "ask") {
        _vm = StateObject(wrappedValue: CollectionViewModel(collection: collection))
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            NexusBackground()

            tabContent

            // Bottom floating glass capsule (DESIGN_LANGUAGE §3 + §8):
            // 24pt above the home indicator, content scrolls underneath.
            // Never keyboard-avoids — the keyboard covers it (WhatsApp/Clock
            // behavior); riding up with the keyboard looked broken (2026-07-15).
            GlassTabBar(tabs: Self.tabs, selection: $selectedTab)
                .padding(.bottom, 24)
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .opacity(keyboardUp ? 0 : 1)
                .allowsHitTesting(!keyboardUp)
                .animation(.easeInOut(duration: 0.22), value: keyboardUp)
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
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardUp = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardUp = false
        }
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
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case "ask":
            // Composer must clear the capsule — inset the whole tab
            NexusTabView(collection: vm.collection, items: vm.items)
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 84) }
                .transition(.opacity)
        case "create":
            // Content scrolls UNDER the glass capsule (margins, not insets —
            // glass is invisible unless content passes beneath it)
            CreateTabView(collection: vm.collection, items: vm.items)
                .contentMargins(.bottom, 110, for: .scrollContent)
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
            .contentMargins(.bottom, 110, for: .scrollContent)
            .transition(.opacity)
        }
    }
}
