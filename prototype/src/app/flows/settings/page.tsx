"use client";

/**
 * Account · Settings · Feedback sheets — ChatGPT-exact styling (2026-07-16
 * review). Flat white cards (NO border stroke), grey section labels, icon
 * rows with inset hairline separators, values right-aligned. Top segmented
 * switches which sheet you're reviewing. X standardized trailing.
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

  return (
    <Screen>
      <StatusBar />

      {/* sheet chrome: grabber + title + X (trailing) */}
      <div style={{ display: "flex", justifyContent: "center", paddingTop: 8 }}>
        <div style={{ width: 36, height: 5, borderRadius: 999, background: t.border }} />
      </div>
      <div style={{ display: "flex", alignItems: "center", padding: "10px 16px 4px" }}>
        <div style={{ width: 30 }} />
        <div style={{ flex: 1, textAlign: "center", fontSize: 17, fontWeight: 650, letterSpacing: -0.4, color: t.text }}>
          {screen === "Feedback" ? "Send feedback" : screen}
        </div>
        <CloseX />
      </div>

      {screen === "Account" && <AccountSheet />}
      {screen === "Settings" && <SettingsSheet />}
      {screen === "Feedback" && <FeedbackSheet />}

      {/* review-only screen switcher */}
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
        {SCREENS.map((s) => (
          <button
            key={s}
            onClick={() => { setScreen(s); router.replace(`/flows/settings?s=${s.toLowerCase()}`); }}
            style={{
              padding: "5px 12px", borderRadius: 999, border: "none", fontSize: 11, fontWeight: 600,
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
    </Screen>
  );
}

function CloseX() {
  return (
    <button
      aria-label="Close"
      style={{
        width: 30, height: 30, borderRadius: 999, border: "none", background: t.surface2,
        display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer",
      }}
    >
      <Icon name="x" size={14} color={t.muted} stroke={2.2} />
    </button>
  );
}

// ── ChatGPT flat-card primitives (no border stroke) ──

function SectionLabel({ children }: { children: React.ReactNode }) {
  return (
    <div style={{ fontSize: 13, fontWeight: 500, letterSpacing: -0.1, color: t.faint, padding: "0 18px 7px" }}>
      {children}
    </div>
  );
}

function Card({ children }: { children: React.ReactNode }) {
  return (
    <div
      style={{
        background: t.surface,
        borderRadius: 16,
        overflow: "hidden",
        boxShadow: "0 1px 3px rgba(19,14,26,0.05)",
      }}
    >
      {children}
    </div>
  );
}

function Row({
  icon,
  label,
  value,
  trailing = "none",
  danger = false,
  last = false,
  onClick,
}: {
  icon: string;
  label: string;
  value?: string;
  trailing?: "chevron" | "external" | "none";
  danger?: boolean;
  last?: boolean;
  onClick?: () => void;
}) {
  const color = danger ? "#C0392B" : t.text;
  return (
    <Pressable
      scale={0.99}
      onClick={onClick}
      style={{
        display: "flex",
        alignItems: "center",
        gap: 13,
        width: "100%",
        padding: "13px 15px",
        // separator inset to align under the label, ChatGPT-style
        borderBottom: last ? "none" : `1px solid ${t.hair}`,
        borderBottomWidth: last ? 0 : 1,
        background: "transparent",
        border: "none",
        cursor: onClick ? "pointer" : "default",
        textAlign: "left",
        position: "relative",
      }}
    >
      <Icon name={icon as never} size={19} color={danger ? "#C0392B" : t.ink} stroke={1.7} />
      <span style={{ flex: 1, fontSize: 16, letterSpacing: -0.2, color }}>{label}</span>
      {value && <span style={{ fontSize: 15, letterSpacing: -0.2, color: t.faint }}>{value}</span>}
      {trailing === "chevron" && <Icon name="chevRight" size={15} color={t.ghost} />}
      {trailing === "external" && <Icon name="arrowUpRight" size={15} color={t.ghost} />}
    </Pressable>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Account — ChatGPT exact
// ─────────────────────────────────────────────────────────────────────────

function AccountSheet() {
  return (
    <div style={{ flex: 1, overflowY: "auto", padding: "14px 16px 120px" }}>
      {/* avatar + name */}
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", marginBottom: 26 }}>
        <div
          style={{
            width: 84, height: 84, borderRadius: 999, background: tokens.color.bloom,
            display: "flex", alignItems: "center", justifyContent: "center",
          }}
        >
          <span style={{ fontSize: 32, fontWeight: 600, color: t.plum }}>S</span>
        </div>
        <div style={{ fontSize: 19, fontWeight: 650, letterSpacing: -0.4, color: t.text, marginTop: 12 }}>
          Srihari
        </div>
      </div>

      <SectionLabel>Account</SectionLabel>
      <Card>
        <Row icon="envelope" label="Email" value="you@example.com" />
        <Row icon="sparkle" label="Subscription" value="Free · Beta" trailing="chevron" onClick={() => {}} last />
      </Card>

      <div style={{ height: 20 }} />

      {/* Log out — its own single-row card, red, door icon */}
      <Card>
        <Row icon="logout" label="Log out" danger onClick={() => {}} last />
      </Card>

      {/* Delete account — separate button OUTSIDE the list */}
      <button
        onClick={() => {}}
        style={{
          display: "block",
          width: "100%",
          marginTop: 26,
          padding: "14px 0",
          background: "transparent",
          border: "none",
          fontSize: 15.5,
          fontWeight: 500,
          letterSpacing: -0.2,
          color: "#C0392B",
          cursor: "pointer",
          fontFamily: "inherit",
          textAlign: "center",
        }}
      >
        Delete account
      </button>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Settings — ChatGPT exact (flat cards, native-menu Appearance, external links)
// ─────────────────────────────────────────────────────────────────────────

function SettingsSheet() {
  const [menuOpen, setMenuOpen] = useState(false);
  const [appearance] = useState("Light");

  return (
    <div style={{ flex: 1, overflowY: "auto", padding: "14px 16px 120px", position: "relative" }}>
      <SectionLabel>App</SectionLabel>
      <Card>
        <div style={{ position: "relative" }}>
          <Row icon="sliders" label="Appearance" value={appearance} trailing="chevron" onClick={() => setMenuOpen(!menuOpen)} />
          {menuOpen && (
            <div
              style={{
                position: "absolute", right: 12, top: 46, zIndex: 20, width: 200, padding: 5, borderRadius: 16,
                background: "rgba(255,255,255,0.72)",
                backdropFilter: "blur(30px) saturate(185%)", WebkitBackdropFilter: "blur(30px) saturate(185%)",
                border: "1px solid rgba(255,255,255,0.65)", boxShadow: "0 18px 44px rgba(19,14,26,0.18)",
                animation: "nxPop .2s ease both",
              }}
            >
              {["Light", "Dark", "System"].map((mode, i) => (
                <div
                  key={mode}
                  onClick={() => setMenuOpen(false)}
                  style={{
                    display: "flex", alignItems: "center", padding: "10px 12px", borderRadius: 11,
                    fontSize: 15, letterSpacing: -0.2, color: mode === "Light" ? t.text : t.ghost, cursor: "pointer",
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
      </Card>

      <div style={{ height: 20 }} />
      <SectionLabel>Data</SectionLabel>
      <Card>
        <Row icon="file" label="Offline reading cache" value="24 MB" />
        <Row icon="trash" label="Clear cache" onClick={() => {}} last />
      </Card>

      <div style={{ height: 20 }} />
      <SectionLabel>About</SectionLabel>
      <Card>
        <Row icon="nexus" label="Version" value="1.0 (1)" />
        <Row icon="note" label="Terms of Service" trailing="external" onClick={() => {}} />
        <Row icon="note" label="Privacy Policy" trailing="external" onClick={() => {}} last />
      </Card>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Feedback — ChatGPT "Report app issue" exact
// ─────────────────────────────────────────────────────────────────────────

function FeedbackSheet() {
  const [text, setText] = useState("");
  const [includeShot, setIncludeShot] = useState(true);
  const [shake, setShake] = useState(true);
  const [sent, setSent] = useState(false);

  if (sent) return <FeedbackThanks onAgain={() => { setSent(false); setText(""); }} />;

  return (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", padding: "18px 20px 0" }}>
      <div style={{ fontSize: 17, fontWeight: 650, letterSpacing: -0.3, color: t.text, marginBottom: 12 }}>
        What happened?
      </div>

      {/* grey filled text area with counter inside */}
      <div style={{ position: "relative", background: t.surface2, borderRadius: 16, padding: 16, minHeight: 180 }}>
        {text === "" && (
          <span style={{ position: "absolute", fontSize: 15.5, letterSpacing: -0.2, color: t.ghost, pointerEvents: "none" }}>
            Tell us about the issue you encountered
          </span>
        )}
        <textarea
          value={text}
          maxLength={2000}
          onChange={(e) => setText(e.target.value)}
          style={{
            width: "100%", height: 148, border: "none", outline: "none", resize: "none",
            background: "transparent", fontSize: 15.5, lineHeight: 1.55, letterSpacing: -0.2,
            color: t.text, fontFamily: "inherit",
          }}
        />
        <div style={{ position: "absolute", right: 16, bottom: 12, fontSize: 13.5, color: t.faint }}>
          {text.length} / 2000
        </div>
      </div>

      {/* disclaimer */}
      <div style={{ fontSize: 14, lineHeight: 1.5, letterSpacing: -0.15, color: t.muted, margin: "16px 2px 0" }}>
        Any information you share may be reviewed to help improve Nexus. If you have additional questions,{" "}
        <span style={{ color: t.plum, fontWeight: 500, cursor: "pointer" }}>contact support</span>.
      </div>

      {/* toggle rows with hairline separators */}
      <div style={{ marginTop: 22 }}>
        <div style={{ height: 1, background: t.hair }} />
        <ToggleRow label="Include screenshot in report" on={includeShot} onToggle={() => setIncludeShot(!includeShot)} />
        <div style={{ height: 1, background: t.hair }} />
        <ToggleRow
          label="Shake iPhone to report a bug"
          subtitle="Toggle off to disable"
          on={shake}
          onToggle={() => setShake(!shake)}
        />
      </div>

      <div style={{ flex: 1 }} />

      {/* bottom full-width Send */}
      <div style={{ padding: "0 0 max(env(safe-area-inset-bottom), 84px)" }}>
        <Pressable
          scale={0.98}
          onClick={() => text.trim() && setSent(true)}
          style={{
            display: "flex", alignItems: "center", justifyContent: "center",
            width: "100%", padding: "16px 0",
            background: text.trim() ? t.ink : t.surface2, border: "none", borderRadius: 999,
            fontSize: 16, fontWeight: 600, letterSpacing: -0.2,
            color: text.trim() ? "#fff" : t.ghost, cursor: "pointer",
            transition: "background .2s ease, color .2s ease",
          }}
        >
          Send
        </Pressable>
      </div>
    </div>
  );
}

function ToggleRow({
  label,
  subtitle,
  on,
  onToggle,
}: {
  label: string;
  subtitle?: string;
  on: boolean;
  onToggle: () => void;
}) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "15px 2px" }}>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 16, letterSpacing: -0.2, color: t.text }}>{label}</div>
        {subtitle && <div style={{ fontSize: 13, letterSpacing: -0.15, color: t.faint, marginTop: 2 }}>{subtitle}</div>}
      </div>
      <button
        onClick={onToggle}
        aria-label={label}
        style={{
          width: 51, height: 31, borderRadius: 999, border: "none", cursor: "pointer", padding: 0,
          background: on ? t.plum : "#E4E1EC",
          position: "relative", transition: "background .2s ease", flexShrink: 0,
        }}
      >
        <span
          style={{
            position: "absolute", top: 2, left: on ? 22 : 2, width: 27, height: 27, borderRadius: 999,
            background: "#fff", boxShadow: "0 1px 3px rgba(0,0,0,0.2)", transition: "left .2s cubic-bezier(.4,.0,.2,1)",
          }}
        />
      </button>
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
      <div style={{ fontSize: 18, fontWeight: 700, letterSpacing: -0.4, color: t.text, marginTop: 18 }}>Thank you</div>
      <div style={{ fontSize: 14, color: t.muted, letterSpacing: -0.15, marginTop: 6, textAlign: "center" }}>
        We read every single one.
      </div>
      <button
        onClick={onAgain}
        style={{ marginTop: 16, border: "none", background: "transparent", fontSize: 13.5, fontWeight: 500, color: t.plum, cursor: "pointer", fontFamily: "inherit" }}
      >
        Send another
      </button>
    </div>
  );
}
