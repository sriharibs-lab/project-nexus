"use client";

/**
 * Sheet variants (2026-07-16) — Account · Settings · Feedback, each with
 * A/B designs. Top segmented picks the screen; A·B pill picks the variant.
 *
 * Account   A · Stats     — profile + plan + usage stats + identity rows
 *           B · Flat list — ChatGPT-style single card of icon rows
 * Settings  A · Flat list — ChatGPT-style: icon rows, hairline separators,
 *                           inline value + native-menu feel for Appearance
 *           B · Cards     — current grouped-cards style (baseline)
 * Feedback  A · Form      — category chips, big text card, screenshot chip,
 *                           primary send at bottom
 *           B · Chat      — one conversational input in the product voice
 */

import React, { useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Icon } from "../../../lib/icons";
import { Pressable, Screen, StatusBar } from "../../../lib/primitives";
import { t, tokens } from "../../../lib/tokens";

const SCREENS = ["Account", "Settings", "Feedback"] as const;
type ScreenName = (typeof SCREENS)[number];

export default function SheetVariants() {
  const params = useSearchParams();
  const router = useRouter();
  const [screen, setScreen] = useState<ScreenName>(
    (SCREENS.find((s) => s.toLowerCase() === params.get("s")) ?? "Account") as ScreenName
  );
  const [variant, setVariant] = useState<"A" | "B">(params.get("v")?.toUpperCase() === "B" ? "B" : "A");

  const sync = (s: ScreenName, v: "A" | "B") =>
    router.replace(`/flows/settings?s=${s.toLowerCase()}&v=${v.toLowerCase()}`);

  return (
    <Screen>
      <StatusBar />

      {/* sheet chrome: grabber + title + X (trailing, standardized) */}
      <div style={{ display: "flex", justifyContent: "center", paddingTop: 8 }}>
        <div style={{ width: 36, height: 5, borderRadius: 999, background: t.border }} />
      </div>
      <div style={{ display: "flex", alignItems: "center", padding: "10px 16px 4px" }}>
        <div style={{ width: 30 }} />
        <div style={{ flex: 1, textAlign: "center", fontSize: 17, fontWeight: 650, letterSpacing: -0.4, color: t.text }}>
          {screen}
        </div>
        <button
          style={{
            width: 30,
            height: 30,
            borderRadius: 999,
            border: "none",
            background: t.surface2,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            cursor: "pointer",
          }}
          aria-label="Close"
        >
          <Icon name="x" size={14} color={t.muted} stroke={2.2} />
        </button>
      </div>

      {screen === "Account" && (variant === "A" ? <AccountStats /> : <AccountFlat />)}
      {screen === "Settings" && (variant === "A" ? <SettingsFlat /> : <SettingsCards />)}
      {screen === "Feedback" && (variant === "A" ? <FeedbackForm /> : <FeedbackChat />)}

      {/* review controls */}
      <div
        style={{
          position: "absolute",
          bottom: 24,
          left: "50%",
          transform: "translateX(-50%)",
          display: "flex",
          alignItems: "center",
          gap: 8,
          zIndex: 30,
        }}
      >
        <div style={{ display: "flex", gap: 4, padding: 3, background: "rgba(19,14,26,0.06)", borderRadius: 999, backdropFilter: "blur(10px)" }}>
          {SCREENS.map((s) => (
            <button
              key={s}
              onClick={() => { setScreen(s); sync(s, variant); }}
              style={{
                padding: "5px 11px", borderRadius: 999, border: "none", fontSize: 11, fontWeight: 600,
                cursor: "pointer",
                background: screen === s ? t.surface : "transparent",
                color: screen === s ? t.text : t.muted,
                boxShadow: screen === s ? "0 2px 8px rgba(19,14,26,0.10)" : "none",
              }}
            >
              {s}
            </button>
          ))}
        </div>
        <div style={{ display: "flex", gap: 4, padding: 3, background: "rgba(19,14,26,0.06)", borderRadius: 999, backdropFilter: "blur(10px)" }}>
          {(["A", "B"] as const).map((v) => (
            <button
              key={v}
              onClick={() => { setVariant(v); sync(screen, v); }}
              style={{
                width: 30, height: 24, borderRadius: 999, border: "none", fontSize: 12, fontWeight: 700,
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
      </div>
    </Screen>
  );
}

// ── shared row primitives (ChatGPT flat-list grammar) ──

function FlatCard({ children }: { children: React.ReactNode }) {
  return (
    <div style={{ background: t.surface, border: `1px solid ${t.border}`, borderRadius: 16, overflow: "hidden" }}>
      {children}
    </div>
  );
}

function FlatRow({
  icon,
  label,
  value,
  chevron = "right",
  danger = false,
  last = false,
  valueDot,
}: {
  icon: string;
  label: string;
  value?: string;
  chevron?: "right" | "menu" | "none";
  danger?: boolean;
  last?: boolean;
  valueDot?: string;
}) {
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 12,
        padding: "13px 14px",
        borderBottom: last ? "none" : `1px solid ${t.hair}`,
        cursor: "pointer",
      }}
    >
      <Icon name={icon as never} size={17} color={danger ? "#C0392B" : t.muted} />
      <span style={{ flex: 1, fontSize: 15.5, letterSpacing: -0.2, color: danger ? "#C0392B" : t.text }}>{label}</span>
      {valueDot && <span style={{ width: 8, height: 8, borderRadius: 999, background: valueDot }} />}
      {value && <span style={{ fontSize: 14.5, letterSpacing: -0.2, color: t.faint }}>{value}</span>}
      {chevron === "right" && <Icon name="chevRight" size={14} color={t.ghost} />}
      {chevron === "menu" && (
        <span style={{ display: "inline-flex", flexDirection: "column", gap: 1, alignItems: "center" }}>
          <span style={{ display: "inline-flex", transform: "rotate(180deg)" }}>
            <Icon name="chevDown" size={10} color={t.ghost} />
          </span>
          <Icon name="chevDown" size={10} color={t.ghost} />
        </span>
      )}
    </div>
  );
}

function SectionLabel({ children }: { children: React.ReactNode }) {
  return (
    <div style={{ fontSize: 12.5, fontWeight: 600, letterSpacing: -0.1, color: t.faint, padding: "0 4px 8px" }}>
      {children}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Account A · Stats — the sheet earns its space with the user's own numbers
// ─────────────────────────────────────────────────────────────────────────

function AccountStats() {
  return (
    <div style={{ flex: 1, overflowY: "auto", padding: "18px 16px 120px" }}>
      {/* profile */}
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", marginBottom: 22 }}>
        <div
          style={{
            width: 68, height: 68, borderRadius: 999, background: tokens.color.bloom,
            display: "flex", alignItems: "center", justifyContent: "center",
          }}
        >
          <span style={{ fontSize: 26, fontWeight: 600, color: t.plum }}>S</span>
        </div>
        <div style={{ fontSize: 15, color: t.muted, marginTop: 10 }}>srihari.scorp@gmail.com</div>
        <div
          style={{
            display: "inline-flex", alignItems: "center", gap: 6, marginTop: 8,
            padding: "5px 12px", background: t.surface, border: `1px solid ${t.border}`, borderRadius: 999,
          }}
        >
          <Icon name="sparkle" size={11} color={t.plum} />
          <span style={{ fontSize: 12.5, fontWeight: 600, color: t.text }}>Free · Beta</span>
        </div>
      </div>

      {/* usage stats — the "not bare" ingredient: your library, quantified */}
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 8, marginBottom: 18 }}>
        {[
          { n: "7", label: "collections" },
          { n: "46", label: "sources" },
          { n: "112", label: "questions" },
        ].map((s) => (
          <div
            key={s.label}
            style={{
              background: t.surface, border: `1px solid ${t.border}`, borderRadius: 14,
              padding: "14px 8px", textAlign: "center",
            }}
          >
            <div style={{ fontSize: 22, fontWeight: 700, letterSpacing: -0.6, color: t.text }}>{s.n}</div>
            <div style={{ fontSize: 11.5, letterSpacing: -0.1, color: t.faint, marginTop: 2 }}>{s.label}</div>
          </div>
        ))}
      </div>

      {/* identity rows */}
      <FlatCard>
        <FlatRow icon="link" label="Signed in with" value="Email" chevron="none" />
        <FlatRow icon="clock" label="Member since" value="Jun 2026" chevron="none" last />
      </FlatCard>

      <div style={{ height: 18 }} />

      <FlatCard>
        <FlatRow icon="chevRight" label="Sign out" chevron="none" />
        <FlatRow icon="trash" label="Delete account" danger chevron="none" last />
      </FlatCard>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Account B · Flat list — everything as one ChatGPT-style card
// ─────────────────────────────────────────────────────────────────────────

function AccountFlat() {
  return (
    <div style={{ flex: 1, overflowY: "auto", padding: "18px 16px 120px" }}>
      <div style={{ display: "flex", alignItems: "center", gap: 13, padding: "4px 4px 18px" }}>
        <div
          style={{
            width: 52, height: 52, borderRadius: 999, background: tokens.color.bloom,
            display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0,
          }}
        >
          <span style={{ fontSize: 20, fontWeight: 600, color: t.plum }}>S</span>
        </div>
        <div style={{ minWidth: 0 }}>
          <div style={{ fontSize: 16.5, fontWeight: 650, letterSpacing: -0.3, color: t.text }}>Srihari</div>
          <div style={{ fontSize: 13.5, color: t.faint, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
            srihari.scorp@gmail.com
          </div>
        </div>
      </div>

      <FlatCard>
        <FlatRow icon="sparkle" label="Plan" value="Free · Beta" chevron="right" />
        <FlatRow icon="link" label="Signed in with" value="Email" chevron="none" />
        <FlatRow icon="clock" label="Member since" value="Jun 2026" chevron="none" />
        <FlatRow icon="file" label="Export my data" chevron="right" last />
      </FlatCard>

      <div style={{ height: 18 }} />

      <FlatCard>
        <FlatRow icon="chevRight" label="Sign out" chevron="none" />
        <FlatRow icon="trash" label="Delete account" danger chevron="none" last />
      </FlatCard>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Settings A · Flat list — ChatGPT grammar, native menu for Appearance
// ─────────────────────────────────────────────────────────────────────────

function SettingsFlat() {
  const [menuOpen, setMenuOpen] = useState(false);
  const [appearance, setAppearance] = useState("Light");

  return (
    <div style={{ flex: 1, overflowY: "auto", padding: "18px 16px 120px", position: "relative" }}>
      <SectionLabel>App</SectionLabel>
      <FlatCard>
        {/* Appearance opens a native-style menu anchored to the row */}
        <div onClick={() => setMenuOpen(!menuOpen)} style={{ position: "relative" }}>
          <FlatRow icon="sliders" label="Appearance" value={appearance} chevron="menu" />
          {menuOpen && (
            <div
              style={{
                position: "absolute",
                right: 10,
                top: 44,
                zIndex: 20,
                width: 190,
                padding: 5,
                borderRadius: 16,
                background: "rgba(255,255,255,0.72)",
                backdropFilter: "blur(30px) saturate(185%)",
                WebkitBackdropFilter: "blur(30px) saturate(185%)",
                border: "1px solid rgba(255,255,255,0.65)",
                boxShadow: "0 18px 44px rgba(19,14,26,0.18)",
                animation: "nxPop .22s ease both",
              }}
            >
              {["Light", "Dark", "System"].map((mode, i) => (
                <div
                  key={mode}
                  onClick={(e) => {
                    e.stopPropagation();
                    if (mode === "Light") setAppearance(mode);
                    setMenuOpen(false);
                  }}
                  style={{
                    display: "flex",
                    alignItems: "center",
                    padding: "10px 12px",
                    borderRadius: 11,
                    fontSize: 15,
                    letterSpacing: -0.2,
                    color: mode === "Light" ? t.text : t.ghost,
                    cursor: "pointer",
                    borderBottom: i < 2 ? `1px solid ${t.hair}` : "none",
                  }}
                >
                  <span style={{ flex: 1 }}>{mode}</span>
                  {mode !== "Light" && (
                    <span style={{ fontSize: 10.5, fontWeight: 600, color: t.ghost, background: t.surface2, borderRadius: 999, padding: "2px 7px" }}>
                      Soon
                    </span>
                  )}
                  {appearance === mode && <Icon name="check" size={15} color={t.plum} />}
                </div>
              ))}
            </div>
          )}
        </div>
        <FlatRow icon="mic" label="Voice input" value="On" chevron="menu" />
        <FlatRow icon="globe" label="Default research depth" value="Standard" chevron="menu" last />
      </FlatCard>

      <div style={{ height: 20 }} />
      <SectionLabel>Data</SectionLabel>
      <FlatCard>
        <FlatRow icon="file" label="Offline reading cache" value="24 MB" chevron="right" />
        <FlatRow icon="trash" label="Clear cache" chevron="none" last />
      </FlatCard>

      <div style={{ height: 20 }} />
      <SectionLabel>About</SectionLabel>
      <FlatCard>
        <FlatRow icon="nexus" label="Version" value="1.0 (1)" chevron="none" />
        <FlatRow icon="note" label="Terms of Service" chevron="right" />
        <FlatRow icon="note" label="Privacy Policy" chevron="right" last />
      </FlatCard>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Settings B · Cards — the current shipped style (baseline for comparison)
// ─────────────────────────────────────────────────────────────────────────

function SettingsCards() {
  return (
    <div style={{ flex: 1, overflowY: "auto", padding: "18px 16px 120px" }}>
      {[
        { label: "Appearance", rows: [["Light", "✓"], ["Dark", "Soon"], ["System", "Soon"]] },
        { label: "Data", rows: [["Offline reading cache", "24 MB"], ["Clear cache", ""]] },
        { label: "About", rows: [["Version", "1.0 (1)"], ["Build stamp", "Jul 16 20:55"]] },
        { label: "Legal", rows: [["Terms of Service", "↗"], ["Privacy Policy", "↗"]] },
      ].map((section) => (
        <div key={section.label} style={{ marginBottom: 20 }}>
          <SectionLabel>{section.label}</SectionLabel>
          <FlatCard>
            {section.rows.map(([label, value], i) => (
              <div
                key={label}
                style={{
                  display: "flex", alignItems: "center", padding: "13px 14px",
                  borderBottom: i < section.rows.length - 1 ? `1px solid ${t.hair}` : "none",
                }}
              >
                <span style={{ flex: 1, fontSize: 15.5, letterSpacing: -0.2, color: value === "Soon" ? t.ghost : t.text }}>
                  {label}
                </span>
                <span style={{ fontSize: 14, color: value === "✓" ? t.plum : t.faint }}>{value}</span>
              </div>
            ))}
          </FlatCard>
        </div>
      ))}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Feedback A · Form — structured, one screen, primary send
// ─────────────────────────────────────────────────────────────────────────

function FeedbackForm() {
  const [category, setCategory] = useState("Bug");
  const [text, setText] = useState("");
  const [sent, setSent] = useState(false);

  if (sent) return <FeedbackThanks onAgain={() => { setSent(false); setText(""); }} />;

  return (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", padding: "18px 16px 120px" }}>
      <div style={{ display: "flex", gap: 8 }}>
        {["Bug", "Idea", "Other"].map((c) => (
          <button
            key={c}
            onClick={() => setCategory(c)}
            style={{
              flex: 1, padding: "10px 0", borderRadius: 999,
              border: `1px solid ${category === c ? t.plum : t.border}`,
              background: category === c ? tokens.color.bloom : t.surface,
              fontSize: 14, fontWeight: 600, letterSpacing: -0.2,
              color: category === c ? t.plum : t.muted,
              cursor: "pointer", fontFamily: "inherit", transition: "all .15s ease",
            }}
          >
            {c}
          </button>
        ))}
      </div>

      <div
        style={{
          flex: 1, minHeight: 180, marginTop: 14, padding: 16,
          background: t.surface, border: `1px solid ${t.border}`, borderRadius: 18,
          position: "relative",
        }}
      >
        {text === "" && (
          <span style={{ position: "absolute", fontSize: 15.5, color: t.ghost, pointerEvents: "none" }}>
            What did you see? What did you expect?
          </span>
        )}
        <textarea
          value={text}
          onChange={(e) => setText(e.target.value)}
          style={{
            width: "100%", height: "100%", border: "none", outline: "none", resize: "none",
            background: "transparent", fontSize: 15.5, lineHeight: 1.55, letterSpacing: -0.2,
            color: t.text, fontFamily: "inherit",
          }}
        />
      </div>

      {/* screenshot chip */}
      <div style={{ display: "flex", alignItems: "center", gap: 9, marginTop: 12 }}>
        <div
          style={{
            display: "inline-flex", alignItems: "center", gap: 7, padding: "8px 12px",
            background: t.surface, border: `1px solid ${t.border}`, borderRadius: 999,
          }}
        >
          <Icon name="photo" size={13} color={t.muted} />
          <span style={{ fontSize: 12.5, fontWeight: 500, color: t.muted }}>Screenshot attached</span>
          <Icon name="x" size={11} color={t.ghost} stroke={2.2} />
        </div>
      </div>

      <Pressable
        scale={0.97}
        onClick={() => text.trim() && setSent(true)}
        style={{
          display: "flex", alignItems: "center", justifyContent: "center", gap: 8,
          marginTop: 16, padding: "15px 0", width: "100%",
          background: text.trim() ? t.plum : t.surface2, border: "none", borderRadius: 999,
          fontSize: 15.5, fontWeight: 600, letterSpacing: -0.2,
          color: text.trim() ? "#fff" : t.ghost, cursor: "pointer",
          transition: "background .2s ease, color .2s ease",
        }}
      >
        Send feedback
      </Pressable>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Feedback B · Chat — one conversational input, product voice
// ─────────────────────────────────────────────────────────────────────────

function FeedbackChat() {
  const [text, setText] = useState("");
  const [sent, setSent] = useState(false);

  if (sent) return <FeedbackThanks onAgain={() => { setSent(false); setText(""); }} />;

  return (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", padding: "22px 22px 120px" }}>
      <div style={{ fontSize: 17.5, fontWeight: 500, lineHeight: 1.55, letterSpacing: -0.25, color: t.text }}>
        What&apos;s working? What&apos;s broken? What do you wish existed?
      </div>
      <div style={{ fontSize: 14, color: t.faint, letterSpacing: -0.15, marginTop: 8 }}>
        Goes straight to Srihari with a screenshot of your last screen.
      </div>

      <div
        style={{
          flex: 1, minHeight: 220, marginTop: 18, padding: 16,
          background: t.surface, border: `1px solid ${t.border}`, borderRadius: 22, position: "relative",
        }}
      >
        {text === "" && (
          <span style={{ position: "absolute", fontSize: 16, color: t.ghost, pointerEvents: "none" }}>
            Just type — no categories, no forms…
          </span>
        )}
        <textarea
          value={text}
          onChange={(e) => setText(e.target.value)}
          style={{
            width: "100%", height: "100%", border: "none", outline: "none", resize: "none",
            background: "transparent", fontSize: 16, lineHeight: 1.6, letterSpacing: -0.2,
            color: t.text, fontFamily: "inherit",
          }}
        />
        {text.trim() && (
          <div
            onClick={() => setSent(true)}
            style={{
              position: "absolute", right: 12, bottom: 12,
              width: 42, height: 42, borderRadius: 999, background: t.plum,
              display: "flex", alignItems: "center", justifyContent: "center",
              cursor: "pointer", animation: "nxPop .3s ease both",
            }}
          >
            <Icon name="arrowUp" size={16} color="#fff" stroke={2.4} />
          </div>
        )}
      </div>
    </div>
  );
}

function FeedbackThanks({ onAgain }: { onAgain: () => void }) {
  return (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", padding: 40 }}>
      <div
        style={{
          width: 62, height: 62, borderRadius: 999, background: tokens.color.bloom,
          display: "flex", alignItems: "center", justifyContent: "center", animation: "nxPop .4s ease both",
        }}
      >
        <Icon name="check" size={26} color={t.plum} stroke={2.4} />
      </div>
      <div style={{ fontSize: 18, fontWeight: 700, letterSpacing: -0.4, color: t.text, marginTop: 18 }}>
        Thank you
      </div>
      <div style={{ fontSize: 14, color: t.muted, letterSpacing: -0.15, marginTop: 6, textAlign: "center" }}>
        We read every single one.
      </div>
      <button
        onClick={onAgain}
        style={{
          marginTop: 16, border: "none", background: "transparent",
          fontSize: 13.5, fontWeight: 500, color: t.plum, cursor: "pointer", fontFamily: "inherit",
        }}
      >
        Send another
      </button>
    </div>
  );
}
