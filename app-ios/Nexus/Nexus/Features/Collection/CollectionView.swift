import SwiftUI

struct CollectionView: View {
    @StateObject private var vm: CollectionViewModel
    @State private var selectedTab: Tab = .nexus

    enum Tab: String, CaseIterable {
        case nexus  = "Nexus"
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
                    .padding(.vertical, NexusSpacing.sm)

                Divider()
                    .overlay(Color.Nexus.hair)

                tabContent
            }
        }
        .navigationTitle(vm.collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
    }

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(NexusAnimation.pivot) { selectedTab = tab }
                } label: {
                    Text(tab.rawValue)
                        .font(.Nexus.labelMedium)
                        .foregroundColor(selectedTab == tab ? .Nexus.ink : .Nexus.muted)
                        .padding(.vertical, NexusSpacing.xs)
                        .padding(.horizontal, NexusSpacing.md)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .nexus:
            NexusTabView(collection: vm.collection)
                .transition(.opacity)
        case .sources:
            SourcesTabView(items: vm.items, isLoading: vm.isLoading)
                .transition(.opacity)
        }
    }
}

// MARK: - Nexus tab (AI chat shell)

struct NexusTabView: View {
    let collection: NexusCollection

    var body: some View {
        VStack {
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

// MARK: - Sources tab (item list shell)

struct SourcesTabView: View {
    let items: [Item]
    let isLoading: Bool

    var body: some View {
        if isLoading {
            Spacer()
            ProgressView()
            Spacer()
        } else if items.isEmpty {
            VStack(spacing: NexusSpacing.md) {
                Spacer()
                Text("No sources yet")
                    .font(.Nexus.labelLarge)
                    .foregroundColor(.Nexus.muted)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: NexusSpacing.xs) {
                    ForEach(items) { item in
                        SourceRow(item: item)
                    }
                }
                .padding(.horizontal, NexusSpacing.sideGutter)
                .padding(.vertical, NexusSpacing.sm)
            }
        }
    }
}

private struct SourceRow: View {
    let item: Item

    var body: some View {
        HStack(spacing: NexusSpacing.md) {
            Image(systemName: item.contentType.icon)
                .font(.system(size: 15))
                .foregroundColor(.Nexus.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: NexusSpacing.xs) {
                Text(item.title ?? item.url)
                    .font(.Nexus.labelMedium)
                    .foregroundColor(.Nexus.ink)
                    .lineLimit(2)
                if let summary = item.summary {
                    Text(summary)
                        .font(.Nexus.caption)
                        .foregroundColor(.Nexus.muted)
                        .lineLimit(2)
                } else if item.ingestStatus == .processing {
                    Text("Processing…")
                        .font(.Nexus.caption)
                        .foregroundColor(.Nexus.ghost)
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
    }
}
