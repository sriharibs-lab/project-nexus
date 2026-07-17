"use client";

/**
 * FRE — onboarding tour candidates (2026-07-16). The TRUE first-run wizard:
 * what a brand-new user sees before landing in the app. Three directions,
 * switchable via the A·B·C pill; each is fully tappable through its steps
 * and "lands" on the empty home.
 *
 *  A · Pager      — the classic: 3 swipeable pages (promise → how it works
 *                   → pick interests), dots, Next/Skip. Familiar, safe.
 *  B · Spotlight  — one continuous canvas; the Echo mark stays center-stage
 *                   and the story changes around it in 3 beats. More brand,
 *                   fewer UI conventions.
 *  C · Learn-by-doing — no tour at all: Nexus walks you into creating your
 *                   first collection as the tutorial. The wizard IS the task
 *                   (Notion/Linear modern school).
 */

import React, { useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Icon } from "../../../lib/icons";
import { EchoMark } from "../../../lib/logo";
import { Pressable, Screen, StatusBar } from "../../../lib/primitives";
import { t, tokens } from "../../../lib/tokens";

const VARIANTS = ["A", "B", "C"] as const;
type Variant = (typeof VARIANTS)[number];

const INTEREST_TOPICS = [
  "Technology", "Science", "Business", "Health",
  "History", "Design", "Politics", "Climate",
  "AI", "Finance", "Culture", "Space",
];

