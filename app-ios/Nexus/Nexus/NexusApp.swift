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
/// Not authenticated → AuthPlaceholderView (Sign in with Apple in 1B-002)
/// Authenticated → HomeView (HomeView handles empty state by showing FRE inline)
private struct RootView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        if !authManager.isAuthenticated {
            AuthPlaceholderView()
        } else {
            HomeView()
        }
    }
}

/// Temporary auth placeholder — replaced by Sign in with Apple + magic link in 1B-002.
private struct AuthPlaceholderView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        ZStack {
            NexusBackground()
            VStack(spacing: NexusSpacing.xl) {
                Text("Nexus")
                    .font(.Nexus.displayMedium)
                    .foregroundColor(.Nexus.ink)
                    .kerning(NexusKerning.tighter)

                Button("Continue (dev)") {
                    // Bypasses auth for local dev; 1B-002 replaces this
                    authManager.setSession(token: "dev", userId: UUID())
                }
                .font(.Nexus.labelLarge)
                .foregroundColor(.Nexus.white)
                .padding(.vertical, NexusSpacing.md)
                .padding(.horizontal, NexusSpacing.xl)
                .background(Color.Nexus.accent)
                .clipShape(Capsule())
            }
        }
    }
}
