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

/// Root routing: auth state + onboarding state drive the view stack.
///
/// Priority order:
///   1. Not authenticated → AuthPlaceholderView (replaced by Sign in with Apple in 1B-002)
///   2. Authenticated + onboarding not done → OnboardingView
///   3. Authenticated + onboarding done → HomeView
private struct RootView: View {
    @EnvironmentObject var authManager: AuthManager

    /// Tracks whether onboarding is complete within this session.
    /// Initialized from UserDefaults; set to true when OnboardingView calls onComplete.
    @State private var onboardingDone: Bool = OnboardingViewModel.hasCompletedOnboarding

    /// When true, HomeView will immediately show the ResearchFlowView sheet.
    @State private var launchResearchOnHome: Bool = false

    var body: some View {
        if !authManager.isAuthenticated {
            AuthPlaceholderView()
        } else if !onboardingDone {
            OnboardingView { launchResearch in
                launchResearchOnHome = launchResearch
                withAnimation(NexusAnimation.pageForward) {
                    onboardingDone = true
                }
            }
            .transition(.asymmetric(
                insertion: .opacity,
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        } else {
            HomeView(openResearchOnAppear: launchResearchOnHome)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
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
