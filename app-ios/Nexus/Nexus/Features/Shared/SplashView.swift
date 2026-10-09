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

            VStack(spacing: 22) {
                EchoMark(size: 78)
                    .scaleEffect(appeared ? 1 : 0.92)

                Text("Nexus")
                    .font(.system(size: 34, weight: .bold))
                    .kerning(-0.5)
                    .foregroundColor(.Nexus.ink)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: -12)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) { appeared = true }
        }
    }
}

#if DEBUG
#Preview { SplashView() }
#endif
