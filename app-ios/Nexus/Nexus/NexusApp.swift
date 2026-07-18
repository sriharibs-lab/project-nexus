//
//  NexusApp.swift
//  Nexus
//
//  Created by Srihari Srinivasa on 6/13/26.
//

import Combine
import SwiftUI

@main
struct NexusApp: App {
    @StateObject private var authManager = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .preferredColorScheme(.light)
        }
    }
}

/// Root routing: auth state drives the view stack.
/// Not authenticated → AuthView (Sign in with Apple + magic link)
/// Authenticated → HomeView (handles empty state by showing FRE inline)
private struct RootView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        #if DEBUG
        if let preview = previewScreen {
            preview
        } else {
            normalRoot
        }
        #else
        normalRoot
        #endif
    }

    @ViewBuilder
    private var normalRoot: some View {
        if !authManager.isAuthenticated {
            AuthView()
        } else {
            HomeView()
        }
    }

    #if DEBUG
    // Simulator preview harness: `simctl launch ... -preview collection`
    // jumps straight to a screen with sample data — lets Claude screenshot
    // states without driving the full auth/nav flow. No effect on device
    // builds unless the argument is passed.
    private var previewScreen: AnyView? {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-preview"), idx + 1 < args.count else { return nil }
        switch args[idx + 1] {
        case "collection":
            let tab = args.firstIndex(of: "-tab").flatMap { i in
                i + 1 < args.count ? args[i + 1] : nil
            } ?? "ask"
            return AnyView(
                NavigationStack {
                    CollectionView(collection: .previewSample, initialTab: tab)
                }
            )
        case "auth":
            return AnyView(AuthView())
        case "glass":
            return AnyView(NavigationStack { GlassPlaygroundView() })
        case "account":
            return AnyView(AccountView().environmentObject(AuthManager.shared))
        case "settings":
            return AnyView(SettingsView().environmentObject(AuthManager.shared))
        case "settingsplayground":
            let v = args.firstIndex(of: "-variant").flatMap { i in
                i + 1 < args.count ? Int(args[i + 1]) : nil
            }.flatMap { SettingsPlaygroundView.Variant(rawValue: $0) } ?? .ios
            return AnyView(SettingsPlaygroundView(variant: v).environmentObject(AuthManager.shared))
        case "feedback":
            return AnyView(NavigationStack { FeedbackView(preloadedScreenshot: nil) }.environmentObject(AuthManager.shared))
        case "home":
            return AnyView(
                HomeView(viewModel: HomeViewModel(previewCollections: NexusCollection.previewList))
                    .environmentObject(AuthManager.shared)
            )
        case "fre":
            return AnyView(
                ResearchFlowView(
                    onComplete: { _ in },
                    showsBackButton: args.contains("-back"),
                    showsAvatar: !args.contains("-back")
                )
                .environmentObject(AuthManager.shared)
            )
        default:
            return nil
        }
    }
    #endif
}

#if DEBUG
extension NexusCollection {
    /// Sample for the -preview harness (not persisted, never hits the API).
    static var previewSample: NexusCollection {
        NexusCollection(
            id: UUID(),
            userId: UUID(),
            name: "AI platform shifts",
            description: "Every model is becoming a platform — your sources map the fight.",
            framingParagraph: nil,
            createdBy: .ai,
            sourceCount: 6,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    /// Home-list sample set for `-preview home`.
    static var previewList: [NexusCollection] {
        [
            ("The attention economy", 12, true),
            ("Second-brain tools", 7, false),
            ("How memory works", 5, true),
            ("AI platform shifts", 9, true),
            ("Ozempic & longevity", 6, true),
        ].map { name, count, ai in
            NexusCollection(
                id: UUID(),
                userId: UUID(),
                name: name,
                description: nil,
                framingParagraph: nil,
                createdBy: ai ? .ai : .user,
                sourceCount: count,
                createdAt: Date().addingTimeInterval(-86_400),
                updatedAt: Date().addingTimeInterval(-3_600)
            )
        }
    }
}
#endif
