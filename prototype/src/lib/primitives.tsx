"use client";

/**
 * Nexus primitives — every inline control on a surface.
 * Ported/merged from design-handoff landing-kit.jsx + landing-app.jsx and the
 * previous components.tsx. All values via tokens (fidelity contract).
 *
 * Material model: inline controls = solid fill + hairline border (no glass).
 */

import React, { useEffect, useRef, useState } from "react";
import { Icon, IconName } from "./icons";
import { t, tokens } from "./tokens";

// ── Responsive breakpoint hook — <640px = real-phone mode ──

export function useIsNarrow(): boolean {
  const [narrow, setNarrow] = useState(false);
  useEffect(() => {
    const mq = window.matchMedia("(max-width: 639px)");
    const handler = (e: MediaQueryListEvent) => setNarrow(e.matches);
    setNarrow(mq.matches);
    mq.addEventListener("change", handler);
    return () => mq.removeEventListener("change", handler);
  }, []);
  return narrow;
}

// ── Press-spring wrapper — every tappable ──
// `active` holds the pressed state (e.g. avatar dented while its menu is open);
// pressDur/pressEase let a control opt into a bouncier release.

export function Pressable({
  scale = 0.95,
  active = false,
  stop = false,
  pressDur = 0.24,
  pressEase = tokens.motion.spring,
  onClick,
  style,
  children,
  className,
  ...rest
}: React.ButtonHTMLAttributes<HTMLButtonElement> & {
  scale?: number;
  active?: boolean;
  stop?: boolean;
  pressDur?: number;
  pressEase?: string;
  children: React.ReactNode;
}) {
  const [down, setDown] = useState(false);
  const end = () => setDown(false);
  const pressed = down || active;
  return (
    <button
      {...rest}
      onPointerDown={() => setDown(true)}
      onPointerUp={end}
      onPointerLeave={end}
      onPointerCancel={end}
      onClick={(e) => {
        if (stop) e.stopPropagation();
        onClick?.(e);
      }}
      style={{
        border: "none",
        padding: 0,
        background: "transparent",
        cursor: "pointer",
        ...style,
        transform: `scale(${pressed ? scale : 1})${style?.transform ? " " + style.transform : ""}`,
        transition: `transform ${pressDur}s ${pressEase}`,
        WebkitTapHighlightColor: "transparent",
        touchAction: "manipulation",
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
  label,
}: {
  name: IconName;
  size?: number;
  iconSize?: number;
  color?: string;
  onClick?: () => void;
  style?: React.CSSProperties;
  label?: string;
}) {
  return (
    <Pressable
      onClick={onClick}
      aria-label={label ?? name}
      style={{
        width: size,
        height: size,
        borderRadius: tokens.radius.full,
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
  ring = false,
}: {
  initials?: string;
  size?: number;
  ring?: boolean;
}) {
  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: tokens.radius.full,
        flexShrink: 0,
        background: t.surface,
        border: `1px solid ${ring ? t.ink : t.borderStrong}`,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        fontSize: size * 0.4,
        fontWeight: 600,
        letterSpacing: -0.2,
        color: t.ink,
        boxShadow: ring ? `0 0 0 3px ${t.surface2}` : "none",
      }}
    >
      {initials}
    </div>
  );
}

// ── Avatar button — presses smaller then springs bigger, spitting out the
// menu; replays the bounce when the menu is absorbed (active → false) ──

export function AvatarButton({
  initials = "S",
  size = 36,
  active = false,
  onClick,
}: {
  initials?: string;
  size?: number;
  active?: boolean;
  onClick?: () => void;
}) {
  const [pop, setPop] = useState(0);
  const prev = useRef(active);
  useEffect(() => {
    if (prev.current && !active) setPop((n) => n + 1);
    prev.current = active;
  }, [active]);
  return (
    <Pressable
      scale={0.84}
      pressDur={0.44}
      onClick={onClick}
      aria-label="Account menu"
      style={{ borderRadius: tokens.radius.full }}
    >
      <div
        key={pop}
        style={{
          opacity: active ? 0 : 1,
          transition: active ? "opacity .05s ease" : "opacity .22s ease .04s",
          animation: pop ? "nxPop .44s ease both" : "none",
        }}
      >
        <Avatar initials={initials} size={size} />
      </div>
    </Pressable>
  );
}

// ── Sliding-thumb segmented control ──

export function Segmented({
  items,
  value,
  onChange,
  compact = false,
}: {
  items: string[];
  value: string;
  onChange: (v: string) => void;
  compact?: boolean;
}) {
  const idx = Math.max(0, items.indexOf(value));
  const refs = useRef<(HTMLSpanElement | null)[]>([]);
  const [thumb, setThumb] = useState<{ left: number; width: number } | null>(null);
  useEffect(() => {
    const el = refs.current[idx];
    if (el) setThumb({ left: el.offsetLeft, width: el.offsetWidth });
  }, [idx, items.join("|")]); // eslint-disable-line react-hooks/exhaustive-deps
  return (
    <div
      style={{
        display: "inline-flex",
        position: "relative",
        gap: 2,
        padding: 3,
        background: t.surface2,
        borderRadius: tokens.radius.full,
        border: `1px solid ${t.hair}`,
      }}
    >
      {thumb && (
        <div
          style={{
            position: "absolute",
            top: 3,
            bottom: 3,
            left: thumb.left,
            width: thumb.width,
            borderRadius: tokens.radius.full,
            background: t.surface,
            border: `1px solid ${t.border}`,
            boxShadow: tokens.shadow.xs,
            transition: `left .52s ${tokens.motion.springLinear}, width .52s ${tokens.motion.springLinear}`,
          }}
        />
      )}
      {items.map((item, i) => (
        <span
          key={item}
          ref={(el) => {
            refs.current[i] = el;
          }}
          onClick={() => onChange(item)}
          style={{
            position: "relative",
            zIndex: 1,
            fontSize: compact ? 12.5 : 13,
            fontWeight: value === item ? 600 : 500,
            letterSpacing: -0.1,
            padding: compact ? "5px 11px" : "6px 13px",
            borderRadius: tokens.radius.full,
            color: value === item ? t.text : t.muted,
            cursor: "pointer",
            WebkitTapHighlightColor: "transparent",
            transition: "color .15s",
            userSelect: "none",
          }}
        >
          {item}
        </span>
      ))}
    </div>
  );
}

// ── Pill tab switcher (kept for existing pages) ──

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
        borderRadius: tokens.radius.full,
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
              borderRadius: tokens.radius.full,
              fontSize: 14,
              fontWeight: isActive ? 600 : 500,
              letterSpacing: -0.1,
              color: isActive ? (tab === "Nexus" ? accent : t.ink) : t.muted,
              background: isActive ? t.surface : "transparent",
              border: isActive ? `1px solid ${t.border}` : "1px solid transparent",
              boxShadow: isActive ? tokens.shadow.xs : "none",
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

export function Shimmer({
  width = "70%",
  height = 13,
  radius = 6,
}: {
  width?: string | number;
  height?: number;
  radius?: number;
}) {
  return (
    <div
      style={{
        width,
        height,
        borderRadius: radius,
        background: `linear-gradient(90deg, ${tokens.color.shimmerA} 25%, ${tokens.color.shimmerB} 50%, ${tokens.color.shimmerA} 75%)`,
        backgroundSize: "800px 100%",
        animation: "nxShimmer 1.6s ease-in-out infinite",
      }}
    />
  );
}

// ── Spinner — 16px plum-tinted (FRE loading spec) ──

export function Spinner({ size = 16, color = t.plum }: { size?: number; color?: string }) {
  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: tokens.radius.full,
        border: `2px solid ${tokens.color.bloom}`,
        borderTopColor: color,
        animation: "nxSpin 0.75s linear infinite",
        flexShrink: 0,
      }}
    />
  );
}