export default function OnboardingCandidates() {
  const params = useSearchParams();
  const router = useRouter();
  const initial = (params.get("v")?.toUpperCase() ?? "A") as Variant;
  const [variant, setVariant] = useState<Variant>(VARIANTS.includes(initial) ? initial : "A");
  // Remount the active variant when switching so each demo restarts at step 0
  const [runKey, setRunKey] = useState(0);

  const land = () => router.push("/flows/home?state=empty");

  return (
    <Screen>
      <StatusBar />

      {variant === "A" && <PagerTour key={`a-${runKey}`} onDone={land} />}
      {variant === "B" && <SpotlightTour key={`b-${runKey}`} onDone={land} />}
      {variant === "C" && <DoingTour key={`c-${runKey}`} onDone={land} />}

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
              setRunKey((k) => k + 1);
              router.replace(`/flows/onboarding?v=${v.toLowerCase()}`);
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
// A · Pager — classic 3-page tour
// ─────────────────────────────────────────────────────────────────────────

function PagerTour({ onDone }: { onDone: () => void }) {
  const [page, setPage] = useState(0);
  const [picked, setPicked] = useState<Set<string>>(new Set());

  const next = () => (page < 2 ? setPage(page + 1) : onDone());

  return (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", overflow: "hidden" }}>
      {/* Skip */}
      <div style={{ display: "flex", justifyContent: "flex-end", padding: "6px 18px 0" }}>
        <button
          onClick={onDone}
          style={{ border: "none", background: "transparent", fontSize: 14, color: t.faint, cursor: "pointer", padding: 6 }}
        >
          Skip
        </button>
      </div>

      {/* Sliding pages */}
      <div style={{ flex: 1, minHeight: 0, position: "relative", overflow: "hidden" }}>
        <div
          style={{
            display: "flex",
            width: "300%",
            height: "100%",
            transform: `translateX(-${page * (100 / 3)}%)`,
            transition: "transform .45s cubic-bezier(.2,.8,.2,1)",
          }}
        >
          {/* Page 1 — the promise */}
          <TourPage>
            <EchoMark size={72} />
            <h2 style={pageTitle}>Think, don&apos;t just save.</h2>
            <p style={pageBody}>
              Nexus reads everything you collect — articles, videos, PDFs — and turns it into
              something you can actually think with.
            </p>
          </TourPage>

          {/* Page 2 — how it works */}
          <TourPage>
            <div style={{ display: "flex", flexDirection: "column", gap: 18, width: "100%" }}>
              {[
                { icon: "sparkle", title: "Collect", body: "Research a topic or save links — Nexus reads every source." },
                { icon: "nexus", title: "Ask", body: "Question your collection like a colleague who read it all." },
                { icon: "photo", title: "Create", body: "Turn it into audio, infographics, quizzes, or a paper." },
              ].map((row) => (
                <div key={row.title} style={{ display: "flex", gap: 14, alignItems: "flex-start", textAlign: "left" }}>
                  <div
                    style={{
                      width: 42, height: 42, borderRadius: 13, flexShrink: 0,
                      background: tokens.color.bloom, display: "flex", alignItems: "center", justifyContent: "center",
                    }}
                  >
                    <Icon name={row.icon as never} size={19} color={t.plum} />
                  </div>
                  <div>
                    <div style={{ fontSize: 16.5, fontWeight: 650, letterSpacing: -0.3, color: t.text }}>{row.title}</div>
                    <div style={{ fontSize: 14, lineHeight: 1.5, letterSpacing: -0.15, color: t.muted, marginTop: 3 }}>
                      {row.body}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </TourPage>

          {/* Page 3 — pick interests (seeds trending + FRE topics) */}
          <TourPage>
            <h2 style={{ ...pageTitle, fontSize: 22 }}>What do you read about?</h2>
            <p style={{ ...pageBody, marginTop: 6 }}>Pick a few — Nexus personalizes suggestions.</p>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 8, justifyContent: "center", marginTop: 18 }}>
              {INTEREST_TOPICS.map((topic) => {
                const on = picked.has(topic);
                return (
                  <button
                    key={topic}
                    onClick={() =>
                      setPicked((prev) => {
                        const nextSet = new Set(prev);
                        if (nextSet.has(topic)) {
                          nextSet.delete(topic);
                        } else {
                          nextSet.add(topic);
                        }
                        return nextSet;
                      })
                    }
                    style={{
                      padding: "9px 15px",
                      borderRadius: 999,
                      border: `1px solid ${on ? t.plum : t.border}`,
                      background: on ? tokens.color.bloom : t.surface,
                      fontSize: 13.5,
                      fontWeight: 500,
                      letterSpacing: -0.15,
                      color: on ? t.plum : t.text,
                      cursor: "pointer",
                      fontFamily: "inherit",
                      transition: "all .15s ease",
                    }}
                  >
                    {topic}
                  </button>
                );
              })}
            </div>
          </TourPage>
        </div>
      </div>

      {/* Dots + Next */}
      <div style={{ padding: "0 22px 84px" }}>
        <div style={{ display: "flex", justifyContent: "center", gap: 6, marginBottom: 18 }}>
          {[0, 1, 2].map((i) => (
            <div
              key={i}
              style={{
                width: i === page ? 20 : 6,
                height: 6,
                borderRadius: 999,
                background: i === page ? t.plum : t.border,
                transition: "all .3s cubic-bezier(.2,.8,.2,1)",
              }}
            />
          ))}
        </div>
        <Pressable
          scale={0.97}
          onClick={next}
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            width: "100%",
            padding: "15px 0",
            background: t.ink,
            border: "none",
            borderRadius: 999,
            fontSize: 15.5,
            fontWeight: 600,
            letterSpacing: -0.2,
            color: "#fff",
            cursor: "pointer",
          }}
        >
          {page < 2 ? "Next" : picked.size > 0 ? `Start with ${picked.size} interest${picked.size > 1 ? "s" : ""}` : "Get started"}
        </Pressable>
      </div>
    </div>
  );
}

const pageTitle: React.CSSProperties = {
  fontSize: 26,
  fontWeight: 700,
  letterSpacing: -0.7,
  color: "#130E1A",
  margin: "24px 0 0",
  lineHeight: 1.2,
};
const pageBody: React.CSSProperties = {
  fontSize: 15.5,
  lineHeight: 1.6,
  letterSpacing: -0.2,
  color: "#68607A",
  margin: "12px 0 0",
  maxWidth: 300,
};

function TourPage({ children }: { children: React.ReactNode }) {
  return (
    <div
      style={{
        width: `${100 / 3}%`,
        height: "100%",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        textAlign: "center",
        padding: "0 30px",
      }}
    >
      {children}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// B · Spotlight — the mark stays; the story changes around it
// ─────────────────────────────────────────────────────────────────────────

function SpotlightTour({ onDone }: { onDone: () => void }) {
  const [beat, setBeat] = useState(0);

  const BEATS = [
    {
      title: "Everything you save,\nread for you.",
      body: "Articles, videos, PDFs — collected into topics Nexus actually reads.",
    },
    {
      title: "Ask it anything.",
      body: "Your collection answers back — with citations from your own sources.",
    },
    {
      title: "Make it yours.",
      body: "Audio overviews, infographics, quizzes — created from what you saved.",
    },
  ];

  const next = () => (beat < 2 ? setBeat(beat + 1) : onDone());

  return (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", padding: "0 30px", overflow: "hidden" }}>
      <div style={{ display: "flex", justifyContent: "flex-end", width: "100%", paddingTop: 6 }}>
        <button
          onClick={onDone}
          style={{ border: "none", background: "transparent", fontSize: 14, color: t.faint, cursor: "pointer", padding: 6 }}
        >
          Skip
        </button>
      </div>

      <div style={{ flex: 1 }} />

      {/* The mark is the constant; rings hint at each beat */}
      <div style={{ position: "relative", width: 120, height: 120, display: "flex", alignItems: "center", justifyContent: "center" }}>
        {[0, 1, 2].map((i) => (
          <div
            key={i}
            style={{
              position: "absolute",
              inset: -((i + 1) * 14),
              borderRadius: 999,
              border: `1.5px solid ${t.plum}`,
              opacity: beat >= i ? 0.16 + i * 0.04 : 0,
              transform: `scale(${beat >= i ? 1 : 0.7})`,
              transition: "all .6s cubic-bezier(.2,.8,.2,1)",
            }}
          />
        ))}
        <EchoMark size={72} />
      </div>

      <div key={beat} style={{ textAlign: "center", marginTop: 34, animation: "nxFadeRise .5s ease both" }}>
        <h2 style={{ ...pageTitle, margin: 0, whiteSpace: "pre-line" }}>{BEATS[beat].title}</h2>
        <p style={{ ...pageBody, margin: "12px auto 0" }}>{BEATS[beat].body}</p>
      </div>

      <div style={{ flex: 1.2 }} />

      <div style={{ width: "100%", paddingBottom: 84 }}>
        <div style={{ display: "flex", justifyContent: "center", gap: 6, marginBottom: 18 }}>
          {[0, 1, 2].map((i) => (
            <div
              key={i}
              style={{
                width: i === beat ? 20 : 6,
                height: 6,
                borderRadius: 999,
                background: i === beat ? t.plum : t.border,
                transition: "all .3s cubic-bezier(.2,.8,.2,1)",
              }}
            />
          ))}
        </div>
        <Pressable
          scale={0.97}
          onClick={next}
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            width: "100%",
            padding: "15px 0",
            background: t.ink,
            border: "none",
            borderRadius: 999,
            fontSize: 15.5,
            fontWeight: 600,
            letterSpacing: -0.2,
            color: "#fff",
            cursor: "pointer",
          }}
        >
          {beat < 2 ? "Next" : "Get started"}
        </Pressable>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// C · Learn-by-doing — the tour IS creating your first collection
// ─────────────────────────────────────────────────────────────────────────

function DoingTour({ onDone }: { onDone: () => void }) {
  const [step, setStep] = useState(0);
  const [visibleLines, setVisibleLines] = useState(0);
  const [topic, setTopic] = useState<string | null>(null);

  useEffect(() => {
    if (step !== 0) return;
    const timers = [0, 1].map((i) => setTimeout(() => setVisibleLines(i + 1), 300 + i * 550));
    return () => timers.forEach(clearTimeout);
  }, [step]);

  const line: React.CSSProperties = {
    fontSize: 17.5,
    fontWeight: 500,
    lineHeight: 1.55,
    letterSpacing: -0.25,
    color: t.text,
  };

  return (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", padding: "0 26px" }}>
      <div style={{ flex: 0.7 }} />
      <EchoMark size={32} />

      {step === 0 && (
        <>
          <div style={{ display: "flex", flexDirection: "column", gap: 13, marginTop: 20 }}>
            {visibleLines >= 1 && (
              <div style={{ ...line, animation: "nxFadeRise .5s ease both" }}>
                Hi — I&apos;m Nexus. The fastest way to see what I do is to do it.
              </div>
            )}
            {visibleLines >= 2 && (
              <div style={{ ...line, color: t.muted, animation: "nxFadeRise .5s ease both" }}>
                Pick something you&apos;re curious about. I&apos;ll build your first collection around it.
              </div>
            )}
          </div>

          {visibleLines >= 2 && (
            <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginTop: 24, animation: "nxFadeRise .5s ease both" }}>
              {["AI platform shifts", "Ozempic & longevity", "Vision Pro 2", "The attention economy"].map((topicName) => (
                <button
                  key={topicName}
                  onClick={() => {
                    setTopic(topicName);
                    setStep(1);
                  }}
                  style={{
                    padding: "11px 16px",
                    borderRadius: 999,
                    border: `1px solid ${t.border}`,
                    background: t.surface,
                    fontSize: 14,
                    fontWeight: 500,
                    letterSpacing: -0.15,
                    color: t.text,
                    cursor: "pointer",
                    fontFamily: "inherit",
                  }}
                >
                  {topicName}
                </button>
              ))}
              <button
                onClick={onDone}
                style={{
                  padding: "11px 16px",
                  borderRadius: 999,
                  border: "none",
                  background: "transparent",
                  fontSize: 14,
                  fontWeight: 500,
                  color: t.faint,
                  cursor: "pointer",
                  fontFamily: "inherit",
                  textDecoration: "underline",
                  textUnderlineOffset: 3,
                }}
              >
                I&apos;ll explore on my own
              </button>
            </div>
          )}
        </>
      )}

      {step === 1 && (
        <div style={{ marginTop: 20 }}>
          <div style={{ ...line, animation: "nxFadeRise .4s ease both" }}>
            <span style={{ color: t.plum, fontWeight: 600 }}>{topic}</span> — good choice.
          </div>
          <div style={{ ...line, color: t.muted, marginTop: 12, animation: "nxFadeRise .4s ease .15s both" }}>
            Here&apos;s what happens next: I find the best sources, read them all, and then you can
            ask me anything about them. Watch.
          </div>
          <Pressable
            scale={0.97}
            onClick={onDone}
            style={{
              display: "inline-flex",
              alignItems: "center",
              gap: 8,
              marginTop: 26,
              padding: "13px 22px",
              background: t.plum,
              border: "none",
              borderRadius: 999,
              fontSize: 15,
              fontWeight: 600,
              color: "#fff",
              cursor: "pointer",
              animation: "nxFadeRise .4s ease .3s both",
            }}
          >
            Build my first collection
            <Icon name="arrowUp" size={14} color="#fff" stroke={2.4} />
          </Pressable>
        </div>
      )}

      <div style={{ flex: 1.4 }} />
    </div>
  );
}
