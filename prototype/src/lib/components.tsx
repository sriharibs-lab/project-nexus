"use client";

/**
 * Shared UI primitives — faithful to DESIGN_LANGUAGE.md.
 *
 * Material model:
 *   - Inline controls: solid fill + hairline border. No glass.
 *   - Floating layers: Liquid Glass (menus, modals).
 *
 * Motion: spring-press on every tappable. Pivot swipe for tab transitions.
 */

import React, { useState } from "react";
import { tokens } from "./tokens";

const t = tokens.color;
const font = tokens.font;

// ── Icon set — thin geometric stroke (1.6px), matches hairline aesthetic ──

interface IconProps {
  name: keyof typeof ICONS;
  size?: number;
  color?: string;
  stroke?: number;
}

// SVG path props — typed as SVGProps<SVGPathElement> since all shape elements
// accept the common presentation attributes (fill, stroke, etc.).
type P = React.SVGProps<SVGPathElement>;

const ICONS = {
  search: (p: P) => (
    <>
      <circle cx="11" cy="11" r="7" fill={p.fill} stroke={p.stroke} strokeWidth={p.strokeWidth} strokeLinecap={p.strokeLinecap} strokeLinejoin={p.strokeLinejoin} />
      <path d="m20 20-3.4-3.4" {...p} />
    </>
  ),
  plus: (p: P) => <path d="M12 5v14M5 12h14" {...p} />,
  mic: (p: P) => (
    <>
      <rect x="9" y="3" width="6" height="12" rx="3" fill={p.fill} stroke={p.stroke} strokeWidth={p.strokeWidth} strokeLinecap={p.strokeLinecap} strokeLinejoin={p.strokeLinejoin} />
      <path d="M5 11a7 7 0 0 0 14 0M12 18v3" {...p} />
    </>
  ),
  globe: (p: P) => (
    <>
      <circle cx="12" cy="12" r="9" fill={p.fill} stroke={p.stroke} strokeWidth={p.strokeWidth} strokeLinecap={p.strokeLinecap} strokeLinejoin={p.strokeLinejoin} />
      <path d="M3 12h18" {...p} />
      <path d="M12 3C8 5 8 19 12 21M12 3C16 5 16 19 12 21" {...p} />
    </>
  ),
  video: (p: P) => (
    <>
      <rect x="3" y="5.5" width="18" height="13" rx="3.5" fill={p.fill} stroke={p.stroke} strokeWidth={p.strokeWidth} strokeLinecap={p.strokeLinecap} strokeLinejoin={p.strokeLinejoin} />
      <path
        d="M10.5 9.3v5.4l4.4-2.7-4.4-2.7Z"
        fill="currentColor"
        stroke="currentColor"
        strokeWidth="1.2"
        strokeLinejoin="round"
      />
    </>
  ),
  file: (p: P) => (
    <>
      <path d="M7 3h7l4 4v14H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1Z" {...p} />
      <path d="M14 3v4h4" {...p} />
    </>
  ),
  chevDown: (p: P) => <path d="m6 9 6 6 6-6" {...p} />,
  chevLeft: (p: P) => <path d="m15 5-7 7 7 7" {...p} />,
  chevRight: (p: P) => <path d="m9 5 7 7-7 7" {...p} />,
  x: (p: P) => <path d="M6 6l12 12M18 6 6 18" {...p} />,
  check: (p: P) => <path d="m5 12.5 4.5 4.5L19 7" {...p} />,
  sparkle: (p: P) => (
    <path d="M12 3.2c.4 6 2.6 8.2 8.6 8.6-6 .4-8.2 2.6-8.6 8.6-.4-6-2.6-8.2-8.6-8.6 6-.4 8.2-2.6 8.6-8.6Z" {...p} />
  ),
  nexus: (p: P) => (
    <>
      <g fill={p.fill} stroke={p.stroke} strokeWidth={p.strokeWidth} strokeLinecap={p.strokeLinecap} strokeLinejoin={p.strokeLinejoin}>
        <path d="M9.25 8 A5.5 5.5 0 0 0 9.25 16" />
        <path d="M14.75 8 A5.5 5.5 0 0 1 14.75 16" />
      </g>
      <g fill={p.fill} stroke={p.stroke} strokeWidth={p.strokeWidth} strokeLinecap={p.strokeLinecap} strokeLinejoin={p.strokeLinejoin} opacity={0.35}>
        <path d="M6.75 4.75 A8.75 8.75 0 0 0 6.75 19.25" />
        <path d="M17.25 4.75 A8.75 8.75 0 0 1 17.25 19.25" />
      </g>
      <circle cx="12" cy="12" r="2.3" fill="currentColor" stroke="none" />
    </>
  ),
  send: (p: P) => <path d="M12 19V5m-6 6 6-6 6 6" {...p} />,
  layers: (p: P) => (
    <>
      <path d="M12 3 21 8l-9 5-9-5 9-5Z" {...p} />
      <path d="M3 13l9 5 9-5" {...p} />
    </>
  ),
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  waveform: (_p: P) => (
    <>
      {([[5, 8],[9.5, 15],[14, 7],[18.5, 12]] as [number, number][]).map(([x, h], i) => (
        <rect key={i} x={x - 1.4} y={12 - h / 2} width={2.8} height={h} rx={1.4} fill="currentColor" />
      ))}
    </>
  ),
};

