import SwiftUI

// MARK: - AccountView
//
// Presented as a sheet from the avatar button in HomeView.
// Shows: avatar circle with user initials, display name (if available),
// email (if available), and a Sign Out button.
//
// Design: inline surface (solid card + hairline) — not Liquid Glass.
// Liquid Glass is for floating menus; a sheet is a full-screen surface.

struct AccountView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                NexusBackground()

                VStack(spacing: 0) {
                    profileSection
                        .padding(.top, NexusSpacing.xxxl)

                    Spacer()

                    signOutSection
                        .padding(.bottom, NexusSpacing.safeBottom + NexusSpacing.lg)
                }
                .padding(.horizontal, NexusSpacing.standard)
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.Nexus.labelLarge)
                        .foregroundColor(.Nexus.accent)
                }
            }
        }
    }

    // MARK: - Profile section

    private var profileSection: some View {
        VStack(spacing: NexusSpacing.lg) {
            // Avatar circle
            AvatarCircle(initials: initials, size: 72)

            // Name + email
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

    // MARK: - Sign Out section

    private var signOutSection: some View {
        Button(role: .destructive) {
            authManager.signOut()
            dismiss()
        } label: {
            Text("Sign Out")
                .font(.Nexus.labelLarge)
                .foregroundColor(.Nexus.destructive)
                .frame(maxWidth: .infinity)
                .frame(height: NexusSpacing.buttonHeight)
                .background(Color.Nexus.destructive.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: NexusRadius.md, style: .continuous)
                        .stroke(Color.Nexus.destructive.opacity(0.18), lineWidth: NexusBorder.hair)
                )
        }
    }

    // MARK: - Helpers

    /// Up to two initials derived from displayName, falling back to email prefix,
    /// then "?" if neither is available.
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
