"use client";

/**
 * Home flow — BOTH landing states, toggleable for review (2026-07-15):
 *
 *  • EMPTY (no collections): centered hero — mark → "Start your first
 *    collection" → two action cards (Research a topic / Start with a link).
 *    Quiet, single-purpose, no chrome that has nothing to do.
 *
 *  • COLLECTIONS: landing-app.jsx mock — Recent/All pivot (large-text
 *    segmented, thumb pill), avatar (bloom menu), collection cards, and a
 *    CREATE DOCK at the bottom ("Research a topic or paste a link…").
 *    The mock's composer reinterpreted per locked IA: it creates collections
 *    (chat lives inside a collection, never globally).
 *
 * Floating [Empty · Collections] chip toggles states; syncs to ?state=.
 */

import React, { useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Icon } from "../../../lib/icons";
import { EchoMark } from "../../../lib/logo";
import { Pressable, Screen, Segmented, StatusBar } from "../../../lib/primitives";
import { BloomMenu } from "../../../lib/surfaces";
import { t, tokens } from "../../../lib/tokens";

const COLLECTIONS = [
  { title: "The attention economy", items: 12, when: "updated 2h ago" },
  { title: "Second-brain tools", items: 7, when: "yesterday" },
  { title: "How memory works", items: 5, when: "last week" },
  { title: "AI platform shifts", items: 9, when: "3 days ago" },
  { title: "Ozempic & longevity", items: 6, when: "last month" },
];

export default function HomeFlow() {
  const params = useSearchParams();
  const router = useRouter();
  const [state, setState] = useState<string>(params.get("state") === "empty" ? "Empty" : "Collections");
  const [pivot, setPivot] = useState("Recent");
  const [menuOpen, setMenuOpen] = useState(false);

  const cards = useMemo(
    () => (pivot === "Recent" ? COLLECTIONS.slice(0, 3) : COLLECTIONS),
    [pivot]
  );

  return (
    <Screen>
      <StatusBar />

      {state === "Empty" ? <EmptyLanding /> : (
        <>
          {/* header: pivot + avatar */}
          <div
            style={{
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
              padding: "4px 14px 0",
              flexShrink: 0,
            }}
          >
            <Segmented items={["Recent", "All"]} value={pivot} onChange={setPivot} />
            <AvatarButton active={menuOpen} onClick={() => setMenuOpen(true)} />
          </div>

          {/* collection cards */}
          <div style={{ flex: 1, minHeight: 0, overflowY: "auto", padding: "18px 16px 120px" }}>
            <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
              {cards.map((c) => (
                <Pressable
                  key={c.title}
                  scale={0.985}
                  onClick={() => router.push("/flows/qa")}
                  style={{
                    display: "block",
                    width: "100%",
                    textAlign: "left",
                    background: t.surface,
                    border: `1px solid ${t.border}`,
                    borderRadius: 14,
                    padding: "15px 16px",
                    cursor: "pointer",
                    animation: "nxFadeRise .3s ease both",
                  }}
                >
                  <div style={{ fontSize: 17, fontWeight: 650, letterSpacing: -0.4, color: t.text, lineHeight: 1.25 }}>
                    {c.title}
                  </div>
                  <div style={{ fontSize: 13, color: t.faint, marginTop: 4, letterSpacing: -0.1 }}>
                    {c.items} sources · {c.when}
                  </div>
                </Pressable>
              ))}
            </div>
          </div>

          {/* create dock — the mock's composer, reinterpreted as creation entry */}
          <div style={{ position: "absolute", left: 16, right: 16, bottom: 24 }}>
            <Pressable
              scale={0.98}
              onClick={() => router.push("/flows/create")}
              style={{
                display: "flex",
                alignItems: "center",
                gap: 11,
                width: "100%",
                padding: "15px 18px",
                background: "rgba(255,255,255,0.72)",
                backdropFilter: "blur(24px) saturate(180%)",
                WebkitBackdropFilter: "blur(24px) saturate(180%)",
                border: `1px solid rgba(255,255,255,0.65)`,
                borderRadius: 999,
                boxShadow: "0 10px 32px rgba(19,14,26,0.13)",
                cursor: "pointer",
                textAlign: "left",
              }}
            >
              <Icon name="sparkle" size={17} color={t.plum} />
              <span style={{ flex: 1, fontSize: 15.5, letterSpacing: -0.2, color: t.ghost }}>
                Research a topic or paste a link…
              </span>
              <Icon name="arrowUp" size={16} color={t.faint} />
            </Pressable>
          </div>

          {/* avatar bloom menu — 3 flat rows, no header (locked 2026-06-29) */}
          <BloomMenu open={menuOpen} onClose={() => setMenuOpen(false)} anchor={{ top: 54, right: 14 }} origin="top right">
            {["Account", "Settings", "Feedback"].map((label) => (
              <Pressable
                key={label}
                scale={0.97}
                onClick={() => setMenuOpen(false)}
                style={{
                  display: "flex",
                  alignItems: "center",
                  width: 180,
                  padding: "11px 13px",
                  border: "none",
                  background: "transparent",
                  cursor: "pointer",
                  fontSize: 14.5,
                  letterSpacing: -0.2,
                  color: t.text,
                  textAlign: "left",
                }}
              >
                {label}
              </Pressable>
            ))}
          </BloomMenu>
        </>
      )}

      {/* review-only state toggle */}
      <div
        style={{
          position: "absolute",
          bottom: state === "Empty" ? 24 : 92,
          left: "50%",
          transform: "translateX(-50%)",
          display: "flex",
          gap: 4,
          padding: 3,
          background: "rgba(19,14,26,0.06)",
          borderRadius: 999,
          backdropFilter: "blur(10px)",
          zIndex: 30,
        }}
      >
        {["Empty", "Collections"].map((s) => (
          <button
            key={s}
            onClick={() => {
              setState(s);
              router.replace(`/flows/home?state=${s.toLowerCase()}`);
            }}
            style={{
              padding: "5px 12px",
              borderRadius: 999,
              border: "none",
              fontSize: 11,
              fontWeight: 600,
              letterSpacing: -0.1,
              cursor: "pointer",
              background: state === s ? t.surface : "transparent",
              color: state === s ? t.text : t.muted,
              boxShadow: state === s ? "0 2px 8px rgba(19,14,26,0.10)" : "none",
            }}
          >
            {s}
          </button>
        ))}
      </div>
    </Screen>
  );
}