export function Icon({
  name,
  size = 22,
  color = "currentColor",
  stroke = 1.6,
}: IconProps) {
  const p = {
    fill: "none" as const,
    stroke: color,
    strokeWidth: stroke,
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
  };
  const IconShape = ICONS[name];
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      style={{ flex: "0 0 auto", display: "block" }}
    >
      {IconShape(p)}
    </svg>
  );
}

// ── Press-spring wrapper — every tappable ──

interface PressableProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  scale?: number;
  as?: "button" | "div";
  children: React.ReactNode;
}

export function Pressable({
  scale = 0.95,
  onClick,
  style,
  children,
  className,
  ...rest
}: PressableProps) {
  const [down, setDown] = useState(false);
  return (
    <button
      {...rest}
      onPointerDown={() => setDown(true)}
      onPointerUp={() => setDown(false)}
      onPointerLeave={() => setDown(false)}
      onPointerCancel={() => setDown(false)}
      onClick={onClick}
      style={{
        ...style,
        transform: down ? `scale(${scale})` : "scale(1)",
        transition: `transform 0.24s cubic-bezier(.18,1.5,.4,1)`,
        WebkitTapHighlightColor: "transparent",
        touchAction: "manipulation",
        cursor: "pointer",
        border: "none",
        padding: 0,
        background: "transparent",
      }}
      className={className}
    >
      {children}
    </button>
  );
}

// ── Icon button (inline, hairline border) ──

export function IconButton({
  name,
  size = 36,
  iconSize = 18,
  color,
  onClick,
  style,
}: {
  name: keyof typeof ICONS;
  size?: number;
  iconSize?: number;
  color?: string;
  onClick?: () => void;
  style?: React.CSSProperties;
}) {
  return (
    <Pressable
      onClick={onClick}
      style={{
        width: size,
        height: size,
        borderRadius: 999,
        background: t.surface,
        border: `1px solid ${t.border}`,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        flexShrink: 0,
        ...style,
      }}
    >
      <Icon name={name} size={iconSize} color={color ?? t.muted} />
    </Pressable>
  );
}

// ── Avatar (initials, neutral) ──

export function Avatar({
  initials = "S",
  size = 36,
}: {
  initials?: string;
  size?: number;
}) {
  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: 999,
        flexShrink: 0,
        background: t.surface,
        border: `1px solid ${t.borderStrong}`,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        fontSize: size * 0.38,
        fontWeight: 600,
        letterSpacing: -0.2,
        color: t.ink,
      }}
    >
      {initials}
    </div>
  );
}

// ── Responsive breakpoint hook ──
//
// Returns true when the viewport is narrower than 640 px (mobile-native mode).
// Defaults to false on the server so the desktop frame is the SSR fallback,
// avoiding layout shift on large screens. The effect fires synchronously after
// hydration so mobile clients snap to full-screen in the first paint.

function useIsNarrow(): boolean {
  const [narrow, setNarrow] = React.useState(false);

  React.useEffect(() => {
    const mq = window.matchMedia("(max-width: 639px)");
    const handler = (e: MediaQueryListEvent) => setNarrow(e.matches);
    setNarrow(mq.matches);
    mq.addEventListener("change", handler);
    return () => mq.removeEventListener("change", handler);
  }, []);

  return narrow;
}

