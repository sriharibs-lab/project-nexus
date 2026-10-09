// Generated from design-system/tokens/colors.json — do not edit manually.
import SwiftUI

extension Color {
    enum Nexus {
        // Brand
        static let accent  = Color(hex: "#7054AB")  // plum — approved uses only
        static let bloom   = Color(hex: "#E7DCF4")  // plum bloom

        // Neutral scale
        static let white         = Color(hex: "#FFFFFF")
        static let surface3      = Color(hex: "#FBFAFD")
        static let pageEnd       = Color(hex: "#F7F3EC")  // Cream (warm base, chosen 2026)
        static let surface2      = Color(hex: "#F4F2F9")
        static let hair          = Color(hex: "#EEEBF5")
        static let border        = Color(hex: "#E9E5F2")
        static let borderStrong  = Color(hex: "#DCD7EA")
        static let ghost         = Color(hex: "#B7B1C4")
        static let faint         = Color(hex: "#9A93AC")
        static let muted         = Color(hex: "#68607A")
        static let ink           = Color(hex: "#130E1A")
        static let inkDeep       = Color(hex: "#0A0710")

        // Semantic
        static let pageBackground  = Color(hex: "#F7F3EC")  // Cream (warm base, chosen 2026)
        static let cardBackground  = Color(hex: "#FFFFFF")
        static let textPrimary     = Color(hex: "#130E1A")
        static let textSecondary   = Color(hex: "#68607A")
        static let textTertiary    = Color(hex: "#9A93AC")

        // Status
        static let destructive     = Color(hex: "#C0392B")  // red — destructive actions only
        static let success         = Color(hex: "#3E8E5A")  // green — correct answers, positive states
    }
}

// MARK: - Global background

/// The canonical Nexus screen background: pageEnd base + plum bloom radial gradient from top.
/// Use instead of Color.Nexus.pageBackground.ignoresSafeArea() on every screen.
struct NexusBackground: View {
    var body: some View {
        ZStack {
            Color.Nexus.pageEnd.ignoresSafeArea()
            LinearGradient(
                // Softened on the warm Cream base so the cool plum bloom reads
                // as a faint haze, not a muddy wash (base chosen 2026).
                colors: [Color.Nexus.bloom.opacity(0.32), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.48)
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Echo mark (canonical)

/// The Nexus brand mark — "Echo Ember" (brand kit 2026, BRAND.md).
/// Two inner arcs + a fainter outer arc pair around a pearl node; the arcs warm
/// from plum → magenta → coral. Geometry matches brand/svg/mark-light.svg
/// (48-unit grid). `color == nil` → full Ember gradient (hero sizes); set a
/// `color` for a flat one-colour mark (small / nav / monochrome contexts).
struct EchoMark: View {
    var color: Color? = nil
    var size: CGFloat = 48

    var body: some View {
        Canvas { ctx, sz in
            let s = sz.width / 48.0

            // Paths (identical geometry to the SVG arc endpoints).
            var innerL = Path()
            innerL.addArc(center: CGPoint(x: 26.05 * s, y: 24 * s), radius: 11 * s,
                          startAngle: .degrees(226.6), endAngle: .degrees(133.4), clockwise: true)
            var innerR = Path()
            innerR.addArc(center: CGPoint(x: 21.95 * s, y: 24 * s), radius: 11 * s,
                          startAngle: .degrees(313.4), endAngle: .degrees(46.6), clockwise: false)
            var outerL = Path()
            outerL.addArc(center: CGPoint(x: 23.298 * s, y: 24 * s), radius: 17.5 * s,
                          startAngle: .degrees(236), endAngle: .degrees(124), clockwise: true)
            var outerR = Path()
            outerR.addArc(center: CGPoint(x: 24.702 * s, y: 24 * s), radius: 17.5 * s,
                          startAngle: .degrees(304), endAngle: .degrees(56), clockwise: false)

            let dotR = 4.4 * s
            let node = Path(ellipseIn: CGRect(x: 24 * s - dotR, y: 24 * s - dotR, width: dotR * 2, height: dotR * 2))

            let innerStyle = StrokeStyle(lineWidth: 3.2 * s, lineCap: .round)
            let outerStyle = StrokeStyle(lineWidth: 2.4 * s, lineCap: .round)

            // Ember shadow only at ≥32px (BRAND.md); never on small marks.
            if color == nil, size >= 32 {
                ctx.addFilter(.shadow(color: Color(hex: "#5E3F9E").opacity(0.30), radius: 1.3 * s, x: 0, y: 1.2 * s))
            }

            if let flat = color {
                // One-colour mark (small / nav).
                ctx.stroke(innerL, with: .color(flat), style: innerStyle)
                ctx.stroke(innerR, with: .color(flat), style: innerStyle)
                ctx.stroke(outerL, with: .color(flat.opacity(0.6)), style: outerStyle)
                ctx.stroke(outerR, with: .color(flat.opacity(0.6)), style: outerStyle)
                ctx.fill(node, with: .color(flat))
                return
            }

            // Ember gradients (light). Inner: plum → magenta → coral.
            let ember = GraphicsContext.Shading.linearGradient(
                Gradient(stops: [
                    .init(color: Color(hex: "#7054AB"), location: 0),
                    .init(color: Color(hex: "#B8569C"), location: 0.55),
                    .init(color: Color(hex: "#E8776A"), location: 1),
                ]),
                startPoint: CGPoint(x: 12 * s, y: 10 * s), endPoint: CGPoint(x: 36 * s, y: 38 * s))
            ctx.stroke(innerL, with: ember, style: innerStyle)
            ctx.stroke(innerR, with: ember, style: innerStyle)

            // Outer: orchid → peach at 60%.
            let outer = GraphicsContext.Shading.linearGradient(
                Gradient(stops: [
                    .init(color: Color(hex: "#9A5BB5").opacity(0.6), location: 0),
                    .init(color: Color(hex: "#F09A78").opacity(0.6), location: 1),
                ]),
                startPoint: CGPoint(x: 10 * s, y: 8 * s), endPoint: CGPoint(x: 38 * s, y: 40 * s))
            ctx.stroke(outerL, with: outer, style: outerStyle)
            ctx.stroke(outerR, with: outer, style: outerStyle)

            // Pearl node — radial + a soft white highlight.
            let pearl = GraphicsContext.Shading.radialGradient(
                Gradient(stops: [
                    .init(color: Color(hex: "#CDB8FF"), location: 0),
                    .init(color: Color(hex: "#7E5CC4"), location: 0.45),
                    .init(color: Color(hex: "#4B2F86"), location: 1),
                ]),
                center: CGPoint(x: 22.68 * s, y: 22.24 * s), startRadius: 0, endRadius: 6.6 * s)
            ctx.fill(node, with: pearl)
            let hl = Path(ellipseIn: CGRect(x: (22.7 - 1.4) * s, y: (22.5 - 0.9) * s, width: 2.8 * s, height: 1.8 * s))
            ctx.fill(hl, with: .color(.white.opacity(0.75)))
        }
        .frame(width: size, height: size)
    }
}

extension Color {
    init(hex: String) {
        let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8)  & 0xFF) / 255.0,
            blue:  Double(rgb         & 0xFF) / 255.0
        )
    }
}
