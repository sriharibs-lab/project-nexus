import SwiftUI

/// Launch splash — the brand moment on cold start, masking first-load latency.
/// Logo + name only (Claude-style: nothing else). Shown by RootView for a beat,
/// then cross-fades to the app. The real cold-start fix is keeping the backend
/// warm (UptimeRobot); this covers the app's own launch.
struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            NexusBackground().ignoresSafeArea()

            // Matches the AuthView hero EXACTLY (mark 64 → "Nexus" → tagline,
            // same sizes + centering) so splash → login is a seamless crossfade
            // with no jump (device report 2026-10).
            VStack(spacing: 0) {
                EchoMark(size: 64)
                    .scaleEffect(appeared ? 1 : 0.92)
                Text("Nexus")
                    .font(.system(size: 27, weight: .semibold))
                    .kerning(-0.6)
                    .foregroundColor(.Nexus.ink)
                    .padding(.top, 26)
                Text("Your AI research companion.")
                    .font(.system(size: 27, weight: .semibold))
                    .kerning(-0.6)
                    .foregroundColor(.Nexus.faint)
                    .padding(.top, 10)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) { appeared = true }
        }
    }
}

#if DEBUG
#Preview { SplashView() }
#endif
