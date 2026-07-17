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
                NexusBackground()

                ScrollView {
                    VStack(spacing: 0) {
                        profileSection
                            .padding(.top, NexusSpacing.md)
                            .padding(.bottom, NexusSpacing.xl)

                        SettingsSectionLabel(text: "Account")
                        SettingsCard {
                            SettingsRow(icon: "envelope", label: "Email",
                                        value: authManager.email.isEmpty ? "—" : authManager.email)
                            SettingsRow(icon: "sparkles", label: "Subscription",
                                        value: "Free · Beta", trailing: .chevron,
                                        showsDivider: false, action: {})
                        }

                        // Log out — its own red single-row card, door icon
                        SettingsCard {
                            SettingsRow(icon: "rectangle.portrait.and.arrow.right",
                                        label: "Log out", danger: true,
                                        showsDivider: false) {
                                authManager.signOut()
                                dismiss()
                            }
                        }
                        .padding(.top, NexusSpacing.lg)

                        if let deleteError {
                            Text(deleteError)
                                .font(.Nexus.caption)
                                .foregroundColor(.Nexus.destructive)
                                .multilineTextAlignment(.center)
                                .padding(.top, NexusSpacing.md)
                        }

                        // Delete account — separate text button OUTSIDE the list
                        deleteAccountButton
                            .padding(.top, NexusSpacing.xl)
                    }
                    .padding(.horizontal, NexusSpacing.standard)
                    .padding(.bottom, NexusSpacing.xxxl)
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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

    private var profileSection: some View {
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

    // MARK: - Delete (separate button)

    private var deleteAccountButton: some View {
        Button {
            confirmingDelete = true
        } label: {
            ZStack {
                if deleting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .Nexus.destructive))
                } else {
                    Text("Delete account")
                        .font(.system(size: 15.5, weight: .medium))
                        .kerning(-0.2)
                        .foregroundColor(.Nexus.destructive)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, NexusSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(deleting)
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
