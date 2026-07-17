import Combine
import SwiftUI

// MARK: - Home
//
// LOCKED design (prototype /flows/home, 2026-07-15):
//  • Header: "Nexus" title left + avatar right (bloom menu: Account ·
//    Settings · Feedback). No nav-bar toolbar, no Recent/All pivot.
//  • Cards: native swipe-left reveals an icon-only trash delete (Weather).
//  • Bottom stack floats over the list: primary "+ New collection" ink pill
//    (right-aligned) above a full-width liquid-glass search bar that filters
//    the list live (Claude-style: magnifier, "Search" ghost, ×-circle cancel).
//  • Empty state: the FRE (ResearchFlowView) with its single link CTA.

struct HomeView: View {
    @StateObject private var vm: HomeViewModel
    @ObservedObject private var authManager = AuthManager.shared

    @State private var showingAccount = false
    @State private var showingSettings = false
    @State private var showingFeedback = false
    @State private var navPath = NavigationPath()
    @FocusState private var searchFocused: Bool

    /// Route token for the pushed New-collection screen.
    private struct NewCollectionRoute: Hashable {}

    @MainActor
    init(viewModel: HomeViewModel? = nil) {
        _vm = StateObject(wrappedValue: viewModel ?? HomeViewModel())
    }

    var body: some View {
        // The NavigationStack ALWAYS exists — appending to navPath while the
        // stack was unmounted (FRE branch) desynced the path binding, leaving
        // every subsequent NavigationLink tap dead (2026-07-11).
        NavigationStack(path: $navPath) {
            Group {
                if vm.isLoading && vm.collections.isEmpty {
                    ZStack {
                        NexusBackground()
                        LoadingStateView()
                    }
                    .toolbar(.hidden, for: .navigationBar)
                } else if vm.collections.isEmpty {
                    // No collections — FRE is the primary screen, not a modal
                    ResearchFlowView { collectionId in
                        Task {
                            await vm.load()
                            if let found = vm.collections.first(where: { $0.id == collectionId }) {
                                navPath.append(found)
                            }
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                } else {
                    collectionsScreen
                        .toolbar(.hidden, for: .navigationBar)
                }
            }
            // Attached to the always-mounted Group, NOT the list branch —
            // a destination inside a conditional branch unmounts with it.
            .navigationDestination(for: NexusCollection.self) { collection in
                CollectionView(collection: collection)
            }
            // New collection PUSHES from the side (device review 2026-07-16).
            // Native nav bar back button (glass + swipe-back) — NOT a custom
            // circular chevron. No avatar (avatar = landing pages only).
            .navigationDestination(for: NewCollectionRoute.self) { _ in
                ResearchFlowView(
                    onComplete: { collectionId in
                        Task {
                            await vm.load()
                            if let found = vm.collections.first(where: { $0.id == collectionId }) {
                                navPath.append(found)
                            }
                        }
                    },
                    showsBackButton: false,
                    showsAvatar: false
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
            }
        }
        .task { await vm.load() }
    }

    // MARK: - Collections screen

    private var collectionsScreen: some View {
        ZStack {
            NexusBackground()

            VStack(spacing: 0) {
                header
                collectionList
            }
        }
        .sheet(isPresented: $showingAccount) { AccountView() }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(isPresented: $showingFeedback) { NavigationStack { FeedbackView(preloadedScreenshot: nil) } }
        .alert("Couldn't delete collection", isPresented: Binding(
            get: { vm.deleteError != nil },
            set: { if !$0 { vm.deleteError = nil } }
        )) {
            Button("OK", role: .cancel) { vm.deleteError = nil }
        } message: {
            Text(vm.deleteError?.errorDescription ?? "Please try again.")
        }
    }

    // Header: title left, avatar right (locked mock; native menu = Weather style)
    private var header: some View {
        HStack {
            Text("Nexus")
                .font(.system(size: 22, weight: .bold))
                .kerning(-0.5)
                .foregroundColor(.Nexus.ink)
            Spacer()
            NexusAvatarMenu(
                onAccount: { showingAccount = true },
                onSettings: { showingSettings = true },
                onFeedback: { showingFeedback = true }
            )
        }
        .padding(.horizontal, NexusSpacing.sideGutter)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Collection list (native List for Weather-style swipe delete)

    private var collectionList: some View {
        List {
            ForEach(vm.visibleCollections) { collection in
                // Hidden-link pattern: suppresses the List's own disclosure
                // chevron (the card showed doubled chevrons otherwise)
                ZStack {
                    NavigationLink(value: collection) { EmptyView() }
                        .opacity(0)
                    CollectionCard(collection: collection)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(
                    top: 5, leading: NexusSpacing.sideGutter,
                    bottom: 5, trailing: NexusSpacing.sideGutter
                ))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await vm.delete(collection) }
                    } label: {
                        // Icon only — Weather-app pattern (locked 2026-07-15)
                        Image(systemName: "trash")
                    }
                }
            }

            if vm.visibleCollections.isEmpty {
                Text("No collections match \u{201C}\(vm.query)\u{201D}")
                    .font(.Nexus.bodySmall)
                    .foregroundColor(.Nexus.faint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await vm.load() }
        .scrollDismissesKeyboard(.interactively)
        // Bottom stack: "+ New collection" above the glass search bar.
        // safeAreaInset keeps it above the keyboard when search is focused.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomStack
        }
    }

    // MARK: - Bottom stack (primary CTA + glass search)

    private var bottomStack: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Button {
                    navPath.append(NewCollectionRoute())
                } label: {
                    // Claude "+ New chat" proportions (device review 2026-07-16)
                    HStack(spacing: 7) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                        Text("New collection")
                            .font(.system(size: 15.5, weight: .semibold))
                            .kerning(-0.2)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 15)
                    .background(Color.Nexus.ink)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.22), radius: 12, y: 4)
                }
                .buttonStyle(PressableCardStyle())
            }

            HStack(spacing: 10) {
                searchField

                if searchFocused {
                    Button {
                        vm.query = ""
                        searchFocused = false
                    } label: {
                        ZStack {
                            Circle().fill(.ultraThinMaterial)
                            Circle().stroke(Color.white.opacity(0.65), lineWidth: NexusBorder.hair)
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.Nexus.ink)
                        }
                        .frame(width: 44, height: 44)
                    }
                    .buttonStyle(PressableCardStyle())
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: searchFocused)
        }
        .padding(.horizontal, NexusSpacing.sideGutter)
        .padding(.top, NexusSpacing.xs)
        .padding(.bottom, NexusSpacing.sm)
    }

    // Claude-style glass search: magnifier + "Search" ghost + live filter
    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.Nexus.faint)
            TextField("Search", text: $vm.query)
                .font(.system(size: 15.5))
                .kerning(-0.2)
                .foregroundColor(.Nexus.ink)
                .focused($searchFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !vm.query.isEmpty {
                Button {
                    vm.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.Nexus.ghost)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(searchGlass)
        .overlay(
            Capsule().stroke(
                searchFocused ? Color.white.opacity(0.95) : Color.white.opacity(0.65),
                lineWidth: NexusBorder.hair
            )
        )
        .shadow(color: .black.opacity(searchFocused ? 0.16 : 0.12), radius: 16, y: 5)
    }

    // Liquid Glass (floating layer) — native on iOS 26, material fallback.
    // No explicit fill under glassEffect (defeats it, ios-gotchas).
    @ViewBuilder
    private var searchGlass: some View {
        if #available(iOS 26.0, *) {
            Color.clear.glassEffect(.regular, in: Capsule())
        } else {
            Capsule().fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Pressable card style

/// Press-scale feedback driven by the Button/NavigationLink itself — never
/// attach tap/press gestures to card content (they steal the link's tap).
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? NexusScale.pressLight : 1)
            .animation(NexusAnimation.press, value: configuration.isPressed)
    }
}

// MARK: - Collection card

/// Home screen card for one collection.
/// Shows: name, source count, creation mode badge (AI / user), relative timestamp.

private struct CollectionCard: View {
    let collection: NexusCollection

    // Locked mock card (2026-07-15): title (17/650) over one quiet meta line
    // "{n} sources · {when}". No chevron, no badge, no description.
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(collection.name)
                .font(.system(size: 17, weight: .semibold))
                .kerning(-0.4)
                .foregroundColor(.Nexus.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(sourceCountLabel) · \(relativeDate)")
                .font(.system(size: 13))
                .kerning(-0.1)
                .foregroundColor(.Nexus.faint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 15, leading: 16, bottom: 15, trailing: 16))
        .background(Color.Nexus.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.Nexus.border, lineWidth: NexusBorder.hair)
        )
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
