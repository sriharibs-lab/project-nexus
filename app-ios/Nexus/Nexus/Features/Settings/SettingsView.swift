import SwiftUI

struct SettingsView: View {
    @ObservedObject private var authManager = AuthManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.Nexus.pageBackground.ignoresSafeArea()

                List {
                    Section {
                        NavigationLink("Send Feedback") {
                            FeedbackView()
                        }
                    }

                    Section {
                        Button("Sign Out", role: .destructive) {
                            authManager.signOut()
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// Shell — wired up fully in 1B-006
struct FeedbackView: View {
    var body: some View {
        ZStack {
            Color.Nexus.pageBackground.ignoresSafeArea()
            Text("Feedback coming soon")
                .font(.Nexus.bodyMedium)
                .foregroundColor(.Nexus.muted)
        }
        .navigationTitle("Send Feedback")
        .navigationBarTitleDisplayMode(.inline)
    }
}