// ── Mobile frame wrapper ──
//
// Responsive:
//   mobile  (<640 px): fills the real viewport — no frame chrome, no padding.
//   desktop (≥640 px): centered 390×844 iPhone mockup on warm canvas (#EDEBE6).
//
// All consumer screens remain unchanged — MobileFrame adapts around them.

export function MobileFrame({ children }: { children: React.ReactNode }) {
  const isNarrow = useIsNarrow();

  if (isNarrow) {
    // On a real phone/narrow window — the app IS the viewport.
    return (
      <div
        style={{
          width: "100%",
          // height: 100dvh gives child screens a reference to resolve height: 100%,
          // just like the fixed 844px desktop mockup does. overflow: hidden lets
          // each screen manage its own scrollable areas internally.
          height: "100dvh",
          background: t.surface,
          fontFamily: font.sans,
          position: "relative",
          overflow: "hidden",
          display: "flex",
          flexDirection: "column",
        }}
      >
        {children}
      </div>
    );
  }

  // Desktop: centered phone mockup on warm canvas.
  return (
    <div
      style={{
        minHeight: "100vh",
        background: "#EDEBE6",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: 28,
        fontFamily: font.sans,
      }}
    >
      <div
        style={{
          width: 390,
          height: 844,
          borderRadius: 54,
          overflow: "hidden",
          boxShadow:
            "0 0 0 1px rgba(0,0,0,0.12), 0 32px 80px rgba(0,0,0,0.28), inset 0 0 0 1px rgba(255,255,255,0.15)",
          position: "relative",
          background: t.surface,
          flexShrink: 0,
        }}
      >
        {children}
      </div>
    </div>
  );
}

// ── iOS status bar ──
//
// Responsive:
//   mobile  (<640 px): a minimal safe-area spacer (respects env(safe-area-inset-top)
//             for notch/Dynamic Island on real devices). No clock/battery chrome —
//             the browser already provides those.
//   desktop (≥640 px): full faux iOS status bar with 9:41 clock and battery icon.

export function StatusBar() {
  const isNarrow = useIsNarrow();

  if (isNarrow) {
    // Minimal spacer that respects the device safe area inset.
    return (
      <div
        style={{
          flexShrink: 0,
          // fallback 20px for environments where the CSS env() isn't set
          paddingTop: "max(env(safe-area-inset-top), 20px)",
        }}
      />
    );
  }

  // Desktop faux status bar.
  return (
    <div
      style={{
        height: 54,
        display: "flex",
        alignItems: "flex-end",
        justifyContent: "space-between",
        padding: "0 28px 8px",
        flexShrink: 0,
      }}
    >
      <span style={{ fontSize: 15, fontWeight: 600, color: t.ink, letterSpacing: -0.3 }}>
        9:41
      </span>
      <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
        {/* signal bars */}
        <svg width={16} height={12} viewBox="0 0 16 12">
          {[0, 1, 2, 3].map((i) => (
            <rect
              key={i}
              x={i * 4}
              y={12 - (i + 1) * 3}
              width={3}
              height={(i + 1) * 3}
              rx={1}
              fill={t.ink}
              opacity={i < 3 ? 1 : 0.3}
            />
          ))}
        </svg>
        <span style={{ fontSize: 12, fontWeight: 600, color: t.ink }}>Wi-Fi</span>
        {/* battery */}
        <svg width={25} height={12} viewBox="0 0 25 12">
          <rect x={0.5} y={0.5} width={21} height={11} rx={3} stroke={t.ink} strokeWidth={1} fill="none" />
          <rect x={22} y={3.5} width={2.5} height={5} rx={1.5} fill={t.ink} />
          <rect x={2} y={2} width={14} height={8} rx={2} fill={t.ink} />
        </svg>
      </div>
    </div>
  );
}

// ── Home screen nav tab (bottom dock pill) ──
//
// Responsive:
//   mobile  (<640 px): paddingBottom uses safe-area-inset-bottom so the pill
//             clears the home indicator on iPhone models without a Home button.
//   desktop (≥640 px): fixed 24 px bottom padding (matches the phone mockup).

