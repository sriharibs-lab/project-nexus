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

import React, { useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Icon } from "../../../lib/icons";
import { Pressable, Screen, StatusBar } from "../../../lib/primitives";
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
  const [menuOpen, setMenuOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [collections, setCollections] = useState(COLLECTIONS);

  const visible = collections.filter((c) =>
    c.title.toLowerCase().includes(query.trim().toLowerCase())
  );

  return (
    <Screen>
      <StatusBar />

      {state === "Empty" ? <EmptyLanding /> : (
        <>
          {/* header: title + avatar (Recent/All pivot removed, review 2026-07-15) */}
          <div
            style={{
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
              padding: "8px 16px 0",
              flexShrink: 0,
            }}
          >
            <div style={{ fontSize: 22, fontWeight: 700, letterSpacing: -0.5, color: t.text, fontFamily: tokens.font.display }}>
              Nexus
            </div>
            <AvatarButton active={menuOpen} onClick={() => setMenuOpen(true)} />
          </div>

          {/* collection cards — swipe left to reveal Delete */}
          <div style={{ flex: 1, minHeight: 0, overflowY: "auto", padding: "16px 16px 170px" }}>
            <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
              {visible.map((c) => (
                <SwipeableCard
                  key={c.title}
                  title={c.title}
                  meta={`${c.items} sources · ${c.when}`}
                  onOpen={() => router.push("/flows/qa")}
                  onDelete={() => setCollections((cs) => cs.filter((x) => x.title !== c.title))}
                />
              ))}
              {visible.length === 0 && (
                <div style={{ textAlign: "center", color: t.faint, fontSize: 14, paddingTop: 40 }}>
                  No collections match “{query}”
                </div>
              )}
            </div>
          </div>

          {/* bottom stack: primary + New collection (right) above glass search bar */}
          <div style={{ position: "absolute", left: 16, right: 16, bottom: 24, display: "flex", flexDirection: "column", gap: 12 }}>
            <Pressable
              scale={0.96}
              onClick={() => setState("Empty")}
              style={{
                display: "inline-flex",
                alignItems: "center",
                gap: 7,
                alignSelf: "flex-end",
                padding: "12px 18px",
                background: t.ink,
                border: "none",
                borderRadius: 999,
                fontSize: 14,
                fontWeight: 600,
                letterSpacing: -0.2,
                color: "#FFFFFF",
                cursor: "pointer",
                boxShadow: "0 8px 24px rgba(19,14,26,0.22)",
              }}
            >
              <Icon name="plus" size={15} color="#FFFFFF" stroke={2.2} />
              New collection
            </Pressable>

            <ClaudeSearchBar value={query} onChange={setQuery} />
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
          bottom: state === "Empty" ? 24 : 148,
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

// ── Empty landing — the FRE input screen (review 2026-07-15):
//    kicker → rotating headline → central composer → 4 trending chips →
//    ONE "Start with a link" CTA (the three link-type tiles are gone).

const ROTATING = ["the attention economy", "Vision Pro 2", "Ozempic & longevity", "AI platform shifts"];
const TRENDING = ["US–Iran conflict", "AI platform shifts", "Ozempic & longevity", "Vision Pro 2"];

function EmptyLanding() {
  const router = useRouter();
  const [wordIdx, setWordIdx] = useState(0);

  React.useEffect(() => {
    const id = setInterval(() => setWordIdx((i) => (i + 1) % ROTATING.length), 2600);
    return () => clearInterval(id);
  }, []);

  return (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", padding: "0 22px", position: "relative" }}>
      {/* avatar top-right */}
      <div style={{ display: "flex", justifyContent: "flex-end", paddingTop: 4 }}>
        <AvatarButton active={false} onClick={() => {}} />
      </div>

      <div style={{ flex: 1 }} />

      {/* kicker */}
      <div style={{ fontSize: 11.5, fontWeight: 600, letterSpacing: 0.8, color: t.ghost, marginBottom: 14 }}>
        NEW COLLECTION
      </div>

      {/* headline + rotating word */}
      <div style={{ fontSize: 29, fontWeight: 700, letterSpacing: -0.8, lineHeight: 1.18 }}>
        <div style={{ color: t.muted }}>Start a collection on</div>
        <div key={wordIdx} style={{ color: t.text, animation: "nxFadeRise .4s ease both", minHeight: 36 }}>
          {ROTATING[wordIdx]}
        </div>
      </div>

      {/* central composer — EXACT FREComposer port (ResearchFlowView.swift):
          two tiers: 17pt input (pad-x 4, top 2, bottom 16, minH 28) over a
          42pt toolbar row — plus in 32×32 radius-8 square left, mic in 32×32
          circle right (→ 42pt plum send circle when text). Container: 14/16/12
          padding, radius xxl(24), border→borderStrong on focus. */}
      <FREComposerMock onSubmit={() => router.push("/flows/create")} />

      {/* trending chips */}
      <div style={{ fontSize: 11, fontWeight: 600, letterSpacing: 0.7, color: t.ghost, margin: "26px 0 10px" }}>
        TRENDING NOW
      </div>
      <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
        {TRENDING.map((topic) => (
          <Pressable
            key={topic}
            scale={0.96}
            onClick={() => router.push("/flows/create")}
            style={{
              display: "inline-flex",
              alignItems: "center",
              gap: 6,
              padding: "9px 14px",
              background: t.surface,
              border: `1px solid ${t.border}`,
              borderRadius: 999,
              fontSize: 13,
              fontWeight: 500,
              letterSpacing: -0.15,
              color: t.text,
              cursor: "pointer",
            }}
          >
            <Icon name="trending" size={12} color={t.faint} />
            {topic}
          </Pressable>
        ))}
      </div>

      {/* single CTA replacing the three link-type tiles */}
      <Pressable
        scale={0.97}
        onClick={() => router.push("/flows/sources")}
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          gap: 8,
          alignSelf: "center",
          marginTop: 30,
          padding: "12px 22px",
          background: "transparent",
          border: `1px solid ${t.border}`,
          borderRadius: 999,
          fontSize: 14,
          fontWeight: 600,
          letterSpacing: -0.2,
          color: t.text,
          cursor: "pointer",
        }}
      >
        <Icon name="link" size={15} color={t.muted} />
        Start with a link
      </Pressable>

      <div style={{ flex: 1.2 }} />
    </div>
  );
}

// ── FREComposer — 1:1 with the shipped iOS composer, but INTERACTIVE ──

function FREComposerMock({ onSubmit }: { onSubmit: (topic: string) => void }) {
  const [text, setText] = useState("");
  const [focused, setFocused] = useState(false);
  const hasText = text.trim().length > 0;

  return (
    <div
      onClick={(e) => (e.currentTarget.querySelector("textarea") as HTMLTextAreaElement)?.focus()}
      style={{
        marginTop: 24,
        padding: "16px 14px 12px",
        background: t.surface,
        borderRadius: 24,
        border: `1px solid ${focused ? t.borderStrong : t.border}`,
        transition: "border-color .2s ease",
        cursor: "text",
      }}
    >
      {/* text tier */}
      <div style={{ position: "relative", minHeight: 28, paddingBottom: 16 }}>
        {text === "" && (
          <span
            style={{
              position: "absolute",
              left: 4,
              top: 2,
              fontSize: 17,
              letterSpacing: -0.2,
              color: t.ghost,
              pointerEvents: "none",
            }}
          >
            Research a topic…
          </span>
        )}
        <textarea
          value={text}
          rows={1}
          onChange={(e) => setText(e.target.value)}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && !e.shiftKey && hasText) {
              e.preventDefault();
              onSubmit(text.trim());
            }
          }}
          style={{
            width: "100%",
            border: "none",
            outline: "none",
            resize: "none",
            background: "transparent",
            fontSize: 17,
            letterSpacing: -0.2,
            color: t.text,
            fontFamily: "inherit",
            padding: "2px 4px 0",
            maxHeight: 66,
          }}
        />
      </div>

      {/* toolbar tier — anchored 42pt */}
      <div style={{ display: "flex", alignItems: "center", height: 42 }}>
        <div
          style={{
            width: 32,
            height: 32,
            borderRadius: 8,
            background: t.surface2,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
          }}
        >
          <Icon name="plus" size={15} color={t.ink} />
        </div>
        <div style={{ flex: 1 }} />
        {hasText ? (
          <Pressable
            scale={0.9}
            onClick={() => onSubmit(text.trim())}
            style={{
              width: 42,
              height: 42,
              borderRadius: 999,
              background: t.plum,
              border: "none",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              cursor: "pointer",
              animation: "nxPop .3s ease both",
            }}
          >
            <Icon name="arrowUp" size={15} color="#FFFFFF" stroke={2.4} />
          </Pressable>
        ) : (
          <div
            style={{
              width: 32,
              height: 32,
              borderRadius: 999,
              background: t.surface2,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              margin: 5,
            }}
          >
            <Icon name="mic" size={14} color={t.muted} />
          </div>
        )}
      </div>
    </div>
  );
}

