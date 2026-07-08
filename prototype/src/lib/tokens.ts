/**
 * Design tokens — typed mirror of src/styles/tokens.css custom properties.
 *
 * FIDELITY CONTRACT: no raw hex/px values in components — everything routes
 * through here, and this file contains ONLY var() references (plus the one
 * JS-only exception, springLinear, which CSS custom properties can't express).
 * tokens.css is generated from design-system/tokens/*.json — the same JSON
 * that feeds the iOS Swift token codegen.
 */

export const tokens = {
  color: {
    plum: "var(--nx-color-brand-plum)",
    bloom: "var(--nx-color-brand-bloom)",

    page: "var(--nx-color-page)",
    surface: "var(--nx-color-bg-primary)",
    surface2: "var(--nx-color-bg-secondary)",
    surface3: "var(--nx-color-bg-elevated)",
    overlay: "var(--nx-color-bg-overlay)",

    ink: "var(--nx-color-text-primary)",
    muted: "var(--nx-color-text-secondary)",
    faint: "var(--nx-color-text-tertiary)",
    ghost: "var(--nx-color-text-disabled)",
    inverse: "var(--nx-color-text-inverse)",

    border: "var(--nx-color-border-default)",
    borderStrong: "var(--nx-color-border-strong)",
    hair: "var(--nx-color-border-subtle)",

    success: "var(--nx-color-status-success)",
    warning: "var(--nx-color-status-warning)",
    error: "var(--nx-color-status-error)",

    shimmerA: "var(--nx-color-shimmer-a)",
    shimmerB: "var(--nx-color-shimmer-b)",
    canvasDesktop: "var(--nx-color-canvas-desktop)",

    // Compat aliases (older pages)
    white: "var(--nx-color-neutral-0)",
    deepInk: "var(--nx-color-neutral-1000)",
  },

  font: {
    ui: "var(--nx-font-ui)",
    display: "var(--nx-font-display)",
    mono: "var(--nx-font-mono)",
    // Compat alias (older pages)
    sans: "var(--nx-font-ui)",
  },

  radius: {
    xs: "var(--nx-radius-xs)",
    sm: "var(--nx-radius-sm)",
    base: "var(--nx-radius-base)",
    md: "var(--nx-radius-md)",
    lg: "var(--nx-radius-lg)",
    xl: "var(--nx-radius-xl)",
    xxl: "var(--nx-radius-2xl)",
    xxxl: "var(--nx-radius-3xl)",
    full: "var(--nx-radius-full)",
  },

  shadow: {
    xs: "var(--nx-shadow-xs)",
    sm: "var(--nx-shadow-sm)",
    md: "var(--nx-shadow-md)",
    lg: "var(--nx-shadow-lg)",
    xl: "var(--nx-shadow-xl)",
    sheet: "var(--nx-shadow-sheet)",
    focus: "var(--nx-shadow-focus)",
  },

  motion: {
    ease: "var(--nx-ease-out)",
    easeIn: "var(--nx-ease-in)",
    spring: "var(--nx-ease-spring)",
    snappy: "var(--nx-ease-snappy)",
    emphasized: "var(--nx-ease-emphasized)",
    // Transition shorthands (duration + easing)
    micro: "var(--nx-transition-micro)",
    microBack: "var(--nx-transition-micro-back)",
    element: "var(--nx-transition-element)",
    panel: "var(--nx-transition-panel)",
    pageForward: "var(--nx-transition-page-forward)",
    pageBack: "var(--nx-transition-page-back)",
    pivot: "var(--nx-transition-pivot)",
    footer: "var(--nx-transition-footer)",
    modalExit: "var(--nx-transition-modal-exit)",
    // JS-only exception: CSS linear() spring cannot live in a custom property.
    // True-spring baked from k=200, c=15.5, ζ≈0.55 (see design-system/tokens/motion.json).
    springLinear:
      "linear(0.0035, 0.0648, 0.2067, 0.3545, 0.5093, 0.6852, 0.8131, 0.9372, 1.0144, 1.0686, 1.1067, 1.1200, 1.1204, 1.1091, 1.0935, 1.0714, 1.0528, 1.0354, 1.0176, 1.0058, 0.9969, 0.9899, 0.9866, 0.9852, 0.9857, 0.9870, 0.9894, 0.9917, 0.9940, 0.9964, 0.9981, 0.9997, 1.0007, 1.0013, 1.0017, 1.0018)",
  },

  scale: {
    pressLight: 0.97,
    pressBase: 0.93,
    pressHeavy: 0.88,
    pressAvatar: 0.84,
    menuOrigin: 0.12,
  },

  layout: {
    safeTop: "var(--nx-safe-top)",
    safeBottom: "var(--nx-safe-bottom)",
    padMobile: "var(--nx-pad-mobile)",
  },
} as const;

/**
 * lTheme()-shaped adapter — same key names the design-handoff mocks use
 * (`t.surface`, `t.border`, `t.muted`, `t.hair`, `t.ink`, `t.page`…), so
 * porting a mock component is a mechanical import swap, not a rewrite.
 */
export const t = {
  page: tokens.color.page,
  surface: tokens.color.surface,
  surface2: tokens.color.surface2,
  surface3: tokens.color.surface3,
  text: tokens.color.ink,
  muted: tokens.color.muted,
  faint: tokens.color.faint,
  ghost: tokens.color.ghost,
  border: tokens.color.border,
  borderStrong: tokens.color.borderStrong,
  hair: tokens.color.hair,
  ink: tokens.color.ink,
  inkInk: tokens.color.inverse,
  plum: tokens.color.plum,
  bloom: tokens.color.bloom,
} as const;

export type Tokens = typeof tokens;
