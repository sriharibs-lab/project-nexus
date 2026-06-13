// Generated from design-system/tokens/typography.json — do not edit manually.
// All sizes in points (1pt = 1px on non-retina, matches token px values).
import SwiftUI

extension Font {
    enum Nexus {
        static let displayLarge  = Font.system(size: 40,   weight: .bold)
        static let displayMedium = Font.system(size: 32,   weight: .bold)
        static let headingLarge  = Font.system(size: 26,   weight: .bold)
        static let headingMedium = Font.system(size: 22,   weight: .bold)
        static let headingSmall  = Font.system(size: 19,   weight: .bold)
        static let bodyLarge     = Font.system(size: 16.5, weight: .medium)
        static let bodyMedium    = Font.system(size: 15,   weight: .medium)
        static let bodySmall     = Font.system(size: 13.5, weight: .medium)
        static let labelLarge    = Font.system(size: 13.5, weight: .semibold)
        static let labelMedium   = Font.system(size: 13,   weight: .semibold)
        static let labelSmall    = Font.system(size: 11.5, weight: .semibold)
        static let caption       = Font.system(size: 11,   weight: .medium)
        static let overline      = Font.system(size: 10,   weight: .medium)
    }
}

// Letter-spacing values (em-based, applied via .kerning() modifier).
enum NexusKerning {
    static let tightest: CGFloat = -0.8   // 26px+
    static let tighter:  CGFloat = -0.5   // headings 22–24px
    static let tight:    CGFloat = -0.4   // pivots, subheadings
    static let snug:     CGFloat = -0.2   // avatar initials
    static let normal:   CGFloat = -0.1   // base UI, most labels
    static let wide:     CGFloat = 0
}