// ── Swipeable collection card (pointer drag reveals Delete) ──

function SwipeableCard({
  title,
  meta,
  onOpen,
  onDelete,
}: {
  title: string;
  meta: string;
  onOpen: () => void;
  onDelete: () => void;
}) {
  const [dx, setDx] = useState(0);
  const drag = React.useRef<{ startX: number; active: boolean; moved: boolean }>({ startX: 0, active: false, moved: false });
  const OPEN = -84;

  const settle = (open: boolean) => setDx(open ? OPEN : 0);

  return (
    <div style={{ position: "relative", borderRadius: 14, overflow: "hidden" }}>
      {/* delete backdrop */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          display: "flex",
          alignItems: "center",
          justifyContent: "flex-end",
          background: "#C0392B",
          borderRadius: 14,
        }}
      >
        <button
          onClick={onDelete}
          style={{
            width: 84,
            height: "100%",
            border: "none",
            background: "transparent",
            color: "#fff",
            fontSize: 13.5,
            fontWeight: 600,
            cursor: "pointer",
          }}
        >
          Delete
        </button>
      </div>

      {/* card */}
      <div
        onPointerDown={(e) => {
          drag.current = { startX: e.clientX - dx, active: true, moved: false };
          (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
        }}
        onPointerMove={(e) => {
          if (!drag.current.active) return;
          const next = Math.min(0, Math.max(OPEN - 20, e.clientX - drag.current.startX));
          if (Math.abs(next - dx) > 2) drag.current.moved = true;
          setDx(next);
        }}
        onPointerUp={() => {
          if (!drag.current.active) return;
          drag.current.active = false;
          if (!drag.current.moved) {
            if (dx !== 0) settle(false);
            else onOpen();
            return;
          }
          settle(dx < OPEN / 2);
        }}
        style={{
          position: "relative",
          background: t.surface,
          border: `1px solid ${t.border}`,
          borderRadius: 14,
          padding: "15px 16px",
          transform: `translateX(${dx}px)`,
          transition: drag.current.active ? "none" : "transform .28s cubic-bezier(.2,.8,.2,1)",
          touchAction: "pan-y",
          cursor: "pointer",
          userSelect: "none",
        }}
      >
        <div style={{ fontSize: 17, fontWeight: 650, letterSpacing: -0.4, color: t.text, lineHeight: 1.25 }}>
          {title}
        </div>
        <div style={{ fontSize: 13, color: t.faint, marginTop: 4, letterSpacing: -0.1 }}>{meta}</div>
      </div>
    </div>
  );
}

