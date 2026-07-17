"use client";

/**
 * FRE candidates (2026-07-16) — four directions for the first-run screen,
 * switchable in place (A·B·C·D pill, syncs ?v=). All four speak the Nexus
 * language: bloom page, ink type, one plum accent, pill geometry, Echo mark.
 *
 *  A · Current   — shipped baseline: kicker → rotating headline → composer
 *                  card → trending → link CTA. Utility-first.
 *  B · Hero      — ceremonial and symmetric: breathing Echo mark, one
 *                  centered question, centered composer, trending tile grid.
 *  C · Host      — NotebookLM ethos: Nexus speaks first. Conversational
 *                  intro in the product voice, then the composer continues
 *                  the dialogue. Trending offered inline, mid-sentence.
 *  D · Canvas    — Notion ethos, radical quiet: the input IS the page.
 *                  Giant borderless prompt, plain-text trending, no cards.
 */

import React, { useEffect, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Icon } from "../../../lib/icons";
import { EchoMark } from "../../../lib/logo";
import { Pressable, Screen, StatusBar } from "../../../lib/primitives";
import { t, tokens } from "../../../lib/tokens";

const TRENDING = ["US–Iran conflict", "AI platform shifts", "Ozempic & longevity", "Vision Pro 2"];
const ROTATING = ["the attention economy", "Vision Pro 2", "Ozempic & longevity", "AI platform shifts"];

const VARIANTS = ["A", "B", "C", "D"] as const;
type Variant = (typeof VARIANTS)[number];

