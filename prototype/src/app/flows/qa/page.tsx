"use client";

/**
 * Q&A flow — the Nexus tab, the core product surface.
 * Ported from design-handoff collection-view.jsx (NexusPane + composer +
 * artifacts + tab capsule).
 *
 * Structure: AI framing hook → Create cards (2×2) + starter chips →
 * chat thread (user pills right; Nexus answers as prose with inline
 * NotebookLM-style source chips) → EchoPulse wait state → suggestion
 * carousel → two-tier ask composer.
 *
 * MOCK: canned answers with the 1.5s wait beat. LIVE: real SSE chat
 * against POST /v1/collections/{id}/chat (word-chunk streaming; retrieved
 * sources render as a chip row).
 */

import React, { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { currentMode, getClient } from "../../../lib/api";
import { MOCK_COLLECTIONS, type Source } from "../../../lib/mock-data";
import { Icon, IconName } from "../../../lib/icons";
import { Pressable, Screen, StatusBar } from "../../../lib/primitives";
import { EchoPulse } from "../../../lib/surfaces";
import { t, tokens } from "../../../lib/tokens";
import { TabCapsule } from "../_shared/TabCapsule";

const collection = MOCK_COLLECTIONS[0];

// ── message model ──

type ChipRef = { label: string; icon: IconName };
type Part = string | ChipRef;
type Block = { type: "p" | "li"; parts: Part[] };
type ArtifactKind = "audio" | "info" | "quiz" | "paper";

type Msg =
  | { role: "user"; text: string }
  | { role: "nexus"; blocks: Block[]; kind?: ArtifactKind; streaming?: boolean };

// ── canned content (mock mode) — ported from collection-view.jsx ──

const chipFor = (s: Source | undefined): ChipRef => ({
  label: s?.publisher ?? "Source",
  icon: s?.content_type === "video" ? "video" : s?.content_type === "podcast" ? "mic" : "globe",
});

function starters(sources: Source[]): Array<{ q: string; blocks: Block[] }> {
  const a = chipFor(sources[0]);
  const b = chipFor(sources[1]);
  const c = chipFor(sources[2]);
  const z = chipFor(sources[sources.length - 1]);
  const p = (...parts: Part[]): Block => ({ type: "p", parts });
  const li = (...parts: Part[]): Block => ({ type: "li", parts });
  return [
    {
      q: "What are the key ideas across these sources?",
      blocks: [
        p(
          "Three threads run through this collection: what just happened, what's at stake, and how it got here. ",
          a, " and ", b,
          " carry the freshest account, while ", c,
          " supplies the structure underneath — read across them and the same few ideas keep resurfacing."
        ),
      ],
    },
    {
      q: "What should I read first?",
      blocks: [
        p(
          `Start with "${sources[0]?.title ?? "the overview"}" `, a,
          " — it's the clearest overview in the set. Then ", b,
          " for the background, and save the longer pieces for when you want depth."
        ),
      ],
    },
    {
      q: "Summarize this collection in 3 bullets",
      blocks: [
        li("The newest developments — and why this moment is different — are best captured by ", a, "."),
        li("The stakes: who stands to gain or lose, laid out most sharply in ", b, "."),
        li("The long arc: ", c, " traces how things reached this point, which the daily coverage assumes."),
      ],
    },
    {
      q: "What questions does this collection raise?",
      blocks: [
        p("A few questions your sources circle but don't settle:"),
        li("Is this a turning point or another swing of the cycle? ", a),
        li("Whose framing of the stakes is right? ", b, " and ", z, " read them quite differently."),
        li("What single development would change the whole picture? The analysis hints, but stops short. ", c),
      ],
    },
    {
      q: "Are there contradictions between sources?",
      blocks: [
        p(
          "Aligned on the facts, split on the framing. ", a,
          " treats the latest developments as significant; ", z,
          " reads them as noise inside a longer pattern. The disagreement is about trajectory, not events — worth reading those two side by side."
        ),
      ],
    },
    {
      q: "What's missing from this collection?",
      blocks: [
        p(
          "You're strong on reporting and analysis, lighter on primary documents and data — and there's no skeptical counter-view in the set yet. Want me to find a couple of candidates?"
        ),
      ],
    },
  ];
}

const CREATE: Array<{ q: string; label: string; kind: ArtifactKind; icon: IconName; blocks: Block[] }> = [
  { q: "Create an audio summary", label: "Audio summary", kind: "audio", icon: "waveform", blocks: [{ type: "p", parts: ["Two hosts, one conversation — your collection as a listen:"] }] },
  { q: "Generate an infographic", label: "Infographic", kind: "info", icon: "trending", blocks: [{ type: "p", parts: ["The whole collection, distilled into one visual:"] }] },
  { q: "Quiz me on this", label: "Quiz me", kind: "quiz", icon: "quiz", blocks: [{ type: "p", parts: ["Let's see what stuck — five questions, straight from your sources:"] }] },
  { q: "Write a paper", label: "Write a paper", kind: "paper", icon: "note", blocks: [{ type: "p", parts: ["A structured draft, built only from what's in this collection:"] }] },
];

// ─────────────────────────────────────────────────────────────────────────

export default function QAFlow() {
  const router = useRouter();
  const [tab, setTab] = useState("ask");
  const [msgs, setMsgs] = useState<Msg[]>([]);
  const [busy, setBusy] = useState(false);
  const [artifacts, setArtifacts] = useState<ArtifactKind[]>([]);
  const [creating, setCreating] = useState<ArtifactKind | null>(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const abortRef = useRef<(() => void) | null>(null);
  const timers = useRef<Array<ReturnType<typeof setTimeout>>>([]);
  const busyRef = useRef(false);

  const starterList = starters(collection.sources);

  useEffect(() => {
    const timersAtMount = timers.current;
    return () => {
      timersAtMount.forEach(clearTimeout);
      abortRef.current?.();
    };
  }, []);

  useEffect(() => {
    const el = scrollRef.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [msgs, busy]);

  const askCanned = (q: string, blocks: Block[], kind?: ArtifactKind) => {
    setMsgs((m) => [...m, { role: "user", text: q }]);
    setBusy(true);
    timers.current.push(
      setTimeout(() => {
        setMsgs((m) => [...m, { role: "nexus", blocks, kind }]);
        setBusy(false);
      }, 1500)
    );
  };

  const askLive = (q: string) => {
    setMsgs((m) => [...m, { role: "user", text: q }]);
    setBusy(true);
    busyRef.current = true;
    const history = msgs
      .filter((m): m is Extract<Msg, { role: "user" }> => m.role === "user")
      .map((m) => ({ role: "user" as const, content: m.text }));

    let text = "";
    let chips: ChipRef[] = [];
    abortRef.current = getClient().chat(collection.id, q, history, (evt) => {
      if (evt.kind === "sources") {
        chips = evt.sources.map((s) => ({
          label: s.publisher ?? s.title,
          icon: (s.content_type === "video" ? "video" : "globe") as IconName,
        }));
      } else if (evt.kind === "chunk") {
        if (busyRef.current) {
          busyRef.current = false;
          setBusy(false);
        }
        text += evt.text;
        const blocks: Block[] = [
          ...(chips.length
            ? [{ type: "p" as const, parts: chips.flatMap<Part>((c, i) => (i ? [" ", c] : [c])) }]
            : []),
          { type: "p", parts: [text] },
        ];
        setMsgs((m) => {
          const last = m[m.length - 1];
          if (last?.role === "nexus" && last.streaming) {
            return [...m.slice(0, -1), { role: "nexus", blocks, streaming: true }];
          }
          return [...m, { role: "nexus", blocks, streaming: true }];
        });
      } else if (evt.kind === "done" || evt.kind === "error") {
        busyRef.current = false;
        setBusy(false);
        setMsgs((m) => {
          const last = m[m.length - 1];
          if (evt.kind === "error" && (!last || last.role !== "nexus" || !last.streaming)) {
            return [...m, { role: "nexus", blocks: [{ type: "p", parts: [evt.message] }] }];
          }
          if (last?.role === "nexus" && last.streaming) {
            return [...m.slice(0, -1), { ...last, streaming: false }];
          }
          return m;
        });
      }
    });
  };

  const ask = (q: string, blocks?: Block[], kind?: ArtifactKind) => {
    if (busy) return;
    if (currentMode() === "live" && !kind) {
      askLive(q);
    } else if (blocks) {
      askCanned(q, blocks, kind);
    } else {
      // free-typed question in mock mode → generic canned answer
      askCanned(q, [
        {
          type: "p",
          parts: [
            "Good question. Across your sources the picture is consistent: the fundamentals matter more than the noise, and ",
            chipFor(collection.sources[0]),
            " frames it best. Want me to go deeper on any part of this?",
          ],
        },
      ]);
    }
  };

  const makeArtifact = (kind: ArtifactKind) => {
    if (creating) return;
    setCreating(kind);
    timers.current.push(
      setTimeout(() => {
        setArtifacts((a) => [kind, ...a]);
        setCreating(null);
      }, 1500)
    );
  };

  const asked = new Set(msgs.filter((m) => m.role === "user").map((m) => m.text));
  const remaining = starterList.filter((s) => !asked.has(s.q));
  const empty = msgs.length === 0;

  return (
    <Screen>
      <StatusBar />

      {/* header — back + title + meta */}
      <div style={{ padding: "2px 12px 4px", flexShrink: 0 }}>
        <Pressable
          scale={0.84}
          pressDur={0.44}
          onClick={() => router.push("/flows")}
          aria-label="Back"
          style={{
            width: 40,
            height: 40,
            borderRadius: tokens.radius.full,
            border: `1px solid ${t.borderStrong}`,
            background: t.surface,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
          }}
        >
          <Icon name="chevLeft" size={20} color={t.text} stroke={1.8} />
        </Pressable>
      </div>
      <div style={{ padding: "2px 18px 6px", flexShrink: 0 }}>
        <div style={{ fontSize: 26, fontWeight: 700, letterSpacing: -0.7, lineHeight: 1.15, color: t.text }}>
          {collection.name}
        </div>
        <div style={{ fontSize: 13.5, color: t.faint, marginTop: 5, letterSpacing: -0.1 }}>
          {collection.sources.length} sources · updated 2h ago
        </div>
      </div>

      {/* ── Create tab — the artifact studio ── */}
      {tab === "create" && (
        <div style={{ flex: 1, minHeight: 0, overflowY: "auto", padding: "12px 18px 8px" }}>
          <div style={{ paddingTop: 16, animation: "nxFade .32s ease" }}>
            <Icon name="sparkle" size={27} color={t.text} />
            <div
              style={{
                fontSize: 16.5,
                fontWeight: 500,
                lineHeight: 1.55,
                letterSpacing: -0.25,
                color: t.text,
                marginTop: 14,
              }}
            >
              Turn this collection into something new — every creation is built only from your
              {" "}{collection.sources.length} sources.
            </div>

            <SectionCaption style={{ marginTop: 28 }}>Create</SectionCaption>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8, marginTop: 12 }}>
              {CREATE.map((item) => (
                <Pressable
                  key={item.q}
                  scale={0.95}
                  onClick={() => makeArtifact(item.kind)}
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: 10,
                    background: t.surface,
                    border: `1px solid ${t.border}`,
                    borderRadius: 14,
                    padding: 13,
                    textAlign: "left",
                    opacity: creating && creating !== item.kind ? 0.5 : 1,
                  }}
                >
                  <Icon name={item.icon} size={19} color={t.plum} stroke={1.8} />
                  <span style={{ fontSize: 13.5, fontWeight: 600, letterSpacing: -0.2, color: t.text }}>
                    {item.label}
                  </span>
                </Pressable>
              ))}
            </div>

            {creating && (
              <div style={{ display: "flex", justifyContent: "center", paddingTop: 8 }}>
                <EchoPulse />
              </div>
            )}

            {artifacts.length > 0 && (
              <>
                <SectionCaption style={{ marginTop: 24 }}>Your creations</SectionCaption>
                <div style={{ display: "flex", flexDirection: "column", gap: 10, marginTop: 12 }}>
                  {artifacts.map((kind, i) => (
                    <div key={`${kind}-${i}`} style={{ animation: "nxFadeRise .34s ease" }}>
                      <Artifact kind={kind} sources={collection.sources} title={collection.name} />
                    </div>
                  ))}
                </div>
              </>
            )}
          </div>
        </div>
      )}

      {/* ── Ask tab — the chat ── */}
      {tab === "ask" && (
      <div ref={scrollRef} style={{ flex: 1, minHeight: 0, overflowY: "auto", padding: "12px 18px 8px" }}>
        {empty ? (
          <div style={{ paddingTop: 16, animation: "nxFade .32s ease" }}>
            <Icon name="nexus" size={27} color={t.text} />
            <div
              style={{
                fontSize: 16.5,
                fontWeight: 500,
                lineHeight: 1.55,
                letterSpacing: -0.25,
                color: t.text,
                marginTop: 14,
              }}
            >
              {collection.ai_framing}
            </div>

            <SectionCaption style={{ marginTop: 28 }}>Ask</SectionCaption>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginTop: 12 }}>
              {starterList.map((s) => (
                <StarterChip key={s.q} q={s.q} onClick={() => ask(s.q, s.blocks)} />
              ))}
            </div>
          </div>
        ) : (
          <div style={{ display: "flex", flexDirection: "column", gap: 16, paddingTop: 4 }}>
            {msgs.map((m, i) =>
              m.role === "user" ? (
                <div
                  key={i}
                  style={{
                    alignSelf: "flex-end",
                    maxWidth: "82%",
                    background: t.surface2,
                    border: `1px solid ${t.hair}`,
                    borderRadius: 18,
                    padding: "10px 14px",
                    fontSize: 15,
                    letterSpacing: -0.2,
                    color: t.text,
                    lineHeight: 1.4,
                    animation: "nxFade .26s ease",
                  }}
                >
                  {m.text}
                </div>
              ) : (
                <div key={i} style={{ animation: "nxFade .34s ease" }}>
                  <Blocks blocks={m.blocks} />
                  {m.kind && (
                    <div style={{ marginTop: 12 }}>
                      <Artifact kind={m.kind} sources={collection.sources} title={collection.name} />
                    </div>
                  )}
                </div>
              )
            )}
            {busy && <EchoPulse />}
          </div>
        )}
      </div>
      )}

      {/* suggestion carousel after first exchange (Ask tab only) */}
      {tab === "ask" && !empty && remaining.length > 0 && (
        <div
          style={{
            flexShrink: 0,
            display: "flex",
            gap: 8,
            overflowX: "auto",
            padding: "6px 16px 4px",
            scrollbarWidth: "none",
          }}
        >
          {remaining.slice(0, 3).map((s) => (
            <StarterChip key={s.q} q={s.q} nowrap onClick={() => ask(s.q, s.blocks)} />
          ))}
        </div>
      )}

      {/* composer (Ask tab only) */}
      {tab === "ask" && (
        <div style={{ flexShrink: 0, padding: "6px 16px 6px" }}>
          <AskComposer disabled={busy} onSend={(q) => ask(q)} />
        </div>
      )}

      {/* tab capsule — Ask · Create · Sources */}
      <div style={{ flexShrink: 0, display: "flex", justifyContent: "center", padding: "6px 0 24px" }}>
        <TabCapsule
          tabs={[
            { key: "ask", label: "Ask", icon: "nexus", iconSelected: "nexusFill" },
            { key: "create", label: "Create", icon: "sparkle", iconSelected: "sparkle" },
            { key: "sources", label: "Sources", icon: "layers", iconSelected: "layersFill" },
          ]}
          active={tab}
          onChange={(key) => {
            setTab(key);
            if (key === "sources") router.push("/flows/sources");
          }}
        />
      </div>
    </Screen>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Pieces
