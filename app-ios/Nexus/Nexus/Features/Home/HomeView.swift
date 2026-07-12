import Combine
import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @ObservedObject private var authManager = AuthManager.shared

    @State private var showingNewCollectionChoice = false
    @State private var showingResearchFlow = false
    @State private var showingLinkSheet = false
    @State private var showingAccount = false
    @State private var navPath = NavigationPath()

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
                    ZStack {
                        NexusBackground()
                        collectionList
                    }
                    .navigationTitle("Nexus")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                showingAccount = true
                            } label: {
                                AvatarCircle(initials: avatarInitials, size: 30)
                            }
                            .frame(width: NexusSpacing.hitTarget, height: NexusSpacing.hitTarget)
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showingNewCollectionChoice = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.Nexus.accent)
                                    .frame(width: NexusSpacing.hitTarget, height: NexusSpacing.hitTarget)
                            }
                        }
                    }
                    .sheet(isPresented: $showingAccount) {
                        AccountView()
                    }
                    .confirmationDialog("New Collection", isPresented: $showingNewCollectionChoice, titleVisibility: .hidden) {
                        Button("Research a topic") { showingResearchFlow = true }
                        Button("Start with a link") { showingLinkSheet = true }
                        Button("Cancel", role: .cancel) {}
                    }
                    .fullScreenCover(isPresented: $showingResearchFlow) {
                        ResearchFlowView { collectionId in
                            Task {
                                await vm.load()
                                if let found = vm.collections.first(where: { $0.id == collectionId }) {
                                    navPath.append(found)
                                }
                            }
                        }
                    }
                    .sheet(isPresented: $showingLinkSheet) {
                        LinkURLSheetView(
                            initialContentType: .website,
                            collections: vm.collections
                        ) { _, collectionId in
                            Task {
                                await vm.load()
                                if let found = vm.collections.first(where: { $0.id == collectionId }) {
                                    navPath.append(found)
                                }
                            }
                        }
                        .presentationDetents([.large])
                        .presentationDragIndicator(.hidden)
                    }
                }
            }
            // Attached to the always-mounted Group, NOT the list branch —
            // a destination inside a conditional branch unmounts with it.
            .navigationDestination(for: NexusCollection.self) { collection in
                CollectionView(collection: collection)
            }
        }
        .task { await vm.load() }
    }

    // MARK: - Avatar initials

    private var avatarInitials: String {
        if !authManager.displayName.isEmpty {
            let parts = authManager.displayName.split(separator: " ").prefix(2)
            return parts.compactMap { $0.first.map { String($0) } }.joined().uppercased()
        }
        if let first = authManager.email.first {
            return String(first).uppercased()
        }
        return "N"
    }

    // MARK: - Collection list

    private var collectionList: some View {
        ScrollView {
            LazyVStack(spacing: NexusSpacing.sm) {
                ForEach(vm.collections) { collection in
                    NavigationLink(value: collection) {
                        CollectionCard(collection: collection)
                    }
                    // Press-scale via ButtonStyle — NavigationLink drives it
                    // natively. The previous onLongPressGesture INSIDE the card
                    // consumed taps, so links never fired (2026-07-11).
                    .buttonStyle(PressableCardStyle())
                }
            }
            .padding(.horizontal, NexusSpacing.sideGutter)
            .padding(.top, NexusSpacing.sm)
            .padding(.bottom, NexusSpacing.xl)
        }
        .refreshable { await vm.load() }
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
        // Press feedback comes from PressableCardStyle on the NavigationLink.
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