export function BottomTabBar({
  active,
}: {
  active: "home" | "search" | "profile";
}) {
  const isNarrow = useIsNarrow();
  const tabs = [
    { key: "home", icon: "layers" as const, label: "Collections" },
    { key: "search", icon: "search" as const, label: "Search" },
    { key: "profile", icon: "mic" as const, label: "Profile" },
  ];
  return (
    <div
      style={{
        position: "absolute",
        bottom: 0,
        left: 0,
        right: 0,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        // On mobile respect the home-indicator safe area; desktop uses fixed 24 px.
        paddingBottom: isNarrow ? "max(env(safe-area-inset-bottom), 16px)" : 24,
        paddingTop: 8,
        background: `linear-gradient(to top, ${t.surface} 60%, transparent)`,
      }}
    >
      <div
        style={{
          display: "inline-flex",
          gap: 0,
          background: "rgba(255,255,255,0.85)",
          backdropFilter: "blur(20px) saturate(180%)",
          WebkitBackdropFilter: "blur(20px) saturate(180%)",
          border: `1px solid ${t.border}`,
          borderRadius: 999,
          padding: "6px 12px",
          boxShadow: "0 8px 32px rgba(19,14,26,0.10), 0 2px 8px rgba(19,14,26,0.06)",
        }}
      >
        {tabs.map((tab) => (
          <div
            key={tab.key}
            style={{
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              gap: 3,
              padding: "6px 20px",
              borderRadius: 999,
              background: active === tab.key ? t.surface2 : "transparent",
              transition: "background 0.2s",
              cursor: "pointer",
            }}
          >
            <Icon
              name={tab.icon}
              size={22}
              color={active === tab.key ? t.ink : t.faint}
              stroke={active === tab.key ? 2 : 1.6}
            />
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Content type icon badge ──

export function TypeBadge({
  contentType,
  size = 28,
}: {
  contentType: string;
  size?: number;
}) {
  const iconMap: Record<string, keyof typeof ICONS> = {
    article: "globe",
    blog: "globe",
    thread: "layers",
    video: "video",
    podcast: "mic",
    announcement: "layers",
    other: "file",
  };
  const icon = iconMap[contentType] ?? "globe";
  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: 8,
        background: t.surface2,
        border: `1px solid ${t.border}`,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        flexShrink: 0,
      }}
    >
      <Icon name={icon} size={size * 0.6} color={t.muted} />
    </div>
  );
}

// ── Pill tab switcher (Nexus / Sources) ──

export function PillTabs({
  tabs,
  active,
  onChange,
  accent = t.plum,
}: {
  tabs: string[];
  active: string;
  onChange: (tab: string) => void;
  accent?: string;
}) {
  return (
    <div
      style={{
        display: "inline-flex",
        gap: 2,
        padding: 3,
        background: t.surface2,
        borderRadius: 999,
        border: `1px solid ${t.hair}`,
      }}
    >
      {tabs.map((tab) => {
        const isActive = active === tab;
        return (
          <Pressable
            key={tab}
            scale={0.95}
            onClick={() => onChange(tab)}
            style={{
              padding: "7px 18px",
              borderRadius: 999,
              fontSize: 14,
              fontWeight: isActive ? 600 : 500,
              letterSpacing: -0.1,
              color: isActive ? (tab === "Nexus" ? accent : t.ink) : t.muted,
              background: isActive ? t.surface : "transparent",
              border: isActive ? `1px solid ${t.border}` : "1px solid transparent",
              boxShadow: isActive ? "0 1px 3px rgba(19,14,26,0.06)" : "none",
              transition: "all 0.18s",
            }}
          >
            {tab}
          </Pressable>
        );
      })}
    </div>
  );
}

// ── Shimmer placeholder ──

export function Shimmer({ width = "70%", height = 13 }: { width?: string | number; height?: number }) {
  return (
    <div
      style={{
        width,
        height,
        borderRadius: 6,
        background: "linear-gradient(90deg, #EDEAF5 25%, #F5F3FB 50%, #EDEAF5 75%)",
        backgroundSize: "800px 100%",
        animation: "nxShimmer 1.6s ease-in-out infinite",
      }}
    />
  );
}

// Export ICONS map for other files that need the type
export type { IconProps };
export { ICONS };
