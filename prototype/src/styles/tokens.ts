/**
 * Nexus Design System — TypeScript token mirror
 * Source: design-system/tokens/*.json
 *
 * Use CSS custom properties (var(--nx-*)) in stylesheets.
 * Use this module for: inline styles, dynamic values, Tailwind config extension.
 *
 * NOTE: These are raw values only. Dark-mode overrides live in tokens.css.
 */

export const color = {
  brand: {
    plum:  "#7054AB",
    bloom: "#E7DCF4",
  },
  neutral: {
    0:    "#FFFFFF",
    50:   "#FBFAFD",
    100:  "#F9F8FC",
    200:  "#F4F2F9",
    300:  "#EEEBF5",
    400:  "#E9E5F2",
    500:  "#DCD7EA",
    600:  "#B7B1C4",
    700:  "#9A93AC",
    800:  "#68607A",
    900:  "#130E1A",
    1000: "#0A0710",
  },
  semantic: {
    page:       "radial-gradient(135% 60% at 50% -8%, #E7DCF4 0%, #F9F8FC 50%)",
    bg: {
      primary:   "#FFFFFF",
      secondary: "#F4F2F9",
      elevated:  "#FBFAFD",
      overlay:   "rgba(19,14,26,0.50)",
    },
    text: {
      primary:   "#130E1A",
      secondary: "#68607A",
      tertiary:  "#9A93AC",
      disabled:  "#B7B1C4",
      inverse:   "#FFFFFF",
    },
    border: {
      default: "#E9E5F2",
      subtle:  "#EEEBF5",
      strong:  "#DCD7EA",
    },
    status: {
      success: "#3D9E5F",
      warning: "#D97706",
      error:   "#DC2626",
      info:    "#7054AB",
    },
  },
} as const;

export const typography = {
  fontFamily: {
    ui:      '-apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif',
    display: '"Geist", -apple-system, sans-serif',
    mono:    '"SF Mono", "Fira Code", monospace',
  },
  fontSize: {
    xs:   "10px",
    sm:   "11.5px",
    base: "13px",
    md:   "13.5px",
    lg:   "15px",
    xl:   "16px",
    "2xl": "16.5px",
    "3xl": "19px",
    "4xl": "22px",
    "5xl": "26px",
    "6xl": "32px",
    "7xl": "40px",
  },
  fontWeight: {
    regular:   400,
    medium:    500,
    semibold:  600,
    bold:      700,
    extrabold: 800,
  },
  lineHeight: {
    tight:   1.2,
    snug:    1.3,
    normal:  1.4,
    relaxed: 1.55,
    loose:   1.6,
  },
  letterSpacing: {
    tightest: "-0.8px",
    tighter:  "-0.5px",
    tight:    "-0.4px",
    snug:     "-0.2px",
    normal:   "-0.1px",
    wide:     "0",
    wider:    "0.05em",
    widest:   "0.08em",
  },
} as const;

export const spacing = {
  0:  "0px",
  1:  "4px",
  2:  "8px",
  3:  "12px",
  4:  "14px",
  5:  "16px",
  6:  "20px",
  7:  "24px",
  8:  "28px",
  10: "32px",
  12: "40px",
  14: "44px",
  16: "48px",
  20: "60px",
  24: "96px",
} as const;

export const borderRadius = {
  none: "0px",
  xs:   "6px",
  sm:   "9px",
  base: "13px",
  md:   "14px",
  lg:   "16px",
  xl:   "22px",
  "2xl": "24px",
  "3xl": "26px",
  full: "9999px",
} as const;

export const borderWidth = {
  none:   "0px",
  hair:   "0.5px",
  base:   "1px",
  medium: "1.5px",
  thick:  "2px",
} as const;

export const shadow = {
  xs:    "0 1px 2px rgba(19,14,26,0.03)",
  sm:    "0 2px 6px rgba(19,14,26,0.06)",
  md:    "0 4px 12px rgba(19,14,26,0.10)",
  lg:    "0 8px 24px rgba(19,14,26,0.15)",
  xl:    "0 22px 58px rgba(19,14,26,0.20)",
  sheet: "0 -12px 40px rgba(19,14,26,0.20)",
  focus: "0 0 0 3px #F4F2F9",
  inner: "inset 0 1px 3px rgba(19,14,26,0.08)",
} as const;