// ─────────────────────────────────────────────────────────────────────────

function SectionCaption({ children, style }: { children: React.ReactNode; style?: React.CSSProperties }) {
  return (
    <div
      style={{
        fontSize: 11.5,
        fontWeight: 600,
        letterSpacing: 0.8,
        textTransform: "uppercase",
        color: t.faint,
        ...style,
      }}
    >
      {children}
    </div>
  );
}

/** Inline source chip — sits inside answer text, NotebookLM-style. */
function SrcChip({ icon, label }: ChipRef) {
  return (
    <span
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: 5,
        height: 22,
        padding: "0 9px",
        margin: "0 2px",
        borderRadius: tokens.radius.full,
        background: t.surface,
        border: `1px solid ${t.border}`,
        fontSize: 11.5,
        fontWeight: 600,
        color: t.muted,
        letterSpacing: -0.1,
        whiteSpace: "nowrap",
        verticalAlign: -5,
      }}
    >
      <Icon name={icon} size={11} color={t.faint} />
      {label}
    </span>
  );
}

function Blocks({ blocks }: { blocks: Block[] }) {
  const txt: React.CSSProperties = { fontSize: 15, lineHeight: 1.6, letterSpacing: -0.2, color: t.text };
  const render = (parts: Part[]) =>
    parts.map((part, i) => (typeof part === "string" ? part : <SrcChip key={i} {...part} />));
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
      {blocks.map((b, i) =>
        b.type === "li" ? (
          <div key={i} style={{ display: "flex", gap: 11 }}>
            <span style={{ color: t.faint, lineHeight: 1.6, fontSize: 15 }}>•</span>
            <span style={txt}>{render(b.parts)}</span>
          </div>
        ) : (
          <div key={i} style={txt}>
            {render(b.parts)}
          </div>
        )
      )}
    </div>
  );
}

