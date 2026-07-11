"use client";

/**
 * Bottom floating Liquid Glass tab capsule (Photos-style) — ported from
 * collection-view.jsx TabCapsule/Segmented. The glass thumb springs between
 * tabs on the true-spring linear() easing.
 */

import React, { useEffect, useRef, useState } from "react";
import { Icon, IconName } from "../../../lib/icons";
import { LiquidGlassCard } from "../../../lib/surfaces";
import { t, tokens } from "../../../lib/tokens";

export interface CapsuleTab {
  key: string;
  label: string;
  icon: IconName;
  iconSelected: IconName;
}

export function TabCapsule({
  tabs,
  active,
  onChange,
}: {
  tabs: CapsuleTab[];
  active: string;
  onChange: (key: string) => void;
}) {
  const idx = Math.max(0, tabs.findIndex((tab) => tab.key === active));
  const refs = useRef<(HTMLButtonElement | null)[]>([]);
  const [thumb, setThumb] = useState<{ left: number; width: number } | null>(null);

  useEffect(() => {
    const el = refs.current[idx];
    if (el) setThumb({ left: el.offsetLeft, width: el.offsetWidth });
  }, [idx, tabs.map((tab) => tab.key).join("|")]); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <LiquidGlassCard radius={999}>
      <div style={{ display: "flex", gap: 2, padding: 3, position: "relative" }}>
        {thumb && (
          // Outer layer glides (left/width on the true spring); inner visual
          // layer remounts per selection to replay the water-bubble squash —
          // the two must be separate elements or the remount kills the glide.
          <div
            style={{
              position: "absolute",
              top: 3,
              bottom: 3,
              left: thumb.left,
              width: thumb.width,
              transition: `left .52s ${tokens.motion.springLinear}, width .52s ${tokens.motion.springLinear}`,
              pointerEvents: "none",
            }}
          >
            <div
              key={idx}
              style={{
                position: "absolute",
                inset: 0,
                borderRadius: tokens.radius.full,
                background: "rgba(255,255,255,0.66)",
                boxShadow:
                  "inset 0 0 0 1px rgba(255,255,255,0.85), inset 0 1.5px 1px rgba(255,255,255,0.95), inset -2px -3px 6px rgba(150,170,255,0.14), inset 2px 3px 6px rgba(255,150,205,0.10), 0 5px 16px rgba(19,14,26,0.18)",
                animation: "nxBubble .56s cubic-bezier(.2,.8,.2,1)",
              }}
            />
          </div>
        )}
        {tabs.map((tab, i) => {
          const selected = active === tab.key;
          const tint = selected ? t.plum : t.muted;
          return (
            <button
              key={tab.key}
              ref={(el) => {
                refs.current[i] = el;
              }}
              onClick={() => onChange(tab.key)}
              style={{
                position: "relative",
                zIndex: 1,
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                gap: 2,
                padding: "6px 26px 5px",
                borderRadius: tokens.radius.full,
                background: "transparent",
                border: "none",
                cursor: "pointer",
                WebkitTapHighlightColor: "transparent",
              }}
            >
              <Icon name={selected ? tab.iconSelected : tab.icon} size={23} color={tint} stroke={1.7} />
              <span
                style={{
                  fontSize: 10.5,
                  fontWeight: 600,
                  letterSpacing: -0.1,
                  color: tint,
                  transition: "color .25s ease",
                }}
              >
                {tab.label}
              </span>
            </button>
          );
        })}
      </div>
    </LiquidGlassCard>
  );
}
