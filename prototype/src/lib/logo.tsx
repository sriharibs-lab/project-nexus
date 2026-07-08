"use client";

/**
 * Nexus brand — the Echo mark + wordmark lockup.
 * Ported from design-handoff logo.jsx.
 * Two facing arcs hold a single point of contact; a lighter pair radiates
 * outward. Strictly monochrome (in-hue opacity only).
 *
 * Wordmark note: the handoff specced Geist 600 for the wordmark, but the
 * native app renders it in the system font — the prototype matches the APP
 * (fidelity contract), so system stack here too.
 */

import React from "react";
import { t, tokens } from "./tokens";

export function EchoMark({ color = t.plum, size = 48 }: { color?: string; size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 48 48" style={{ display: "block", flex: "0 0 auto" }}>
      <g stroke={color} strokeWidth="3" strokeLinecap="round" fill="none">
        <path d="M18.5 16 A11 11 0 0 0 18.5 32" />
        <path d="M29.5 16 A11 11 0 0 1 29.5 32" />
      </g>
      <g stroke={color} strokeWidth="2.2" strokeLinecap="round" fill="none" opacity="0.32">
        <path d="M13.5 9.5 A17.5 17.5 0 0 0 13.5 38.5" />
        <path d="M34.5 9.5 A17.5 17.5 0 0 1 34.5 38.5" />
      </g>
      <circle cx="24" cy="24" r="4.4" fill={color} />
    </svg>
  );
}

export function NexusLockup({
  color = t.plum,
  wordColor,
  iconSize = 38,
  fontSize = 30,
}: {
  color?: string;
  wordColor?: string;
  iconSize?: number;
  fontSize?: number;
}) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: Math.round(iconSize * 0.36) }}>
      <EchoMark color={color} size={iconSize} />
      <span
        style={{
          fontFamily: tokens.font.display,
          fontSize,
          fontWeight: 600,
          letterSpacing: "-0.035em",
          color: wordColor || color,
          lineHeight: 1,
        }}
      >
        Nexus
      </span>
    </div>
  );
}
