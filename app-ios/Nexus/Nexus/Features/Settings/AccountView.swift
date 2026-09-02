import SwiftUI

// MARK: - AccountView
//
// IDENTITY & ACCESS only (approved IA tree 2026-07-16): profile header,
// plan row, sign out, delete account. App behavior lives in Settings.
// Sheet chrome: iOS-native X-circle dismiss + swipe down.

struct AccountView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var confirmingDelete = false
    @State private var deleting = false
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                NexusBackground().ignoresSafeArea()

                List {
                    // Profile header — sits on the bloom, no card chrome
                    Section {
                        profileHeader
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 20, trailing: 0))
                    }

                    Section("Account") {
                        SettingsRow(icon: "envelope", label: "Email") {
                            SettingsValue(authManager.email.isEmpty ? "—" : authManager.email)
                        }
                        Button {
                            // Subscription management — no destination yet
                        } label: {
                            SettingsRow(icon: "sparkles", label: "Subscription") {
                                HStack(spacing: 8) {
                                    SettingsValue("Free · Beta")
                                    SettingsChevron()
                                }
                            }
                        }
                        .tint(.primary)
                    }

                    // Log out — its own red row, door icon
                    Section {
                        Button {
                            authManager.signOut()
                            dismiss()
                        } label: {
                            SettingsRow(icon: "rectangle.portrait.and.arrow.right",
                                        label: "Log out", danger: true)
                        }
                        .tint(.primary)
                    }

                    // Delete account — plain red text OUTSIDE a card (clear row)
                    Section {
                        Button {
                            confirmingDelete = true
                        } label: {
                            Group {
                                if deleting {
                                    ProgressView().tint(.Nexus.destructive)
                                } else {
                                    Text("Delete account")
                                        .foregroundStyle(Color.Nexus.destructive)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .disabled(deleting)
                        .listRowBackground(Color.clear)
                    } footer: {
                        if let deleteError {
                            Text(deleteError)
                                .foregroundStyle(Color.Nexus.destructive)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
                .nexusInsetGrouped()
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SheetCloseButton { dismiss() }
                }
            }
            .confirmationDialog(
                "Delete your account?",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete account and all data", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your collections, sources, and account. It cannot be undone.")
            }
        }
    }

    // MARK: - Profile

    private var profileHeader: some View {
        VStack(spacing: NexusSpacing.md) {
            AvatarCircle(initials: initials, size: 84)

            if !authManager.displayName.isEmpty {
                Text(authManager.displayName)
                    .font(.system(size: 19, weight: .semibold))
                    .kerning(-0.4)
                    .foregroundColor(.Nexus.ink)
            } else if !authManager.email.isEmpty {
                Text(authManager.email)
                    .font(.system(size: 17, weight: .semibold))
                    .kerning(-0.3)
                    .foregroundColor(.Nexus.ink)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func deleteAccount() async {
        deleting = true
        defer { deleting = false }
        do {
            try await APIClient.shared.deleteAccount()
            authManager.signOut()
            dismiss()
        } catch {
            deleteError = "Couldn't delete your account. Please try again."
        }
    }

    // MARK: - Helpers

    private var initials: String {
        if !authManager.displayName.isEmpty {
            let parts = authManager.displayName.split(separator: " ").prefix(2)
            return parts.compactMap { $0.first.map { String($0) } }.joined().uppercased()
        }
        if let first = authManager.email.first {
            return String(first).uppercased()
        }
        return "?"
    }
}

// MARK: - Sheet close button (shared chrome)
//
// Bare xmark ONLY — iOS 26 toolbars wrap buttons in their own glass circle;
// drawing our own circle produced a circle-in-circle (device review
// 2026-07-16). Standard position: TRAILING on every sheet.

struct SheetCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.Nexus.muted)
        }
        .accessibilityLabel("Close")
    }
}

// MARK: - AvatarCircle
//
// Reusable avatar component. Solid fill with plum bloom background and ink
// initials — matches the inline surface model from DESIGN_LANGUAGE.md.

struct AvatarCircle: View {
    let initials: String
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.Nexus.bloom)
                .overlay(
                    Circle()
                        .stroke(Color.Nexus.border, lineWidth: NexusBorder.hair)
                )

            Text(initials)
                .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                .foregroundColor(.Nexus.accent)
                .kerning(NexusKerning.snug)
        }
        .frame(width: size, height: size)
    }
}