function StarterChip({ q, onClick, nowrap }: { q: string; onClick: () => void; nowrap?: boolean }) {
  return (
    <Pressable
      scale={0.95}
      onClick={onClick}
      style={{
        display: "inline-flex",
        alignItems: "center",
        padding: "10px 15px",
        borderRadius: tokens.radius.full,
        background: t.surface,
        border: `1px solid ${t.border}`,
        fontSize: 13.5,
        fontWeight: 500,
        letterSpacing: -0.15,
        color: t.text,
        textAlign: "left",
        lineHeight: 1.3,
        whiteSpace: nowrap ? "nowrap" : "normal",
        flexShrink: 0,
      }}
    >
      {q}
    </Pressable>
  );
}

/** Mock artifacts the Create actions return. */
function Artifact({ kind, sources, title }: { kind: ArtifactKind; sources: Source[]; title: string }) {
  const a = sources[0];
  const b = sources[1];
  const card: React.CSSProperties = { background: t.surface, border: `1px solid ${t.border}`, borderRadius: 16 };
  if (kind === "audio") {
    return (
      <div style={{ ...card, display: "flex", alignItems: "center", gap: 12, padding: "12px 14px" }}>
        <div
          style={{
            width: 40,
            height: 40,
            borderRadius: tokens.radius.full,
            background: t.ink,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            flexShrink: 0,
          }}
        >
          <Icon name="play" size={17} color={tokens.color.white} />
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 14.5, fontWeight: 600, letterSpacing: -0.2, color: t.text }}>Audio overview</div>
          <div style={{ fontSize: 12.5, color: t.faint, marginTop: 2 }}>Two hosts · 4:32</div>
        </div>
        <Icon name="waveform" size={20} color={t.muted} />
      </div>
    );
  }
  if (kind === "info") {
    return (
      <div style={{ ...card, overflow: "hidden" }}>
        <div
          style={{
            height: 116,
            background: t.surface2,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            gap: 7,
          }}
        >
          <Icon name="trending" size={26} color={t.ghost} />
          <span style={{ fontSize: 12, color: t.faint }}>Generating preview…</span>
        </div>
        <div style={{ padding: "10px 14px", fontSize: 13.5, fontWeight: 600, letterSpacing: -0.2, color: t.text }}>
          {title} — in 5 numbers
        </div>
      </div>
    );
  }
  if (kind === "quiz") {
    return (
      <div style={{ ...card, padding: "13px 14px" }}>
        <SectionCaption>Question 1 of 5</SectionCaption>
        <div style={{ fontSize: 15, fontWeight: 600, letterSpacing: -0.2, color: t.text, marginTop: 7, lineHeight: 1.4 }}>
          Which outlet published &ldquo;{a?.title}&rdquo;?
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 7, marginTop: 11 }}>
          {[a?.publisher, b?.publisher].filter(Boolean).map((c) => (
            <Pressable
              key={c}
              scale={0.97}
              style={{
                width: "100%",
                textAlign: "left",
                padding: "10px 13px",
                borderRadius: 12,
                background: t.surface3,
                border: `1px solid ${t.hair}`,
                fontSize: 13.5,
                fontWeight: 500,
                color: t.text,
              }}
            >
              {c}
            </Pressable>
          ))}
        </div>
      </div>
    );
  }
  return (
    <div style={{ ...card, padding: "13px 14px" }}>
      <div style={{ display: "flex", alignItems: "center", gap: 7 }}>
        <Icon name="note" size={13} color={t.faint} />
        <SectionCaption>Draft outline</SectionCaption>
      </div>
      <div style={{ fontSize: 15, fontWeight: 600, letterSpacing: -0.2, color: t.text, marginTop: 7 }}>
        {title}: what the sources say
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: 5, marginTop: 9, fontSize: 13, color: t.muted, lineHeight: 1.5 }}>
        <span>I. The story so far</span>
        <span>II. Where the sources disagree</span>
        <span>III. What happens next</span>
      </div>
    </div>
  );
}

