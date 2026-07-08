"use client";

/**
 * Design Tokens reference — renders the LIVE values from tokens.css by
 * reading computed custom properties off :root. Nothing here is hardcoded:
 * change a token in tokens.css and this page (and every flow) updates.
 * Tap any row to copy "--token-name · value" for precise design feedback.
 */

import React, { useEffect, useState } from "react";
import { Icon } from "../../../lib/icons";
import { ICONS, IconName } from "../../../lib/icons";
import { EchoMark, NexusLockup } from "../../../lib/logo";
import { Pressable, Screen, Spinner, StatusBar } from "../../../lib/primitives";
import { EchoPulse } from "../../../lib/surfaces";
import { t, tokens } from "../../../lib/tokens";

// ── token groups to display (name → CSS custom property) ──

const COLOR_GROUPS: Array<{ title: string; items: Array<[string, string]> }> = [
  {
    title: "Brand",
    items: [
      ["Plum (accent)", "--nx-color-brand-plum"],
      ["Bloom", "--nx-color-brand-bloom"],
    ],
  },
  {
    title: "Text",
    items: [
      ["Ink (primary)", "--nx-color-text-primary"],
      ["Muted (secondary)", "--nx-color-text-secondary"],
      ["Faint (tertiary)", "--nx-color-text-tertiary"],
      ["Ghost (disabled)", "--nx-color-text-disabled"],
    ],
  },
  {
    title: "Background",
    items: [
      ["Surface", "--nx-color-bg-primary"],
      ["Surface 2", "--nx-color-bg-secondary"],
      ["Surface 3 (elevated)", "--nx-color-bg-elevated"],
    ],
  },
  {
    title: "Border",
    items: [
      ["Border", "--nx-color-border-default"],
      ["Border strong", "--nx-color-border-strong"],
      ["Hairline", "--nx-color-border-subtle"],
    ],
  },
  {
    title: "Status",
    items: [
      ["Success", "--nx-color-status-success"],
      ["Warning", "--nx-color-status-warning"],
      ["Error", "--nx-color-status-error"],
    ],
  },
];

const TYPE_SCALE: Array<{ label: string; varName: string; weight: number; tracking: string }> = [
  { label: "Display", varName: "--nx-text-7xl", weight: 700, tracking: "-0.8px" },
  { label: "Title", varName: "--nx-text-5xl", weight: 700, tracking: "-0.5px" },
  { label: "Heading", varName: "--nx-text-3xl", weight: 600, tracking: "-0.4px" },
  { label: "Body large", varName: "--nx-text-xl", weight: 400, tracking: "-0.2px" },
  { label: "Body", varName: "--nx-text-lg", weight: 400, tracking: "-0.1px" },
  { label: "Label", varName: "--nx-text-md", weight: 500, tracking: "-0.1px" },
  { label: "Caption", varName: "--nx-text-sm", weight: 500, tracking: "0" },
  { label: "Overline", varName: "--nx-text-xs", weight: 600, tracking: "0.05em" },
];

const SPACING = ["--nx-space-1", "--nx-space-2", "--nx-space-3", "--nx-space-5", "--nx-space-6", "--nx-space-7", "--nx-space-10", "--nx-space-12", "--nx-space-16"];
const RADII = ["--nx-radius-xs", "--nx-radius-sm", "--nx-radius-base", "--nx-radius-lg", "--nx-radius-xl", "--nx-radius-2xl"];

function useComputedTokens(): (v: string) => string {
  const [, force] = useState(0);
  useEffect(() => force(1), []);
  return (varName: string) => {
    if (typeof window === "undefined") return "";
    return getComputedStyle(document.documentElement).getPropertyValue(varName).trim();
  };
}

function SectionTitle({ children }: { children: React.ReactNode }) {
  return (
    <div
      style={{
        fontSize: 11,
        fontWeight: 700,
        letterSpacing: 0.8,
        textTransform: "uppercase",
        color: t.faint,
        padding: "22px 2px 8px",
      }}
    >
      {children}
    </div>
  );
}

