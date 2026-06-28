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
        if !authManager.isAuthenticated {
            AuthView()
        } else {
            HomeView()
        }
    }
}
