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