export default function TokensPage() {
  const resolve = useComputedTokens();
  const [copied, setCopied] = useState<string | null>(null);

  const copy = (varName: string, value: string) => {
    navigator.clipboard?.writeText(`${varName} · ${value}`);
    setCopied(varName);
    setTimeout(() => setCopied(null), 1200);
  };

  return (
    <Screen>
      <StatusBar />
      <div style={{ flex: 1, overflowY: "auto", padding: "4px 16px 60px" }}>
        <div style={{ fontSize: 19, fontWeight: 700, letterSpacing: -0.4, color: t.text, padding: "8px 2px 0" }}>
          Design tokens
        </div>
        <div style={{ fontSize: 12, color: t.faint, letterSpacing: -0.1, padding: "3px 2px 0" }}>
          Live values from tokens.css — tap any row to copy its name.
        </div>

        {/* ── Brand ── */}
        <SectionTitle>Brand mark — Echo</SectionTitle>
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 22,
            padding: "16px 14px",
            background: t.surface,
            border: `1px solid ${t.border}`,
            borderRadius: tokens.radius.lg,
          }}
        >
          <EchoMark size={48} />
          <EchoMark size={32} />
          <EchoMark size={22} />
          <EchoMark size={15} />
          <div style={{ flex: 1 }} />
          <NexusLockup iconSize={26} fontSize={20} wordColor={t.text} />
        </div>

        {/* ── Colors ── */}
        {COLOR_GROUPS.map((group) => (
          <div key={group.title}>
            <SectionTitle>Color — {group.title}</SectionTitle>
            <div style={{ background: t.surface, border: `1px solid ${t.border}`, borderRadius: tokens.radius.lg, overflow: "hidden" }}>
              {group.items.map(([label, varName], i) => {
                const value = resolve(varName);
                return (
                  <Pressable
                    key={varName}
                    onClick={() => copy(varName, value)}
                    style={{
                      display: "flex",
                      width: "100%",
                      textAlign: "left",
                      alignItems: "center",
                      gap: 12,
                      padding: "11px 14px",
                      borderTop: i > 0 ? `1px solid ${t.hair}` : "none",
                      borderRadius: 0,
                    }}
                  >
                    <div
                      style={{
                        width: 30,
                        height: 30,
                        borderRadius: 8,
                        background: `var(${varName})`,
                        border: `1px solid ${t.hair}`,
                        flexShrink: 0,
                      }}
                    />
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ fontSize: 14, fontWeight: 500, letterSpacing: -0.1, color: t.text }}>{label}</div>
                      <div style={{ fontSize: 11, color: t.faint, fontFamily: tokens.font.mono }}>{varName}</div>
                    </div>
                    <span style={{ fontSize: 12, fontWeight: 600, color: copied === varName ? t.plum : t.muted, fontFamily: tokens.font.mono }}>
                      {copied === varName ? "copied" : value}
                    </span>
                  </Pressable>
                );
              })}
            </div>
          </div>
        ))}

        {/* ── Typography ── */}
        <SectionTitle>Type scale — system stack (SF Pro on iPhone)</SectionTitle>
        <div style={{ background: t.surface, border: `1px solid ${t.border}`, borderRadius: tokens.radius.lg, overflow: "hidden" }}>
          {TYPE_SCALE.map((row, i) => {
            const size = resolve(row.varName);
            return (
              <Pressable
                key={row.varName}
                onClick={() => copy(row.varName, size)}
                style={{
                  display: "flex",
                  width: "100%",
                  textAlign: "left",
                  alignItems: "baseline",
                  gap: 12,
                  padding: "11px 14px",
                  borderTop: i > 0 ? `1px solid ${t.hair}` : "none",
                  borderRadius: 0,
                }}
              >
                <span
                  style={{
                    fontSize: `var(${row.varName})`,
                    fontWeight: row.weight,
                    letterSpacing: row.tracking,
                    color: t.text,
                    flex: 1,
                    whiteSpace: "nowrap",
                    overflow: "hidden",
                    textOverflow: "ellipsis",
                  }}
                >
                  {row.label}
                </span>
                <span style={{ fontSize: 11, color: copied === row.varName ? t.plum : t.faint, fontFamily: tokens.font.mono, flexShrink: 0 }}>
                  {copied === row.varName ? "copied" : `${size} · ${row.weight}`}
                </span>
              </Pressable>
            );
          })}
        </div>

        {/* ── Spacing ── */}
        <SectionTitle>Spacing</SectionTitle>
        <div style={{ background: t.surface, border: `1px solid ${t.border}`, borderRadius: tokens.radius.lg, padding: "12px 14px", display: "flex", flexDirection: "column", gap: 8 }}>
          {SPACING.map((varName) => {
            const value = resolve(varName);
            return (
              <Pressable key={varName} onClick={() => copy(varName, value)} style={{ display: "flex", width: "100%", alignItems: "center", gap: 10, borderRadius: 0 }}>
                <div style={{ width: `var(${varName})`, height: 14, background: tokens.color.bloom, borderRadius: 3, flexShrink: 0 }} />
                <span style={{ fontSize: 11, color: copied === varName ? t.plum : t.faint, fontFamily: tokens.font.mono }}>
                  {copied === varName ? "copied" : `${varName.replace("--nx-space-", "space-")} · ${value}`}
                </span>
              </Pressable>
            );
          })}
        </div>

        {/* ── Radius ── */}
        <SectionTitle>Border radius</SectionTitle>
        <div style={{ background: t.surface, border: `1px solid ${t.border}`, borderRadius: tokens.radius.lg, padding: "14px", display: "flex", gap: 10, flexWrap: "wrap" }}>
          {RADII.map((varName) => {
            const value = resolve(varName);
            return (
              <Pressable key={varName} onClick={() => copy(varName, value)} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 5, borderRadius: 0 }}>
                <div style={{ width: 46, height: 46, borderRadius: `var(${varName})`, background: t.surface2, border: `1.5px solid ${t.borderStrong}` }} />
                <span style={{ fontSize: 10, color: copied === varName ? t.plum : t.faint, fontFamily: tokens.font.mono }}>
                  {copied === varName ? "copied" : value}
                </span>
              </Pressable>
            );
          })}
        </div>

        {/* ── Motion ── */}
        <SectionTitle>Motion — tap to replay</SectionTitle>
        <MotionDemos />

        {/* ── Loading states ── */}
        <SectionTitle>Wait states</SectionTitle>
        <div style={{ background: t.surface, border: `1px solid ${t.border}`, borderRadius: tokens.radius.lg, padding: "8px 14px", display: "flex", alignItems: "center", gap: 30 }}>
          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 2 }}>
            <EchoPulse />
            <span style={{ fontSize: 10, color: t.faint }}>EchoPulse</span>
          </div>
          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 10, paddingTop: 10 }}>
            <Spinner />
            <span style={{ fontSize: 10, color: t.faint }}>Spinner</span>
          </div>
        </div>

        {/* ── Icons ── */}
        <SectionTitle>Icon set — 24-grid, 1.6px stroke</SectionTitle>
        <div style={{ background: t.surface, border: `1px solid ${t.border}`, borderRadius: tokens.radius.lg, padding: 14, display: "grid", gridTemplateColumns: "repeat(6, 1fr)", gap: 14 }}>
          {(Object.keys(ICONS) as IconName[]).map((name) => (
            <div key={name} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
              <Icon name={name} size={20} color={t.muted} />
              <span style={{ fontSize: 8.5, color: t.ghost, overflow: "hidden", textOverflow: "ellipsis", maxWidth: "100%" }}>{name}</span>
            </div>
          ))}
        </div>
      </div>
    </Screen>
  );
}

