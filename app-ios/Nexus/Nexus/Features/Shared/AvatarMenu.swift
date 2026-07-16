import SwiftUI

// MARK: - Shared avatar button + bloom menu
//
// LOCKED design (2026-06-29 review, re-locked in home-flow mock 2026-07-15):
// three flat rows with icons — Account · Settings · Feedback. NO user header,
// NO sign out (sign out lives in AccountView). Used by HomeView and the FRE.

struct NexusAvatarButton: View {
    let active: Bool
    let action: () -> Void

    @EnvironmentObject private var authManager: AuthManager
    // Bounce choreography (locked 2026-06-29, re-shipped 2026-07-16):
    // tap = squish (the avatar "spits out" the menu), menu close = overshoot
    // pop (it "swallows" the menu back).
    @State private var bounceScale: CGFloat = 1.0

    var body: some View {
        Button {
            bounceScale = 0.72
            withAnimation(.spring(response: 0.38, dampingFraction: 0.46)) {
                bounceScale = 1.0
            }
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.Nexus.surface2)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(Color.Nexus.borderStrong, lineWidth: 1.0))
                Text(authManager.avatarInitial)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(.Nexus.muted)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(bounceScale)
        // Button hides while the menu occupies its corner
        .opacity(active ? 0 : 1)
        .animation(.spring(response: 0.26, dampingFraction: 0.72), value: active)
        .onChange(of: active) { _, nowActive in
            guard !nowActive else { return }
            bounceScale = 1.28
            withAnimation(.spring(response: 0.48, dampingFraction: 0.38)) {
                bounceScale = 1.0
            }
        }
    }
}

struct NexusAvatarMenuCard: View {
    let onAccount: () -> Void
    let onSettings: () -> Void
    let onFeedback: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AvatarMenuRow(icon: "person.circle", label: "Account", action: onAccount)
            AvatarMenuRow(icon: "gearshape", label: "Settings", action: onSettings)
            AvatarMenuRow(icon: "message", label: "Feedback", action: onFeedback)
        }
        .padding(.vertical, 5)
        .frame(width: 196)
        // Liquid Glass floating-menu material (DESIGN_LANGUAGE §3: menus are
        // the floating layer, radius 22). Native glassEffect on iOS 26 — no
        // fill underneath (defeats glass); material fallback below 26.
        .background(menuGlass)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.7), Color.white.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.6
                )
        )
        .shadow(color: .black.opacity(0.16), radius: 29, x: 0, y: 11)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var menuGlass: some View {
        if #available(iOS 26.0, *) {
            Color.clear.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.thinMaterial)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.55))
            }
        }
    }
}

private struct AvatarMenuRow: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundColor(Color(UIColor.label))
                    .frame(width: 18, alignment: .center)
                Text(label)
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundColor(Color(UIColor.label))
                Spacer()
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        // ButtonStyle press highlight — never a zero-distance drag gesture
        // (tap-theft class, see ios-gotchas)
        .buttonStyle(MenuRowStyle())
    }
}

private struct MenuRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.black.opacity(0.06) : Color.clear)
    }
}

// MARK: - Bloom menu overlay container
//
// The scrim + top-right bloom animation shared by Home and FRE. Content
// closes over `dismiss` so rows can chain their own action after closing.

struct AvatarBloomOverlay<Menu: View>: View {
    let isPresented: Bool
    let topInset: CGFloat
    let onDismiss: () -> Void
    @ViewBuilder let menu: () -> Menu

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isPresented {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture(perform: onDismiss)
            }

            // Bloom-morph: grows from the avatar's corner at near-zero scale
            // with a visible overshoot (design language: menu bloom, spring
            // linear ≈1.1 peak) — the WhatsApp/Notion pop.
            menu()
                .padding(.trailing, NexusSpacing.standard)
                .padding(.top, topInset)
                .scaleEffect(isPresented ? 1 : 0.12, anchor: .topTrailing)
                .opacity(isPresented ? 1 : 0)
                .animation(
                    isPresented
                        ? .spring(response: 0.5, dampingFraction: 0.62)   // bloom out, overshoot
                        : .spring(response: 0.28, dampingFraction: 0.9),  // quick collapse
                    value: isPresented
                )
                .allowsHitTesting(isPresented)
        }
    }
}
