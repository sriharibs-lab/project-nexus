// Generated from design-system/tokens/colors.json — do not edit manually.
import SwiftUI
import UIKit

extension Color {
    /// Adaptive color resolved by the system trait — one light hex, one dark hex.
    /// Every brand token below is adaptive, so the whole app follows the
    /// Appearance setting (System / Light / Dark) with no per-view work.
    static func adaptive(_ light: String, _ dark: String) -> Color {
        Color(uiColor: UIColor { trait in
            UIColor(nexusHex: trait.userInterfaceStyle == .dark ? dark : light)
        })
    }

    enum Nexus {
        // Brand — plum in light; lifted to lilac in dark (BRAND.md dark variants).
        static let accent  = adaptive("#7054AB", "#A990E6")
        static let bloom   = adaptive("#E7DCF4", "#3A2E5C")

        // Neutral scale — WARM. Light = Cream family; dark = deep warm gray,
        // same restraint (DESIGN_LANGUAGE: dark mode is deep gray, not black).
        static let white         = Color(hex: "#FFFFFF")
        static let surface3      = adaptive("#FBF9F4", "#221D18")
        static let pageEnd       = adaptive("#F7F3EC", "#16120E")
        static let surface2      = adaptive("#EFEBE1", "#2A241E")
        static let hair          = adaptive("#EAE4D8", "#30291F")
        static let border        = adaptive("#E6DFD2", "#3A3228")
        static let borderStrong  = adaptive("#D6CDBD", "#4A4033")
        static let ghost         = adaptive("#B5AD9E", "#6B6256")
        static let faint         = adaptive("#948C7D", "#8A8070")
        static let muted         = adaptive("#6A6253", "#B3A999")
        static let ink           = adaptive("#130E1A", "#F4EFE8")
        static let inkDeep       = adaptive("#0A0710", "#FFFFFF")
        /// Text/glyph color ON an ink-filled control (ink flips to near-white
        /// in dark, so "white on ink" would vanish there).
        static let onInk         = adaptive("#FFFFFF", "#16120E")

        // Semantic
        static let pageBackground  = adaptive("#F7F3EC", "#16120E")
        static let cardBackground  = adaptive("#FFFFFF", "#1F1A15")
        static let textPrimary     = adaptive("#130E1A", "#F4EFE8")
        static let textSecondary   = adaptive("#6A6253", "#B3A999")
        static let textTertiary    = adaptive("#948C7D", "#8A8070")

        // Status
        static let destructive     = adaptive("#C0392B", "#E06A5C")
        static let success         = adaptive("#3E8E5A", "#6FC08A")
    }
}

/// Ember gradient stops for the brand mark — light vs dark (BRAND.md).
struct EmberPalette {
    let inner: [Color]      // plum → magenta → coral
    let outer: [Color]      // orchid → peach
    let pearl: [Color]      // node radial: highlight → mid → deep
    let shadow: Color
    let shadowOpacity: Double

    static let light = EmberPalette(
        inner: [Color(hex: "#7054AB"), Color(hex: "#B8569C"), Color(hex: "#E8776A")],
        outer: [Color(hex: "#9A5BB5"), Color(hex: "#F09A78")],
        pearl: [Color(hex: "#CDB8FF"), Color(hex: "#7E5CC4"), Color(hex: "#4B2F86")],
        shadow: Color(hex: "#5E3F9E"), shadowOpacity: 0.30)
    static let dark = EmberPalette(
        inner: [Color(hex: "#B9A2EE"), Color(hex: "#E07BC0"), Color(hex: "#FFA78A")],
        outer: [Color(hex: "#C9B5F5"), Color(hex: "#FFC2A8")],
        pearl: [Color(hex: "#FFFFFF"), Color(hex: "#EFE6FF"), Color(hex: "#B9A2EE")],
        shadow: Color(hex: "#E07BC0"), shadowOpacity: 0.55)
    static func current(_ scheme: ColorScheme) -> EmberPalette { scheme == .dark ? .dark : .light }
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
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = EmberPalette.current(scheme)
        return Canvas { ctx, sz in
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
                ctx.addFilter(.shadow(color: p.shadow.opacity(p.shadowOpacity), radius: 1.3 * s, x: 0, y: 1.2 * s))
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
                    .init(color: p.inner[0], location: 0),
                    .init(color: p.inner[1], location: 0.55),
                    .init(color: p.inner[2], location: 1),
                ]),
                startPoint: CGPoint(x: 12 * s, y: 10 * s), endPoint: CGPoint(x: 36 * s, y: 38 * s))
            ctx.stroke(innerL, with: ember, style: innerStyle)
            ctx.stroke(innerR, with: ember, style: innerStyle)

            // Outer: orchid → peach at 60%.
            let outer = GraphicsContext.Shading.linearGradient(
                Gradient(stops: [
                    .init(color: p.outer[0].opacity(0.6), location: 0),
                    .init(color: p.outer[1].opacity(0.6), location: 1),
                ]),
                startPoint: CGPoint(x: 10 * s, y: 8 * s), endPoint: CGPoint(x: 38 * s, y: 40 * s))
            ctx.stroke(outerL, with: outer, style: outerStyle)
            ctx.stroke(outerR, with: outer, style: outerStyle)

            // Pearl node — radial + a soft white highlight.
            let pearl = GraphicsContext.Shading.radialGradient(
                Gradient(stops: [
                    .init(color: p.pearl[0], location: 0),
                    .init(color: p.pearl[1], location: 0.45),
                    .init(color: p.pearl[2], location: 1),
                ]),
                center: CGPoint(x: 22.68 * s, y: 22.24 * s), startRadius: 0, endRadius: 6.6 * s)
            ctx.fill(node, with: pearl)
            let hl = Path(ellipseIn: CGRect(x: (22.7 - 1.4) * s, y: (22.5 - 0.9) * s, width: 2.8 * s, height: 1.8 * s))
            ctx.fill(hl, with: .color(.white.opacity(0.75)))
        }
        .frame(width: size, height: size)
    }
}

extension UIColor {
    convenience init(nexusHex hex: String) {
        let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
                  blue: CGFloat(rgb & 0xFF) / 255.0, alpha: 1)
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
