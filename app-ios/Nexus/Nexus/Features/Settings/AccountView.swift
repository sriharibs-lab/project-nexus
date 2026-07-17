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

                VStack(spacing: 0) {
                    profileSection
                        .padding(.top, NexusSpacing.xxxl)

                    planRow
                        .padding(.top, NexusSpacing.xxl)

                    Spacer()

                    if let deleteError {
                        Text(deleteError)
                            .font(.Nexus.caption)
                            .foregroundColor(.Nexus.destructive)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, NexusSpacing.sm)
                    }

                    signOutButton
                    deleteAccountButton
                        .padding(.top, NexusSpacing.sm)
                        .padding(.bottom, NexusSpacing.safeBottom + NexusSpacing.lg)
                }
                .padding(.horizontal, NexusSpacing.standard)
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
        VStack(spacing: NexusSpacing.lg) {
            AvatarCircle(initials: initials, size: 72)

            VStack(spacing: NexusSpacing.xs) {
                if !authManager.displayName.isEmpty {
                    Text(authManager.displayName)
                        .font(.Nexus.headingSmall)
                        .foregroundColor(.Nexus.ink)
                        .kerning(NexusKerning.tighter)
                }

                if !authManager.email.isEmpty {
                    Text(authManager.email)
                        .font(.Nexus.bodySmall)
                        .foregroundColor(.Nexus.muted)
                } else {
                    Text("Apple ID")
                        .font(.Nexus.bodySmall)
                        .foregroundColor(.Nexus.ghost)
                }
            }
        }
    }

    // MARK: - Plan (inert placeholder — subscription slot post-beta)

    private var planRow: some View {
        HStack(spacing: NexusSpacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.Nexus.accent)
            Text("Plan")
                .font(.Nexus.labelLarge)
                .foregroundColor(.Nexus.ink)
            Spacer()
            Text("Free · Beta")
                .font(.Nexus.bodySmall)
                .foregroundColor(.Nexus.muted)
        }
        .padding(.horizontal, NexusSpacing.standard)
        .frame(height: NexusSpacing.buttonHeight)
        .background(Color.Nexus.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NexusRadius.md, style: .continuous)
                .stroke(Color.Nexus.border, lineWidth: NexusBorder.hair)
        )
    }

    // MARK: - Sign out / delete

    private var signOutButton: some View {
        Button {
            authManager.signOut()
            dismiss()
        } label: {
            Text("Sign Out")
                .font(.Nexus.labelLarge)
                .foregroundColor(.Nexus.ink)
                .frame(maxWidth: .infinity)
                .frame(height: NexusSpacing.buttonHeight)
                .background(Color.Nexus.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: NexusRadius.md, style: .continuous)
                        .stroke(Color.Nexus.border, lineWidth: NexusBorder.hair)
                )
        }
        .buttonStyle(PressableCardStyle())
    }

    private var deleteAccountButton: some View {
        Button(role: .destructive) {
            confirmingDelete = true
        } label: {
            ZStack {
                if deleting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .Nexus.destructive))
                } else {
                    Text("Delete Account")
                        .font(.Nexus.labelLarge)
                        .foregroundColor(.Nexus.destructive)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: NexusSpacing.buttonHeight)
            .background(Color.Nexus.destructive.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NexusRadius.md, style: .continuous)
                    .stroke(Color.Nexus.destructive.opacity(0.18), lineWidth: NexusBorder.hair)
            )
        }
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
