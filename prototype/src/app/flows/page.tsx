"use client";

/**
 * Flow index — the founder's bookmark. One card per flow, status chip,
 * pinned Design Tokens reference at top.
 */

import React from "react";
import { useRouter } from "next/navigation";
import { Icon, IconName } from "../../lib/icons";
import { EchoMark } from "../../lib/logo";
import { Pressable, Screen, StatusBar } from "../../lib/primitives";
import { t, tokens } from "../../lib/tokens";

type FlowStatus = "in review" | "draft" | "parked";

const FLOWS: Array<{
  slug: string;
  title: string;
  detail: string;
  icon: IconName;
  status: FlowStatus;
}> = [
  { slug: "login", title: "Login", detail: "Email + code · Apple · sign-up — 3 variants", icon: "envelope", status: "in review" },
  { slug: "onboarding", title: "FRE / Onboarding", detail: "Welcome → topics → first collection", icon: "sparkle", status: "draft" },
  { slug: "create", title: "Collection creation", detail: "Research a topic · start with a link", icon: "plus", status: "draft" },
  { slug: "home", title: "Home", detail: "Collection list · avatar bloom menu", icon: "layers", status: "draft" },
  { slug: "qa", title: "Q&A — Nexus tab", detail: "Chat · citations · Echo pulse · composer", icon: "nexus", status: "draft" },
  { slug: "sources", title: "Sources + Reader", detail: "Source list · add sheet · reader variants", icon: "book", status: "draft" },
  { slug: "settings", title: "Settings & account", detail: "Settings · account · feedback — variants", icon: "sliders", status: "draft" },
  { slug: "search", title: "Search", detail: "Parked until core flows lock", icon: "search", status: "parked" },
];

const STATUS_COLOR: Record<FlowStatus, string> = {
  "in review": t.plum,
  draft: t.faint,
  parked: t.ghost,
};

export default function FlowIndex() {
  const router = useRouter();
  return (
    <Screen>
      <StatusBar />
      <div style={{ flex: 1, overflowY: "auto", padding: "8px 16px 40px" }}>
        {/* header */}
        <div style={{ display: "flex", alignItems: "center", gap: 10, padding: "10px 2px 4px" }}>
          <EchoMark size={26} />
          <div>
            <div style={{ fontSize: 19, fontWeight: 700, letterSpacing: -0.4, color: t.text }}>Design flows</div>
            <div style={{ fontSize: 12, color: t.faint, letterSpacing: -0.1 }}>
              Tap a flow · variants toggle inside · MOCK works offline
            </div>
          </div>
        </div>

        {/* pinned tokens card */}
        <Pressable
          onClick={() => router.push("/flows/tokens")}
          style={{
            display: "flex",
            width: "100%",
            textAlign: "left",
            alignItems: "center",
            gap: 12,
            marginTop: 14,
            padding: "13px 14px",
            background: `linear-gradient(135deg, ${tokens.color.bloom} 0%, ${t.surface} 70%)`,
            border: `1px solid ${t.border}`,
            borderRadius: tokens.radius.lg,
          }}
        >
          <div
            style={{
              width: 34,
              height: 34,
              borderRadius: 10,
              background: t.surface,
              border: `1px solid ${t.border}`,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            <Icon name="grid" size={18} color={t.plum} />
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 15, fontWeight: 600, letterSpacing: -0.2, color: t.text }}>Design tokens</div>
            <div style={{ fontSize: 12, color: t.muted, letterSpacing: -0.1 }}>
              Live values — colors, type, spacing, motion. Tap any row to copy its name.
            </div>
          </div>
          <Icon name="chevRight" size={15} color={t.faint} />
        </Pressable>

        {/* flow cards */}
        <div style={{ display: "flex", flexDirection: "column", gap: 8, marginTop: 14 }}>
          {FLOWS.map((flow) => (
            <Pressable
              key={flow.slug}
              onClick={() => flow.status !== "parked" && router.push(`/flows/${flow.slug}`)}
              style={{
                display: "flex",
                width: "100%",
                textAlign: "left",
                alignItems: "center",
                gap: 12,
                padding: "13px 14px",
                background: t.surface,
                border: `1px solid ${t.border}`,
                borderRadius: tokens.radius.lg,
                opacity: flow.status === "parked" ? 0.55 : 1,
              }}
            >
              <div
                style={{
                  width: 34,
                  height: 34,
                  borderRadius: 10,
                  background: t.surface2,
                  border: `1px solid ${t.hair}`,
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                }}
              >
                <Icon name={flow.icon} size={18} color={t.muted} />
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 15, fontWeight: 600, letterSpacing: -0.2, color: t.text }}>{flow.title}</div>
                <div style={{ fontSize: 12, color: t.muted, letterSpacing: -0.1 }}>{flow.detail}</div>
              </div>
              <span
                style={{
                  fontSize: 10,
                  fontWeight: 700,
                  letterSpacing: 0.4,
                  textTransform: "uppercase",
                  color: STATUS_COLOR[flow.status],
                  border: `1px solid ${flow.status === "in review" ? t.plum : t.hair}`,
                  borderRadius: tokens.radius.full,
                  padding: "3px 8px",
                  flexShrink: 0,
                }}
              >
                {flow.status}
              </span>
            </Pressable>
          ))}
        </div>
      </div>
    </Screen>
  );
}