export default function FRECandidates() {
  const params = useSearchParams();
  const router = useRouter();
  const initial = (params.get("v")?.toUpperCase() ?? "A") as Variant;
  const [variant, setVariant] = useState<Variant>(VARIANTS.includes(initial) ? initial : "A");

  return (
    <Screen>
      <StatusBar />

      {variant === "A" && <VariantCurrent />}
      {variant === "B" && <VariantHero />}
      {variant === "C" && <VariantHost />}
      {variant === "D" && <VariantCanvas />}

      {/* review-only variant switcher */}
      <div
        style={{
          position: "absolute",
          bottom: 24,
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
        {VARIANTS.map((v) => (
          <button
            key={v}
            onClick={() => {
              setVariant(v);
              router.replace(`/flows/fre?v=${v.toLowerCase()}`);
            }}
            style={{
              width: 34,
              height: 26,
              borderRadius: 999,
              border: "none",
              fontSize: 12,
              fontWeight: 700,
              cursor: "pointer",
              background: variant === v ? t.surface : "transparent",
              color: variant === v ? t.text : t.muted,
              boxShadow: variant === v ? "0 2px 8px rgba(19,14,26,0.10)" : "none",
            }}
          >
            {v}
          </button>
        ))}
      </div>
    </Screen>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// A · Current (shipped baseline, for honest comparison)
// ─────────────────────────────────────────────────────────────────────────

function VariantCurrent() {
  const [wordIdx, setWordIdx] = useState(0);
  useEffect(() => {
    const id = setInterval(() => setWordIdx((i) => (i + 1) % ROTATING.length), 2600);
    return () => clearInterval(id);
  }, []);

  return (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", padding: "0 22px" }}>
      <div style={{ flex: 1 }} />
      <div style={{ fontSize: 11.5, fontWeight: 600, letterSpacing: 0.8, color: t.ghost, marginBottom: 14 }}>
        NEW COLLECTION
      </div>
      <div style={{ fontSize: 29, fontWeight: 700, letterSpacing: -0.8, lineHeight: 1.18 }}>
        <div style={{ color: t.muted }}>Start a collection on</div>
        <div key={wordIdx} style={{ color: t.text, animation: "nxFadeRise .4s ease both", minHeight: 36 }}>
          {ROTATING[wordIdx]}
        </div>
      </div>
      <ComposerCard style={{ marginTop: 24 }} />
      <div style={{ fontSize: 11, fontWeight: 600, letterSpacing: 0.7, color: t.ghost, margin: "26px 0 10px" }}>
        TRENDING NOW
      </div>
      <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
        {TRENDING.map((topic) => (
          <TrendChip key={topic} label={topic} />
        ))}
      </div>
      <LinkCTA style={{ alignSelf: "center", marginTop: 30 }} />
      <div style={{ flex: 1.2 }} />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// B · Hero — ceremonial, symmetric, brand-forward
// ─────────────────────────────────────────────────────────────────────────

function VariantHero() {
  return (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", padding: "0 22px" }}>
      <div style={{ flex: 1 }} />

      <BreathingMark />

      <div
        style={{
          fontSize: 26,
          fontWeight: 700,
          letterSpacing: -0.7,
          color: t.text,
          textAlign: "center",
          marginTop: 26,
          lineHeight: 1.22,
          fontFamily: tokens.font.display,
        }}
      >
        What do you want
        <br />
        to understand?
      </div>

      <ComposerCard style={{ marginTop: 28, width: "100%" }} centered />

      {/* trending as a 2×2 tile grid — heavier furniture, more guided */}
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "1fr 1fr",
          gap: 8,
          width: "100%",
          marginTop: 18,
        }}
      >
        {TRENDING.map((topic) => (
          <Pressable
            key={topic}
            scale={0.97}
            style={{
              display: "flex",
              alignItems: "center",
              gap: 7,
              padding: "13px 14px",
              background: t.surface,
              border: `1px solid ${t.border}`,
              borderRadius: 14,
              fontSize: 13,
              fontWeight: 500,
              letterSpacing: -0.15,
              color: t.text,
              cursor: "pointer",
              textAlign: "left",
            }}
          >
            <Icon name="trending" size={12} color={t.plum} />
            <span style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{topic}</span>
          </Pressable>
        ))}
      </div>

      <LinkCTA style={{ marginTop: 24 }} />
      <div style={{ flex: 1.15 }} />
    </div>
  );
}

function BreathingMark() {
  return (
    <div style={{ animation: "nxBreathe 3.2s ease-in-out infinite" }}>
      <EchoMark size={64} />
      <style>{`@keyframes nxBreathe { 0%,100% { transform: scale(1); opacity: 1; } 50% { transform: scale(1.06); opacity: 0.88; } }`}</style>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// C · Host — Nexus speaks first (NotebookLM ethos, Ask-tab voice)
// ─────────────────────────────────────────────────────────────────────────

function VariantHost() {
  const [visibleLines, setVisibleLines] = useState(0);
  useEffect(() => {
    const timers = [0, 1, 2, 3].map((i) => setTimeout(() => setVisibleLines(i + 1), 350 + i * 520));
    return () => timers.forEach(clearTimeout);
  }, []);

  const line: React.CSSProperties = {
    fontSize: 17,
    fontWeight: 500,
    lineHeight: 1.55,
    letterSpacing: -0.25,
    color: t.text,
  };

  return (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", padding: "0 24px" }}>
      <div style={{ flex: 0.9 }} />

      <EchoMark size={30} />

      <div style={{ display: "flex", flexDirection: "column", gap: 14, marginTop: 20 }}>
        {visibleLines >= 1 && (
          <div style={{ ...line, animation: "nxFadeRise .5s ease both" }}>
            I&apos;m Nexus. Give me a topic — I&apos;ll read the best sources on it.
          </div>
        )}
        {visibleLines >= 2 && (
          <div style={{ ...line, color: t.muted, animation: "nxFadeRise .5s ease both" }}>
            Then ask me anything: what matters, what connects, what&apos;s missing.
          </div>
        )}
        {visibleLines >= 3 && (
          <div style={{ ...line, color: t.muted, animation: "nxFadeRise .5s ease both" }}>
            People are currently reading about{" "}
            {TRENDING.slice(0, 3).map((topic, i) => (
              <React.Fragment key={topic}>
                <button
                  style={{
                    display: "inline",
                    border: "none",
                    background: "transparent",
                    padding: 0,
                    fontSize: 17,
                    fontWeight: 600,
                    letterSpacing: -0.25,
                    color: t.plum,
                    cursor: "pointer",
                    fontFamily: "inherit",
                  }}
                >
                  {topic}
                </button>
                {i < 2 ? ", " : "."}
              </React.Fragment>
            ))}
          </div>
        )}
      </div>

      {visibleLines >= 4 && (
        <div style={{ animation: "nxFadeRise .5s ease both" }}>
          <ComposerCard style={{ marginTop: 26 }} />
          <LinkCTA plain style={{ marginTop: 18 }} />
        </div>
      )}

      <div style={{ flex: 1.4 }} />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// D · Canvas — the input IS the page (Notion ethos, radical quiet)
// ─────────────────────────────────────────────────────────────────────────

function VariantCanvas() {
  const [text, setText] = useState("");
  const ref = useRef<HTMLTextAreaElement>(null);

  return (
    <div
      style={{ flex: 1, display: "flex", flexDirection: "column", padding: "0 26px", cursor: "text" }}
      onClick={() => ref.current?.focus()}
    >
      <div style={{ flex: 0.8 }} />

      <div style={{ fontSize: 11.5, fontWeight: 600, letterSpacing: 0.8, color: t.ghost, marginBottom: 18 }}>
        NEW COLLECTION
      </div>

      {/* the page itself is the input — no card, no border */}
      <div style={{ position: "relative" }}>
        {text === "" && (
          <div
            style={{
              position: "absolute",
              inset: 0,
              fontSize: 34,
              fontWeight: 700,
              letterSpacing: -1,
              lineHeight: 1.2,
              color: t.ghost,
              pointerEvents: "none",
              fontFamily: tokens.font.display,
            }}
          >
            Research anything<span style={{ animation: "nxBlink 1.1s step-end infinite" }}>…</span>
            <style>{`@keyframes nxBlink { 50% { opacity: 0; } }`}</style>
          </div>
        )}
        <textarea
          ref={ref}
          value={text}
          rows={2}
          onChange={(e) => setText(e.target.value)}
          style={{
            width: "100%",
            border: "none",
            outline: "none",
            resize: "none",
            background: "transparent",
            fontSize: 34,
            fontWeight: 700,
            letterSpacing: -1,
            lineHeight: 1.2,
            color: t.text,
            fontFamily: tokens.font.display,
            padding: 0,
          }}
        />
      </div>

      {/* plum send appears only once there's intent */}
      {text.trim() && (
        <Pressable
          scale={0.94}
          style={{
            alignSelf: "flex-start",
            display: "flex",
            alignItems: "center",
            gap: 8,
            marginTop: 8,
            padding: "11px 20px",
            background: t.plum,
            border: "none",
            borderRadius: 999,
            fontSize: 14.5,
            fontWeight: 600,
            color: "#fff",
            cursor: "pointer",
            animation: "nxPop .3s ease both",
          }}
        >
          Research
          <Icon name="arrowUp" size={14} color="#fff" stroke={2.4} />
        </Pressable>
      )}

      {/* trending as quiet text lines — library index, not buttons */}
      <div style={{ marginTop: 44 }}>
        {TRENDING.map((topic) => (
          <button
            key={topic}
            style={{
              display: "flex",
              alignItems: "center",
              gap: 10,
              width: "100%",
              padding: "11px 0",
              border: "none",
              borderBottom: `1px solid ${t.hair}`,
              background: "transparent",
              fontSize: 15,
              fontWeight: 500,
              letterSpacing: -0.2,
              color: t.muted,
              cursor: "pointer",
              textAlign: "left",
              fontFamily: "inherit",
            }}
          >
            <Icon name="trending" size={13} color={t.ghost} />
            {topic}
            <span style={{ flex: 1 }} />
            <Icon name="arrowUp" size={12} color={t.ghost} />
          </button>
        ))}
      </div>

      <LinkCTA plain style={{ marginTop: 26, alignSelf: "flex-start" }} />
      <div style={{ flex: 1.3 }} />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Shared pieces
// ─────────────────────────────────────────────────────────────────────────

function ComposerCard({ style, centered = false }: { style?: React.CSSProperties; centered?: boolean }) {
  const [text, setText] = useState("");
  return (
    <div
      style={{
        padding: "16px 14px 12px",
        background: t.surface,
        borderRadius: 24,
        border: `1px solid ${t.border}`,
        ...style,
      }}
    >
      <div style={{ position: "relative", minHeight: 28, paddingBottom: 16 }}>
        {text === "" && (
          <span
            style={{
              position: "absolute",
              left: 4,
              top: 2,
              right: 4,
              fontSize: 17,
              letterSpacing: -0.2,
              color: t.ghost,
              pointerEvents: "none",
              textAlign: centered ? "center" : "left",
            }}
          >
            Research a topic…
          </span>
        )}
        <textarea
          value={text}
          rows={1}
          onChange={(e) => setText(e.target.value)}
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
            textAlign: centered && text === "" ? "center" : "left",
          }}
        />
      </div>
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
        {text.trim() ? (
          <div
            style={{
              width: 42,
              height: 42,
              borderRadius: 999,
              background: t.plum,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              animation: "nxPop .3s ease both",
            }}
          >
            <Icon name="arrowUp" size={15} color="#fff" stroke={2.4} />
          </div>
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

function TrendChip({ label }: { label: string }) {
  return (
    <Pressable
      scale={0.96}
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
      {label}
    </Pressable>
  );
}

function LinkCTA({ style, plain = false }: { style?: React.CSSProperties; plain?: boolean }) {
  if (plain) {
    return (
      <button
        style={{
          display: "inline-flex",
          alignItems: "center",
          gap: 7,
          border: "none",
          background: "transparent",
          fontSize: 14,
          fontWeight: 600,
          letterSpacing: -0.2,
          color: t.muted,
          cursor: "pointer",
          padding: 0,
          fontFamily: "inherit",
          ...style,
        }}
      >
        <Icon name="link" size={14} color={t.faint} />
        <span style={{ textDecoration: "underline", textUnderlineOffset: 3 }}>Or start with a link</span>
      </button>
    );
  }
  return (
    <Pressable
      scale={0.97}
      style={{
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        gap: 8,
        padding: "12px 22px",
        background: "transparent",
        border: `1px solid ${t.border}`,
        borderRadius: 999,
        fontSize: 14,
        fontWeight: 600,
        letterSpacing: -0.2,
        color: t.text,
        cursor: "pointer",
        ...style,
      }}
    >
      <Icon name="link" size={15} color={t.muted} />
      Start with a link
    </Pressable>
  );
}