// ── Claude-iOS-style search (real input: focus, type, filter, clear) ──

function ClaudeSearchBar({
  value,
  onChange,
}: {
  value: string;
  onChange: (v: string) => void;
}) {
  const [focused, setFocused] = useState(false);
  const inputRef = React.useRef<HTMLInputElement>(null);

  return (
    <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
      <div
        onClick={() => inputRef.current?.focus()}
        style={{
          flex: 1,
          display: "flex",
          alignItems: "center",
          gap: 9,
          padding: "13px 16px",
          background: "rgba(255,255,255,0.62)",
          backdropFilter: "blur(26px) saturate(185%)",
          WebkitBackdropFilter: "blur(26px) saturate(185%)",
          border: `1px solid ${focused ? "rgba(255,255,255,0.95)" : "rgba(255,255,255,0.65)"}`,
          borderRadius: 999,
          boxShadow: focused
            ? "0 10px 32px rgba(19,14,26,0.16), inset 0 1px 1px rgba(255,255,255,0.9)"
            : "0 10px 32px rgba(19,14,26,0.12), inset 0 1px 1px rgba(255,255,255,0.85)",
          transition: "border-color .2s ease, box-shadow .2s ease",
          cursor: "text",
        }}
      >
        <Icon name="search" size={16} color={t.faint} />
        <input
          ref={inputRef}
          value={value}
          placeholder="Search"
          onChange={(e) => onChange(e.target.value)}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          style={{
            flex: 1,
            minWidth: 0,
            border: "none",
            outline: "none",
            background: "transparent",
            fontSize: 15.5,
            letterSpacing: -0.2,
            color: t.text,
            fontFamily: "inherit",
          }}
        />
        {value && (
          <button
            onClick={() => {
              onChange("");
              inputRef.current?.focus();
            }}
            style={{
              width: 18,
              height: 18,
              borderRadius: 999,
              border: "none",
              background: t.ghost,
              color: "#fff",
              fontSize: 11,
              lineHeight: 1,
              cursor: "pointer",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              padding: 0,
            }}
          >
            ×
          </button>
        )}
      </div>

      {focused && (
        <button
          onMouseDown={(e) => e.preventDefault()}
          onClick={() => {
            onChange("");
            inputRef.current?.blur();
          }}
          style={{
            border: "none",
            background: "transparent",
            fontSize: 15,
            fontWeight: 500,
            letterSpacing: -0.2,
            color: t.plum,
            cursor: "pointer",
            padding: "4px 2px",
            animation: "nxFade .2s ease both",
          }}
        >
          Cancel
        </button>
      )}
    </div>
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
