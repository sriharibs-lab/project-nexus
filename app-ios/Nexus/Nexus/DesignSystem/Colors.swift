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
        static let pageEnd       = Color(hex: "#F9F8FC")
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
        static let pageBackground  = Color(hex: "#F9F8FC")
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
                colors: [Color.Nexus.bloom.opacity(0.5), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.48)
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Echo mark (canonical)

/// The Nexus brand mark: two facing C-arcs with a filled center dot.
/// Translated exactly from logo.jsx in the design system (48×48 viewBox).
/// Arc geometry: left arcs CCW, right arcs CW — all endpoints match the SVG arc paths.
struct EchoMark: View {
    var color: Color = Color.Nexus.accent
    var size: CGFloat = 48

    var body: some View {
        Canvas { ctx, sz in
            let s = sz.width / 48.0

            // Inner arcs — strokeWidth 3, full opacity
            // SwiftUI Path.addArc uses CG Y-up convention: clockwise:true = CCW on screen.
            // Left "(" arc: appears CCW on screen → clockwise: true
            var li = Path()
            li.addArc(center: CGPoint(x: 26.05 * s, y: 24 * s),
                      radius: 11 * s,
                      startAngle: .degrees(226.6),
                      endAngle: .degrees(133.4),
                      clockwise: true)
            ctx.stroke(li, with: .color(color),
                       style: StrokeStyle(lineWidth: 3 * s, lineCap: .round))

            // Right ")" arc: appears CW on screen → clockwise: false
            var ri = Path()
            ri.addArc(center: CGPoint(x: 21.95 * s, y: 24 * s),
                      radius: 11 * s,
                      startAngle: .degrees(313.4),
                      endAngle: .degrees(46.6),
                      clockwise: false)
            ctx.stroke(ri, with: .color(color),
                       style: StrokeStyle(lineWidth: 3 * s, lineCap: .round))

            // Outer arcs — strokeWidth 2.2, opacity 0.32
            let outer = color.opacity(0.32)
            // Left outer: CCW on screen → clockwise: true
            var lo = Path()
            lo.addArc(center: CGPoint(x: 23.298 * s, y: 24 * s),
                      radius: 17.5 * s,
                      startAngle: .degrees(236),
                      endAngle: .degrees(124),
                      clockwise: true)
            ctx.stroke(lo, with: .color(outer),
                       style: StrokeStyle(lineWidth: 2.2 * s, lineCap: .round))

            // Right outer: CW on screen → clockwise: false
            var ro = Path()
            ro.addArc(center: CGPoint(x: 24.702 * s, y: 24 * s),
                      radius: 17.5 * s,
                      startAngle: .degrees(304),
                      endAngle: .degrees(56),
                      clockwise: false)
            ctx.stroke(ro, with: .color(outer),
                       style: StrokeStyle(lineWidth: 2.2 * s, lineCap: .round))

            // Center dot: cx=24, cy=24, r=4.4, filled
            let dotR = 4.4 * s
            let dot = Path(ellipseIn: CGRect(x: 24 * s - dotR, y: 24 * s - dotR,
                                             width: dotR * 2, height: dotR * 2))
            ctx.fill(dot, with: .color(color))
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
