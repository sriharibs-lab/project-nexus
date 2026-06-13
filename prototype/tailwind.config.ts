import type { Config } from "tailwindcss";

/**
 * Nexus Tailwind config — extends with design system tokens.
 * CSS custom properties (--nx-*) are defined in src/styles/tokens.css.
 * All Tailwind color/spacing/etc utilities that reference var(--nx-*)
 * automatically pick up dark-mode overrides from tokens.css.
 */
const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      /* ─── Colors ─── */
      colors: {
        nx: {
          plum:  "var(--nx-color-brand-plum)",
          bloom: "var(--nx-color-brand-bloom)",

          /* Backgrounds */
          "bg-primary":   "var(--nx-color-bg-primary)",
          "bg-secondary": "var(--nx-color-bg-secondary)",
          "bg-elevated":  "var(--nx-color-bg-elevated)",
          "bg-overlay":   "var(--nx-color-bg-overlay)",

          /* Text */
          "text-primary":   "var(--nx-color-text-primary)",
          "text-secondary": "var(--nx-color-text-secondary)",
          "text-tertiary":  "var(--nx-color-text-tertiary)",
          "text-disabled":  "var(--nx-color-text-disabled)",
          "text-inverse":   "var(--nx-color-text-inverse)",

          /* Borders */
          "border-default": "var(--nx-color-border-default)",
          "border-subtle":  "var(--nx-color-border-subtle)",
          "border-strong":  "var(--nx-color-border-strong)",

          /* Status */
          success: "var(--nx-color-status-success)",
          warning: "var(--nx-color-status-warning)",
          error:   "var(--nx-color-status-error)",
          info:    "var(--nx-color-status-info)",

          /* Neutrals */
          "n-0":    "var(--nx-color-neutral-0)",
          "n-50":   "var(--nx-color-neutral-50)",
          "n-100":  "var(--nx-color-neutral-100)",
          "n-200":  "var(--nx-color-neutral-200)",
          "n-300":  "var(--nx-color-neutral-300)",
          "n-400":  "var(--nx-color-neutral-400)",
          "n-500":  "var(--nx-color-neutral-500)",
          "n-600":  "var(--nx-color-neutral-600)",
          "n-700":  "var(--nx-color-neutral-700)",
          "n-800":  "var(--nx-color-neutral-800)",
          "n-900":  "var(--nx-color-neutral-900)",
          "n-1000": "var(--nx-color-neutral-1000)",
        },
      },

      /* ─── Font Families ─── */
      fontFamily: {
        ui:      "var(--nx-font-ui)",
        display: "var(--nx-font-display)",
        mono:    "var(--nx-font-mono)",
      },

      /* ─── Font Sizes (with default leading/tracking) ─── */
      fontSize: {
        "nx-xs":   ["var(--nx-text-xs)",   { lineHeight: "var(--nx-leading-tight)",  letterSpacing: "var(--nx-tracking-widest)" }],
        "nx-sm":   ["var(--nx-text-sm)",   { lineHeight: "var(--nx-leading-tight)",  letterSpacing: "-0.05px" }],
        "nx-base": ["var(--nx-text-base)", { lineHeight: "var(--nx-leading-normal)", letterSpacing: "var(--nx-tracking-normal)" }],
        "nx-md":   ["var(--nx-text-md)",   { lineHeight: "var(--nx-leading-normal)", letterSpacing: "var(--nx-tracking-normal)" }],
        "nx-lg":   ["var(--nx-text-lg)",   { lineHeight: "var(--nx-leading-loose)",  letterSpacing: "var(--nx-tracking-normal)" }],
        "nx-xl":   ["var(--nx-text-xl)",   { lineHeight: "var(--nx-leading-normal)", letterSpacing: "var(--nx-tracking-normal)" }],
        "nx-2xl":  ["var(--nx-text-2xl)",  { lineHeight: "var(--nx-leading-relaxed)",letterSpacing: "var(--nx-tracking-normal)" }],
        "nx-3xl":  ["var(--nx-text-3xl)",  { lineHeight: "var(--nx-leading-snug)",   letterSpacing: "var(--nx-tracking-tight)" }],
        "nx-4xl":  ["var(--nx-text-4xl)",  { lineHeight: "var(--nx-leading-snug)",   letterSpacing: "var(--nx-tracking-tighter)" }],
        "nx-5xl":  ["var(--nx-text-5xl)",  { lineHeight: "var(--nx-leading-tight)",  letterSpacing: "-0.7px" }],
        "nx-6xl":  ["var(--nx-text-6xl)",  { lineHeight: "var(--nx-leading-tight)",  letterSpacing: "-0.6px" }],
        "nx-7xl":  ["var(--nx-text-7xl)",  { lineHeight: "var(--nx-leading-tight)",  letterSpacing: "var(--nx-tracking-tightest)" }],
      },

      /* ─── Font Weights ─── */
      fontWeight: {
        "nx-regular":   "var(--nx-weight-regular)",
        "nx-medium":    "var(--nx-weight-medium)",
        "nx-semibold":  "var(--nx-weight-semibold)",
        "nx-bold":      "var(--nx-weight-bold)",
        "nx-extrabold": "var(--nx-weight-extrabold)",
      },

      /* ─── Spacing ─── */
      spacing: {
        "nx-0":  "var(--nx-space-0)",
        "nx-1":  "var(--nx-space-1)",
        "nx-2":  "var(--nx-space-2)",
        "nx-3":  "var(--nx-space-3)",
        "nx-4":  "var(--nx-space-4)",
        "nx-5":  "var(--nx-space-5)",
        "nx-6":  "var(--nx-space-6)",
        "nx-7":  "var(--nx-space-7)",
        "nx-8":  "var(--nx-space-8)",
        "nx-10": "var(--nx-space-10)",
        "nx-12": "var(--nx-space-12)",
        "nx-14": "var(--nx-space-14)",
        "nx-16": "var(--nx-space-16)",
        "nx-20": "var(--nx-space-20)",
        "nx-24": "var(--nx-space-24)",
      },

      /* ─── Border Radius ─── */
      borderRadius: {
        "nx-none": "var(--nx-radius-none)",
        "nx-xs":   "var(--nx-radius-xs)",
        "nx-sm":   "var(--nx-radius-sm)",
        "nx-base": "var(--nx-radius-base)",
        "nx-md":   "var(--nx-radius-md)",
        "nx-lg":   "var(--nx-radius-lg)",
        "nx-xl":   "var(--nx-radius-xl)",
        "nx-2xl":  "var(--nx-radius-2xl)",
        "nx-3xl":  "var(--nx-radius-3xl)",
        "nx-full": "var(--nx-radius-full)",
      },

      /* ─── Box Shadow ─── */
      boxShadow: {
        "nx-xs":    "var(--nx-shadow-xs)",
        "nx-sm":    "var(--nx-shadow-sm)",
        "nx-md":    "var(--nx-shadow-md)",
        "nx-lg":    "var(--nx-shadow-lg)",
        "nx-xl":    "var(--nx-shadow-xl)",
        "nx-sheet": "var(--nx-shadow-sheet)",
        "nx-focus": "var(--nx-shadow-focus)",
        "nx-inner": "var(--nx-shadow-inner)",
      },

      /* ─── Max Width ─── */
      maxWidth: {
        "nx-xs":   "var(--nx-max-xs)",
        "nx-sm":   "var(--nx-max-sm)",
        "nx-md":   "var(--nx-max-md)",
        "nx-lg":   "var(--nx-max-lg)",
        "nx-xl":   "var(--nx-max-xl)",
        "nx-2xl":  "var(--nx-max-2xl)",
      },

      /* ─── Transition Timing ─── */
      transitionDuration: {
        "nx-instant":    "var(--nx-dur-instant)",
        "nx-fast":       "var(--nx-dur-fast)",
        "nx-base":       "var(--nx-dur-base)",
        "nx-moderate":   "var(--nx-dur-moderate)",
        "nx-slow":       "var(--nx-dur-slow)",
        "nx-slower":     "var(--nx-dur-slower)",
        "nx-sheet":      "var(--nx-dur-sheet)",
        "nx-menu-open":  "var(--nx-dur-menu-open)",
        "nx-menu-close": "var(--nx-dur-menu-close)",
      },
      transitionTimingFunction: {
        "nx-spring":     "var(--nx-ease-spring)",
        "nx-snappy":     "var(--nx-ease-snappy)",
        "nx-emphasized": "var(--nx-ease-emphasized)",
        "nx-ease-out":   "var(--nx-ease-out)",
        "nx-ease-in":    "var(--nx-ease-in)",
      },
    },
  },
  plugins: [],
};

export default config;
