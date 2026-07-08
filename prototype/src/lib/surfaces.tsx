"use client";

/**
 * Nexus floating surfaces — everything that lifts above the page.
 * Ported from design-handoff landing-app.jsx (LiquidGlassCard, BloomMenu,
 * MenuOverlay, usePresence), fre-flow.jsx (Sheet), collection-view.jsx
 * (EchoPulse).
 *
 * Material model: floating layers = Liquid Glass. Inline stays solid.
 */

import React, { useEffect, useState } from "react";
import { t, tokens } from "./tokens";

// ── enter/exit presence (mount → animate in; animate out → unmount) ──

export function usePresence(open: boolean, ms = 220) {
  const [mounted, setMounted] = useState(open);
  const [active, setActive] = useState(false);
  useEffect(() => {
    let raf1: number, raf2: number, to: ReturnType<typeof setTimeout>;
    if (open) {
      setMounted(true);
      raf1 = requestAnimationFrame(() => {
        raf2 = requestAnimationFrame(() => setActive(true));
      });
    } else {
      setActive(false);
      to = setTimeout(() => setMounted(false), ms);
    }
    return () => {
      cancelAnimationFrame(raf1);
      cancelAnimationFrame(raf2);
      clearTimeout(to);
    };
  }, [open, ms]);
  return { mounted, active };
}

// ── Liquid Glass card — 5 layers: blur, tint+gloss, lens fringe, rim, content ──

export function LiquidGlassCard({
  radius = 26,
  width,
  children,
}: {
  radius?: number;
  width?: number | string;
  children: React.ReactNode;
}) {
  const layer: React.CSSProperties = {
    position: "absolute",
    inset: 0,
    borderRadius: radius,
    pointerEvents: "none",
  };
  return (
    <div
      style={{
        position: "relative",
        width,
        borderRadius: radius,
        isolation: "isolate",
        boxShadow: "0 22px 58px rgba(19,14,26,0.22), 0 6px 18px rgba(19,14,26,0.13)",
      }}
    >
      <div
        style={{
          ...layer,
          overflow: "hidden",
          backdropFilter: "blur(8px) saturate(195%) brightness(1.05)",
          WebkitBackdropFilter: "blur(8px) saturate(195%) brightness(1.05)",
        }}
      />
      <div
        style={{
          ...layer,
          background:
            "linear-gradient(135deg, rgba(255,255,255,0.42) 0%, rgba(255,255,255,0.10) 30%, rgba(255,255,255,0.03) 54%, rgba(255,255,255,0.13) 78%, rgba(255,255,255,0.36) 100%)",
        }}
      />
      <div
        style={{
          ...layer,
          boxShadow:
            "inset 0 0 0 1px rgba(255,255,255,0.4), inset 3px 3px 8px rgba(255,255,255,0.5), inset -5px -6px 12px rgba(150,170,255,0.16), inset 5px 6px 13px rgba(255,150,205,0.11)",
        }}
      />
      <div
        style={{
          ...layer,
          boxShadow:
            "inset 1.6px 1.6px 1px rgba(255,255,255,0.95), inset -1.4px -1.4px 2px rgba(255,255,255,0.5), inset 0 0 16px rgba(255,255,255,0.18)",
        }}
      />
      <div style={{ position: "relative", zIndex: 1 }}>{children}</div>
    </div>
  );
}

// ── Bloom-morph menu — springs OUT of its anchor (scale .12 → 1 on a true
// spring); content fades in after the surface arrives; close is absorbed
// back with a quick ease-in collapse ──

export function BloomMenu({
  open,
  onClose,
  anchor,
  origin,
  children,
}: {
  open: boolean;
  onClose: () => void;
  anchor: React.CSSProperties;
  origin: string;
  children: React.ReactNode;
}) {
  const p = usePresence(open, 480);
  if (!p.mounted) return null;
  const on = p.active;
  return (
    <>
      <div onClick={onClose} style={{ position: "absolute", inset: 0, zIndex: 60, background: "transparent" }} />
      <div
        style={{
          position: "absolute",
          zIndex: 61,
          transformOrigin: origin,
          transform: on ? "scale(1)" : "scale(0.12)",
          opacity: on ? 1 : 0,
          transition: on
            ? `transform .46s ${tokens.motion.springLinear}, opacity .2s ease`
            : `transform .26s cubic-bezier(.4,0,.9,.35), opacity .22s ease .03s`,
          ...anchor,
        }}
      >
        <div
          style={{
            opacity: on ? 1 : 0,
            transform: on ? "translateY(0)" : "translateY(6px)",
            transition: on ? "opacity .24s ease .1s, transform .3s ease .08s" : "opacity .12s ease",
          }}
        >
          {children}
        </div>
      </div>
    </>
  );
}

// ── Menu overlay — scrim + origin-anchored popover (non-bloom menus) ──