// ── Empty landing: single-purpose zero state ──

function EmptyLanding() {
  const router = useRouter();
  return (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", padding: "0 20px" }}>
      {/* avatar still reachable top-right */}
      <div style={{ display: "flex", justifyContent: "flex-end", paddingTop: 4 }}>
        <AvatarButton active={false} onClick={() => {}} />
      </div>

      <div style={{ flex: 1 }} />

      <div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
        <EchoMark size={56} />
        <div
          style={{
            fontSize: 22,
            fontWeight: 650,
            letterSpacing: -0.5,
            color: t.text,
            marginTop: 22,
            fontFamily: tokens.font.display,
          }}
        >
          Start your first collection
        </div>
        <div style={{ fontSize: 14.5, color: t.muted, letterSpacing: -0.15, marginTop: 8, textAlign: "center" }}>
          Nexus reads what you save and answers from it.
        </div>
      </div>

      <div style={{ flex: 0.85 }} />

      <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
        <ActionCard
          icon="sparkle"
          title="Research a topic"
          detail="Nexus finds authoritative sources for you"
          onClick={() => router.push("/flows/create")}
        />
        <ActionCard
          icon="link"
          title="Start with a link"
          detail="Paste an article, video, or PDF"
          onClick={() => router.push("/flows/sources")}
        />
      </div>

      <div style={{ height: 96, flexShrink: 0 }} />
    </div>
  );
}

function ActionCard({ icon, title, detail, onClick }: { icon: React.ComponentProps<typeof Icon>["name"]; title: string; detail: string; onClick: () => void }) {
  return (
    <Pressable
      scale={0.98}
      onClick={onClick}
      style={{
        display: "flex",
        alignItems: "center",
        gap: 13,
        width: "100%",
        padding: "16px 16px",
        background: t.surface,
        border: `1px solid ${t.border}`,
        borderRadius: 16,
        cursor: "pointer",
        textAlign: "left",
      }}
    >
      <div
        style={{
          width: 38,
          height: 38,
          borderRadius: 12,
          background: tokens.color.bloom,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          flexShrink: 0,
        }}
      >
        <Icon name={icon} size={18} color={t.plum} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 15.5, fontWeight: 600, letterSpacing: -0.25, color: t.text }}>{title}</div>
        <div style={{ fontSize: 12.5, color: t.faint, letterSpacing: -0.1, marginTop: 2 }}>{detail}</div>
      </div>
      <Icon name="chevRight" size={15} color={t.ghost} />
    </Pressable>
  );
}

// ── Avatar button (spring pop on tap — landing-app.jsx) ──

function AvatarButton({ active, onClick }: { active: boolean; onClick: () => void }) {
  return (
    <Pressable
      scale={0.84}
      onClick={onClick}
      style={{
        width: 36,
        height: 36,
        borderRadius: 999,
        background: t.surface2,
        border: `1px solid ${t.borderStrong}`,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        cursor: "pointer",
        opacity: active ? 0 : 1,
        transition: "opacity .2s ease",
        flexShrink: 0,
      }}
    >
      <span style={{ fontSize: 13.5, fontWeight: 600, color: t.muted }}>S</span>
    </Pressable>
  );
}
