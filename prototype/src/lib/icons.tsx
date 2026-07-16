"use client";

/**
 * Nexus icon set — thin geometric stroke (1.6px default), 24-grid.
 * Merged from design-handoff landing-kit.jsx LIcon + prototype extras.
 * Matches the hairline aesthetic: round caps/joins, no fills except
 * deliberate solid glyphs (play, video triangle, nexusFill, drag dots).
 */

import React from "react";

type P = {
  fill: "none";
  stroke: string;
  strokeWidth: number;
  strokeLinecap: "round";
  strokeLinejoin: "round";
};

const strokeProps = (p: P) => ({
  fill: p.fill,
  stroke: p.stroke,
  strokeWidth: p.strokeWidth,
  strokeLinecap: p.strokeLinecap,
  strokeLinejoin: p.strokeLinejoin,
});

export const ICONS = {
  search: (p: P) => (
    <>
      <circle cx="11" cy="11" r="7" {...strokeProps(p)} />
      <path d="m20 20-3.4-3.4" {...strokeProps(p)} />
    </>
  ),
  plus: (p: P) => <path d="M12 5v14M5 12h14" {...strokeProps(p)} />,
  mic: (p: P) => (
    <>
      <rect x="9" y="3" width="6" height="12" rx="3" {...strokeProps(p)} />
      <path d="M5 11a7 7 0 0 0 14 0M12 18v3" {...strokeProps(p)} />
    </>
  ),
  sliders: (p: P) => (
    <>
      <path d="M4 7h9m4 0h3M4 17h3m4 0h9" {...strokeProps(p)} />
      <circle cx="15" cy="7" r="2.2" {...strokeProps(p)} />
      <circle cx="9" cy="17" r="2.2" {...strokeProps(p)} />
    </>
  ),
  chevDown: (p: P) => <path d="m6 9 6 6 6-6" {...strokeProps(p)} />,
  chevLeft: (p: P) => <path d="m15 5-7 7 7 7" {...strokeProps(p)} />,
  chevRight: (p: P) => <path d="m9 5 7 7-7 7" {...strokeProps(p)} />,
  photo: (p: P) => (
    <>
      <rect x="3" y="4" width="18" height="16" rx="3" {...strokeProps(p)} />
      <circle cx="8.5" cy="9.5" r="1.6" {...strokeProps(p)} />
      <path d="m4 17 5-5 4 4 3-3 4 4" {...strokeProps(p)} />
    </>
  ),
  file: (p: P) => (
    <>
      <path d="M7 3h7l4 4v14H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1Z" {...strokeProps(p)} />
      <path d="M14 3v4h4" {...strokeProps(p)} />
    </>
  ),
  camera: (p: P) => (
    <>
      <path
        d="M4 8a2 2 0 0 1 2-2h1.5l1.2-1.6a1 1 0 0 1 .8-.4h5a1 1 0 0 1 .8.4L17.5 6H19a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2Z"
        {...strokeProps(p)}
      />
      <circle cx="12" cy="12.5" r="3.4" {...strokeProps(p)} />
    </>
  ),
  link: (p: P) => (
    <>
      <path d="M9.5 14.5 14.5 9.5" {...strokeProps(p)} />
      <path d="M8 11 6 13a3.5 3.5 0 0 0 5 5l2-2" {...strokeProps(p)} />
      <path d="M16 13l2-2a3.5 3.5 0 0 0-5-5l-2 2" {...strokeProps(p)} />
    </>
  ),
  globe: (p: P) => (
    <>
      <circle cx="12" cy="12" r="9" {...strokeProps(p)} />
      <path d="M3 12h18" {...strokeProps(p)} />
      <path d="M12 3C8 5 8 19 12 21M12 3C16 5 16 19 12 21" {...strokeProps(p)} />
    </>
  ),
  video: (p: P) => (
    <>
      <rect x="3" y="5.5" width="18" height="13" rx="3.5" {...strokeProps(p)} />
      <path
        d="M10.5 9.3v5.4l4.4-2.7-4.4-2.7Z"
        fill={p.stroke}
        stroke={p.stroke}
        strokeWidth="1.2"
        strokeLinejoin="round"
      />
    </>
  ),
  note: (p: P) => (
    <>
      <path d="M5 4h11l3 3v13H5Z" {...strokeProps(p)} />
      <path d="M8 10h8M8 14h6" {...strokeProps(p)} />
    </>
  ),
  layers: (p: P) => (
    <>
      <path d="M12 3 21 8l-9 5-9-5 9-5Z" {...strokeProps(p)} />
      <path d="M3 13l9 5 9-5" {...strokeProps(p)} />
    </>
  ),
  layersFill: (p: P) => (
    <>
      <path d="M12 3 21 8l-9 5-9-5 9-5Z" fill={p.stroke} stroke={p.stroke} strokeWidth="1.4" strokeLinejoin="round" />
      <path d="M3 13l9 5 9-5" {...strokeProps(p)} />
    </>
  ),
  folder: (p: P) => (
    <path d="M3 7a1 1 0 0 1 1-1h5l2 2h8a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1Z" {...strokeProps(p)} />
  ),
  grid: (p: P) => (
    <>
      <rect x="4" y="4" width="7" height="7" rx="1.4" {...strokeProps(p)} />
      <rect x="13" y="4" width="7" height="7" rx="1.4" {...strokeProps(p)} />
      <rect x="4" y="13" width="7" height="7" rx="1.4" {...strokeProps(p)} />
      <rect x="13" y="13" width="7" height="7" rx="1.4" {...strokeProps(p)} />
    </>
  ),
  clock: (p: P) => (
    <>
      <circle cx="12" cy="12" r="9" {...strokeProps(p)} />
      <path d="M12 7v5l3 2" {...strokeProps(p)} />
    </>
  ),
  check: (p: P) => <path d="m5 12.5 4.5 4.5L19 7" {...strokeProps(p)} />,
  quiz: (p: P) => (
    <>
      <path d="M4.5 6.5 6 8l2.5-3" {...strokeProps(p)} />
      <path d="M12.5 7H20" {...strokeProps(p)} />
      <path d="M4.5 15.5 6 17l2.5-3" {...strokeProps(p)} />
      <path d="M12.5 16H20" {...strokeProps(p)} />
    </>
  ),
  play: (p: P) => (
    <path d="M8 5.5v13l11-6.5-11-6.5Z" fill={p.stroke} stroke={p.stroke} strokeWidth="1.4" strokeLinejoin="round" />
  ),
  sparkle: (p: P) => (
    <path d="M12 3.2c.4 6 2.6 8.2 8.6 8.6-6 .4-8.2 2.6-8.6 8.6-.4-6-2.6-8.2-8.6-8.6 6-.4 8.2-2.6 8.6-8.6Z" {...strokeProps(p)} />
  ),
  nexus: (p: P) => (
    <>
      <g {...strokeProps(p)}>
        <path d="M9.25 8 A5.5 5.5 0 0 0 9.25 16" />
        <path d="M14.75 8 A5.5 5.5 0 0 1 14.75 16" />
      </g>
      <g {...strokeProps(p)} opacity={0.35}>
        <path d="M6.75 4.75 A8.75 8.75 0 0 0 6.75 19.25" />
        <path d="M17.25 4.75 A8.75 8.75 0 0 1 17.25 19.25" />
      </g>
      <circle cx="12" cy="12" r="2.3" fill={p.stroke} stroke="none" />
    </>
  ),
  nexusFill: (p: P) => (
    <>
      <g stroke={p.stroke} strokeWidth="2.1" strokeLinecap="round" fill="none">
        <path d="M9.25 8 A5.5 5.5 0 0 0 9.25 16" />
        <path d="M14.75 8 A5.5 5.5 0 0 1 14.75 16" />
      </g>
      <g stroke={p.stroke} strokeWidth="1.7" strokeLinecap="round" fill="none" opacity={0.5}>
        <path d="M6.75 4.75 A8.75 8.75 0 0 0 6.75 19.25" />
        <path d="M17.25 4.75 A8.75 8.75 0 0 1 17.25 19.25" />
      </g>
      <circle cx="12" cy="12" r="3" fill={p.stroke} stroke="none" />
    </>
  ),
  book: (p: P) => (
    <>
      <path d="M5 4.5A2 2 0 0 1 7 3h11v15H7a2 2 0 0 0-2 2Z" {...strokeProps(p)} />
      <path d="M5 18.5A2 2 0 0 0 7 21h11" {...strokeProps(p)} />
    </>
  ),
  arrowUp: (p: P) => <path d="M12 19V5m-6 6 6-6 6 6" {...strokeProps(p)} />,
  trash: (p: P) => (
    <>
      <path d="M4 7h16M10 11v6M14 11v6" {...strokeProps(p)} />
      <path d="M6 7l1 12a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-12M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2" {...strokeProps(p)} />
    </>
  ),
  send: (p: P) => <path d="M12 19V5m-6 6 6-6 6 6" {...strokeProps(p)} />,
  trending: (p: P) => (
    <>
      <path d="M22 7L13.5 15.5L8.5 10.5L2 17" {...strokeProps(p)} />
      <path d="M16 7h6v6" {...strokeProps(p)} />
    </>
  ),
  x: (p: P) => <path d="M6 6l12 12M18 6 6 18" {...strokeProps(p)} />,
  drag: (p: P) => (
    <>
      {([[9, 6], [15, 6], [9, 12], [15, 12], [9, 18], [15, 18]] as [number, number][]).map(([cx, cy], i) => (
        <circle key={i} cx={cx} cy={cy} r="1.3" fill={p.stroke} stroke="none" />
      ))}
    </>
  ),
  waveform: (p: P) => (
    <>
      {([[5, 8], [9.5, 15], [14, 7], [18.5, 12]] as [number, number][]).map(([x, h], i) => (
        <rect key={i} x={x - 1.4} y={12 - h / 2} width={2.8} height={h} rx={1.4} fill={p.stroke} stroke="none" />
      ))}
    </>
  ),
  compose: (p: P) => (
    <>
      <path d="M20 12.5V19a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h6.5" {...strokeProps(p)} />
      <path d="M17.7 3.6a2.05 2.05 0 0 1 2.9 2.9L12 15.1l-3.8.9.9-3.8 8.6-8.6Z" {...strokeProps(p)} />
    </>
  ),
  composeFill: (p: P) => (
    <>
      <path d="M20 12.5V19a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h6.5" {...strokeProps(p)} />
      <path
        d="M17.7 3.6a2.05 2.05 0 0 1 2.9 2.9L12 15.1l-3.8.9.9-3.8 8.6-8.6Z"
        fill={p.stroke}
        stroke={p.stroke}
        strokeWidth="1.2"
        strokeLinejoin="round"
      />
    </>
  ),
  envelope: (p: P) => (
    <>
      <rect x="3" y="5" width="18" height="14" rx="2.5" {...strokeProps(p)} />
      <path d="m4 7 8 6 8-6" {...strokeProps(p)} />
    </>
  ),
  apple: (p: P) => (
    <path
      d="M16.7 12.9c0-2 1.6-3 1.7-3-1-1.4-2.4-1.6-2.9-1.6-1.2-.1-2.4.7-3 .7-.6 0-1.6-.7-2.6-.7-1.3 0-2.6.8-3.3 2-1.4 2.4-.4 6 1 8 .7 1 1.5 2.1 2.5 2 1 0 1.4-.6 2.6-.6 1.2 0 1.5.6 2.6.6 1.1 0 1.8-1 2.5-2 .8-1.1 1.1-2.2 1.1-2.3 0 0-2.1-.8-2.2-3.1ZM14.7 6.7c.5-.7.9-1.6.8-2.6-.8 0-1.8.6-2.3 1.2-.5.6-1 1.6-.8 2.5.9.1 1.8-.4 2.3-1.1Z"
      fill={p.stroke}
      stroke="none"
    />
  ),
} as const;

export type IconName = keyof typeof ICONS;

export function Icon({
  name,
  size = 22,
  color = "currentColor",
  stroke = 1.6,
}: {
  name: IconName;
  size?: number;
  color?: string;
  stroke?: number;
}) {
  const p: P = {
    fill: "none",
    stroke: color,
    strokeWidth: stroke,
    strokeLinecap: "round",
    strokeLinejoin: "round",
  };
  const Shape = ICONS[name];
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" style={{ flex: "0 0 auto", display: "block" }}>
      {Shape(p)}
    </svg>
  );
}