/** Two-tier ask composer — real input; ink circle is audio when empty, send when typed. */
function AskComposer({ disabled, onSend }: { disabled: boolean; onSend: (q: string) => void }) {
  const [text, setText] = useState("");
  const submit = () => {
    const q = text.trim();
    if (!q || disabled) return;
    setText("");
    onSend(q);
  };
  return (
    <div
      style={{
        width: "100%",
        background: t.surface,
        borderRadius: 24,
        border: `1px solid ${t.borderStrong}`,
        boxShadow: `0 0 0 3px ${t.surface2}, 0 2px 10px rgba(19,14,26,0.05)`,
        padding: "15px 13px 12px",
      }}
    >
      <div style={{ padding: "0 4px 15px" }}>
        <input
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && submit()}
          placeholder="Ask Nexus anything"
          style={{
            width: "100%",
            border: "none",
            outline: "none",
            background: "transparent",
            fontSize: 17,
            letterSpacing: -0.2,
            lineHeight: 1.4,
            color: t.text,
            fontFamily: tokens.font.ui,
          }}
        />
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
        <RoundIconButton name="plus" color={t.text} />
        <div style={{ flex: 1 }} />
        <RoundIconButton name="mic" color={t.muted} />
        <Pressable
          scale={0.88}
          onClick={text.trim() ? submit : undefined}
          aria-label={text.trim() ? "Send" : "Audio mode"}
          style={{
            width: 34,
            height: 34,
            borderRadius: tokens.radius.full,
            background: t.ink,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            flexShrink: 0,
          }}
        >
          <Icon
            name={text.trim() ? "arrowUp" : "waveform"}
            size={text.trim() ? 18 : 19}
            color={tokens.color.white}
            stroke={2}
          />
        </Pressable>
      </div>
    </div>
  );
}

function RoundIconButton({ name, color }: { name: IconName; color: string }) {
  return (
    <Pressable
      scale={0.9}
      style={{
        width: 32,
        height: 32,
        borderRadius: tokens.radius.full,
        background: t.surface,
        border: `1px solid ${t.border}`,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        flexShrink: 0,
      }}
    >
      <Icon name={name} size={18} color={color} />
    </Pressable>
  );
}