export function MenuOverlay({
  open,
  onClose,
  anchor,
  origin,
  enterY = -6,
  startScale = 0.95,
  dur = 0.2,
  opDur = 0.16,
  scrimBlur = false,
  children,
}: {
  open: boolean;
  onClose: () => void;
  anchor: React.CSSProperties;
  origin: string;
  enterY?: number;
  startScale?: number;
  dur?: number;
  opDur?: number;
  scrimBlur?: boolean;
  children: React.ReactNode;
}) {
  const p = usePresence(open, Math.round(Math.max(dur, opDur) * 1000) + 40);
  if (!p.mounted) return null;
  return (
    <>
      <div
        onClick={onClose}
        style={{
          position: "absolute",
          inset: 0,
          background: "rgba(19,14,26,0.18)",
          backdropFilter: scrimBlur ? "blur(2px)" : "none",
          WebkitBackdropFilter: scrimBlur ? "blur(2px)" : "none",
          opacity: p.active ? 1 : 0,
          transition: `opacity ${opDur}s ease`,
          zIndex: 60,
        }}
      />
      <div
        style={{
          position: "absolute",
          zIndex: 61,
          transformOrigin: origin,
          transform: p.active ? "scale(1) translateY(0)" : `scale(${startScale}) translateY(${enterY}px)`,
          opacity: p.active ? 1 : 0,
          transition: `transform ${dur}s ${tokens.motion.spring}, opacity ${opDur}s ease`,
          ...anchor,
        }}
      >
        {children}
      </div>
    </>
  );
}

// ── Bottom sheet — rises to ~90% cover (FRE / add-source grammar) ──

export function Sheet({
  open,
  onClose,
  cover = 0.905,
  children,
}: {
  open: boolean;
  onClose?: () => void;
  cover?: number;
  children: React.ReactNode;
}) {
  const p = usePresence(open, 540);
  if (!p.mounted) return null;
  const on = p.active;
  return (
    <>
      <div
        onClick={onClose}
        style={{
          position: "absolute",
          inset: 0,
          background: tokens.color.overlay,
          opacity: on ? 0.55 : 0,
          transition: "opacity .3s ease",
          zIndex: 70,
        }}
      />
      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          bottom: 0,
          top: `${(1 - cover) * 100}%`,
          zIndex: 71,
          background: t.surface,
          borderRadius: "22px 22px 0 0",
          boxShadow: tokens.shadow.sheet,
          transform: on ? "translateY(0)" : "translateY(104%)",
          transition: on ? `transform .52s ${tokens.motion.snappy}` : `transform .34s cubic-bezier(.4,0,.9,.35)`,
          display: "flex",
          flexDirection: "column",
          overflow: "hidden",
        }}
      >
        {/* grabber */}
        <div style={{ display: "flex", justifyContent: "center", padding: "9px 0 0", flexShrink: 0 }}>
          <div style={{ width: 38, height: 4.5, borderRadius: tokens.radius.full, background: t.hair }} />
        </div>
        {children}
      </div>
    </>
  );
}

// ── EchoPulse — the wait state: brand mark broadcasting; arc pairs ripple
// outward from the breathing node ──

export function EchoPulse({ size = 36 }: { size?: number }) {
  const ring = (delay: number) => (
    <g
      style={{ transformOrigin: "24px 24px", animation: `nxEcho 1.7s ${delay}s cubic-bezier(.2,.6,.4,1) infinite` }}
      stroke={t.plum}
      strokeWidth="3"
      strokeLinecap="round"
      fill="none"
    >
      <path d="M18.5 16 A11 11 0 0 0 18.5 32" />
      <path d="M29.5 16 A11 11 0 0 1 29.5 32" />
    </g>
  );
  return (
    <div style={{ padding: "12px 0" }}>
      <svg width={size} height={size} viewBox="0 0 48 48">
        <circle
          cx="24"
          cy="24"
          r="4.4"
          fill={t.plum}
          style={{ animation: "nxNodeBreathe 1.7s ease-in-out infinite" }}
        />
        {ring(0)}
        {ring(0.85)}
      </svg>
    </div>
  );
}

// ── PivotSwipe — horizontal pane slide synced with a tab thumb ──

export function PivotSwipe({
  index,
  children,
}: {
  index: number;
  children: React.ReactNode[];
}) {
  return (
    <div style={{ flex: 1, minHeight: 0, overflow: "hidden", position: "relative" }}>
      <div
        style={{
          display: "flex",
          height: "100%",
          width: `${children.length * 100}%`,
          transform: `translateX(-${(index * 100) / children.length}%)`,
          transition: `transform ${tokens.motion.pivot}`,
        }}
      >
        {children.map((pane, i) => (
          <div key={i} style={{ width: `${100 / children.length}%`, height: "100%", overflow: "hidden" }}>
            {pane}
          </div>
        ))}
      </div>
    </div>
  );
}
