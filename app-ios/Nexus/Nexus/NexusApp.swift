//
//  NexusApp.swift
//  Nexus
//
//  Created by Srihari Srinivasa on 6/13/26.
//

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
/// Sign-in screens slot in here in 1B-002; for now a placeholder
/// that goes straight to Home (dev build only).
private struct RootView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        if authManager.isAuthenticated {
            HomeView()
        } else {
            AuthPlaceholderView()
        }
    }
}

/// Temporary auth placeholder — replaced by Sign in with Apple + magic link in 1B-002.
private struct AuthPlaceholderView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        ZStack {
            Color.Nexus.pageBackground.ignoresSafeArea()
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