// ── Screen scaffold with the paged bloom background ──

export function Screen({ children, style }: { children: React.ReactNode; style?: React.CSSProperties }) {
  return (
    <div
      style={{
        minHeight: "100%",
        height: "100%",
        background: t.page,
        fontFamily: tokens.font.ui,
        color: t.text,
        display: "flex",
        flexDirection: "column",
        position: "relative",
        overflow: "hidden",
        ...style,
      }}
    >
      {children}
    </div>
  );
}

// ── iOS status bar / safe-area spacer ──

export function StatusBar() {
  const isNarrow = useIsNarrow();
  if (isNarrow) {
    return <div style={{ flexShrink: 0, paddingTop: "max(env(safe-area-inset-top), 20px)" }} />;
  }
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
      <span style={{ fontSize: 15, fontWeight: 600, color: t.ink, letterSpacing: -0.3 }}>9:41</span>
      <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
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
        <svg width={25} height={12} viewBox="0 0 25 12">
          <rect x={0.5} y={0.5} width={21} height={11} rx={3} stroke={t.ink} strokeWidth={1} fill="none" />
          <rect x={22} y={3.5} width={2.5} height={5} rx={1.5} fill={t.ink} />
          <rect x={2} y={2} width={14} height={8} rx={2} fill={t.ink} />
        </svg>
      </div>
    </div>
  );
}

// ── Mobile frame wrapper — real viewport on phones, 390×844 mockup on desktop ──

export function MobileFrame({ children }: { children: React.ReactNode }) {
  const isNarrow = useIsNarrow();
  if (isNarrow) {
    return (
      <div
        style={{
          width: "100%",
          height: "100dvh",
          background: t.surface,
          fontFamily: tokens.font.ui,
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
  return (
    <div
      style={{
        minHeight: "100vh",
        background: tokens.color.canvasDesktop,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: 28,
        fontFamily: tokens.font.ui,
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

// ── Content type icon badge ──

export function TypeBadge({ contentType, size = 28 }: { contentType: string; size?: number }) {
  const iconMap: Record<string, IconName> = {
    article: "globe",
    blog: "globe",
    thread: "layers",
    video: "video",
    youtube: "video",
    podcast: "mic",
    pdf: "file",
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
