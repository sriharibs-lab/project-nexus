/**
 * Design tokens — sourced from design-system/tokens/colors.json + typography.json + spacing.json.
 * Single source of truth for all prototype components.
 * Platform-agnostic values; iOS Swift codegen will consume the same JSON.
 */

export const tokens = {
  color: {
    // Brand
    plum: "#7054AB",
    bloom: "#E7DCF4",

    // Neutrals
    white: "#FFFFFF",
    surface3: "#FBFAFD",
    surface2: "#F4F2F9",
    hair: "#EEEBF5",
    border: "#E9E5F2",
    borderStrong: "#DCD7EA",
    ghost: "#B7B1C4",
    faint: "#9A93AC",
    muted: "#68607A",
    ink: "#130E1A",
    deepInk: "#0A0710",

    // Page
    page: "radial-gradient(135% 60% at 50% -8%, #E7DCF4 0%, #F9F8FC 50%)",

    // Semantic
    surface: "#FFFFFF",

    // Dark mode
    dark: {
      surface: "#0F0D13",
      surface2: "#1A1720",
      elevated: "#231F2A",
      text: "#F0EBF8",
      textSecondary: "#9E97B0",
      border: "#2E2A38",
    },
  },

  font: {
    sans: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif',
    display: '-apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", sans-serif',
  },

  radius: {
    pill: 999,
    card: 20,
    button: 14,
    sm: 10,
  },

  spacing: {
    screenPadding: 16,
    gap: 12,
  },

  motion: {
    ease: "cubic-bezier(.2,.8,.2,1)",
    spring: "cubic-bezier(.34,1.4,.64,1)",
    springBounce: "cubic-bezier(.18,1.5,.4,1)",
    // True-spring linear() baked from k=200, c=15.5, ζ≈0.55
    springLinear:
      "linear(0.0035, 0.0648, 0.2067, 0.3545, 0.5093, 0.6852, 0.8131, 0.9372, 1.0144, 1.0686, 1.1067, 1.1200, 1.1204, 1.1091, 1.0935, 1.0714, 1.0528, 1.0354, 1.0176, 1.0058, 0.9969, 0.9899, 0.9866, 0.9852, 0.9857, 0.9870, 0.9894, 0.9917, 0.9940, 0.9964, 0.9981, 0.9997, 1.0007, 1.0013, 1.0017, 1.0018)",
  },
} as const;

export type Tokens = typeof tokens;