export const layout = {
  maxWidth: {
    xs:   "320px",
    sm:   "390px",
    md:   "430px",
    lg:   "768px",
    xl:   "1024px",
    "2xl": "1280px",
    full: "100%",
  },
  contentPadding: {
    mobile:  "14px",
    tablet:  "24px",
    desktop: "32px",
  },
  safeArea: {
    top:    "60px",
    bottom: "34px",
  },
} as const;

export const motion = {
  duration: {
    instant:   "50ms",
    fast:      "150ms",
    base:      "240ms",
    moderate:  "380ms",
    slow:      "480ms",
    slower:    "520ms",
    sheet:     "520ms",
    menuOpen:  "420ms",
    menuClose: "260ms",
    shimmer:   "1600ms",
  },
  easing: {
    linear:     "cubic-bezier(0.0,0.0,1.0,1.0)",
    easeIn:     "cubic-bezier(0.4,0.0,0.9,0.35)",
    easeOut:    "cubic-bezier(0.2,0.8,0.2,1.0)",
    easeInOut:  "cubic-bezier(0.4,0.0,0.2,1.0)",
    spring:     "cubic-bezier(0.18,1.5,0.4,1.0)",
    snappy:     "cubic-bezier(0.32,0.72,0.28,1.0)",
    emphasized: "cubic-bezier(0.22,1.18,0.36,1.0)",
    /** True baked spring k=200 c=15.5 ζ≈0.55 — use inline as CSS linear() string */
    springTrue: "linear(0, 0.009, 0.035 2.1%, 0.141, 0.281 6.7%, 0.723 12.9%, 0.938 16.7%, 1.064 20.1%, 1.109 22.4%, 1.12 24.5%, 1.106 27.3%, 0.999 36.8%, 0.984 40.5%, 1.004 47.7%, 1.001 50.2%, 1.0 100%)",
  },
  transition: {
    micro:       "240ms cubic-bezier(0.18,1.5,0.4,1)",
    microBack:   "440ms cubic-bezier(0.18,1.5,0.4,1)",
    element:     "260ms cubic-bezier(0.4,0,0.9,0.35)",
    panel:       "520ms cubic-bezier(0.32,0.72,0.28,1)",
    pageForward: "480ms cubic-bezier(0.2,0.8,0.2,1)",
    pageBack:    "380ms cubic-bezier(0.2,0.8,0.2,1)",
    pivot:       "380ms cubic-bezier(0.2,0.8,0.2,1)",
    footerReveal:"400ms cubic-bezier(0.22,1.18,0.36,1)",
    modalExit:   "260ms cubic-bezier(0.4,0,0.9,0.35)",
  },
  scale: {
    pressLight:  0.97,
    pressBase:   0.93,
    pressHeavy:  0.88,
    pressAvatar: 0.84,
    menuOrigin:  0.12,
    tabSquashX:  1.13,
    tabSquashY:  0.87,
  },
} as const;

/** Convenience: CSS variable reference helpers */
export const vars = {
  color: {
    brand: {
      plum:  "var(--nx-color-brand-plum)",
      bloom: "var(--nx-color-brand-bloom)",
    },
    bg: {
      primary:   "var(--nx-color-bg-primary)",
      secondary: "var(--nx-color-bg-secondary)",
      elevated:  "var(--nx-color-bg-elevated)",
      overlay:   "var(--nx-color-bg-overlay)",
    },
    text: {
      primary:   "var(--nx-color-text-primary)",
      secondary: "var(--nx-color-text-secondary)",
      tertiary:  "var(--nx-color-text-tertiary)",
      disabled:  "var(--nx-color-text-disabled)",
      inverse:   "var(--nx-color-text-inverse)",
    },
    border: {
      default: "var(--nx-color-border-default)",
      subtle:  "var(--nx-color-border-subtle)",
      strong:  "var(--nx-color-border-strong)",
    },
    status: {
      success: "var(--nx-color-status-success)",
      warning: "var(--nx-color-status-warning)",
      error:   "var(--nx-color-status-error)",
      info:    "var(--nx-color-status-info)",
    },
  },
} as const;