// ── Motion demos — tap to replay each easing on a sliding dot ──

const MOTION_ROWS: Array<{ label: string; varName: string }> = [
  { label: "Micro (press)", varName: "--nx-transition-micro" },
  { label: "Element", varName: "--nx-transition-element" },
  { label: "Panel / sheet", varName: "--nx-transition-panel" },
  { label: "Page forward", varName: "--nx-transition-page-forward" },
  { label: "Pivot (tabs)", varName: "--nx-transition-pivot" },
];

function MotionDemos() {
  const [runs, setRuns] = useState<Record<string, boolean>>({});
  const toggle = (v: string) => setRuns((r) => ({ ...r, [v]: !r[v] }));
  return (
    <div style={{ background: t.surface, border: `1px solid ${t.border}`, borderRadius: tokens.radius.lg, overflow: "hidden" }}>
      {MOTION_ROWS.map((row, i) => (
        <Pressable
          key={row.varName}
          onClick={() => toggle(row.varName)}
          style={{
            display: "flex",
            width: "100%",
            textAlign: "left",
            alignItems: "center",
            gap: 12,
            padding: "12px 14px",
            borderTop: i > 0 ? `1px solid ${t.hair}` : "none",
            borderRadius: 0,
          }}
        >
          <div style={{ width: 110, flexShrink: 0 }}>
            <div style={{ fontSize: 13, fontWeight: 500, letterSpacing: -0.1, color: t.text }}>{row.label}</div>
            <div style={{ fontSize: 10, color: t.faint, fontFamily: tokens.font.mono }}>{row.varName.replace("--nx-transition-", "")}</div>
          </div>
          <div style={{ flex: 1, height: 22, position: "relative", background: t.surface2, borderRadius: tokens.radius.full }}>
            <div
              style={{
                position: "absolute",
                top: 3,
                left: runs[row.varName] ? "calc(100% - 19px)" : 3,
                width: 16,
                height: 16,
                borderRadius: tokens.radius.full,
                background: t.plum,
                transition: `left var(${row.varName})`,
              }}
            />
          </div>
        </Pressable>
      ))}
    </div>
  );
}
