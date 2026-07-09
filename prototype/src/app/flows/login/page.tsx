"use client";

/**
 * Login flow — LOCKED DIRECTION (2026-07-08): Claude iOS auth, adapted to Nexus.
 *
 * Spec (from Claude iOS reference screenshots):
 *  - Flat, calm page. Minimal brand color — ink pill buttons, plum only for links.
 *  - Lockup top-center; hero mark + display tagline in the upper half.
 *  - Fully-rounded (pill) shapes for ALL buttons and inputs.
 *  - "Continue with email" is a TEXT BOX, not a button — you type right there.
 *  - Send affordance: dark circle appears when the email is valid; becomes a
 *    spinner while the code email is being prepared (inline loading).
 *  - Code screen: bordered card, gray inner panel with the email + envelope-
 *    with-seal graphic + pill code field, "Change email address" link below.
 *  - Terms/Privacy disclaimer on every screen (stub links — see PARKING_LOT.md).
 *
 * MOCK mode: any 6-digit code. LIVE mode: real OTP via FastAPI + Supabase.
 */

import React, { useRef, useState } from "react";
import { getClient } from "../../../lib/api";
import { Icon } from "../../../lib/icons";
import { EchoMark } from "../../../lib/logo";
import { Pressable, Screen, Spinner, StatusBar } from "../../../lib/primitives";
import { t, tokens } from "../../../lib/tokens";

type Phase = "idle" | "sending" | "otp" | "verifying" | "done";

export default function LoginFlow() {
  const [phase, setPhase] = useState<Phase>("idle");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | null>(null);

  const emailValid = /^[^@\s]+@[^@\s]+\.[^@\s]{2,}$/.test(email.trim());

  const submitEmail = async () => {
    if (!emailValid || phase === "sending") return;
    setError(null);
    setPhase("sending");
    try {
      await getClient().requestOtp(email.trim());
      setCode("");
      setPhase("otp");
    } catch (err) {
      setError((err as Error).message);
      setPhase("idle");
    }
  };

  const submitCode = async (value: string) => {
    setError(null);
    setPhase("verifying");
    try {
      await getClient().verifyOtp(email.trim(), value.trim());
      setPhase("done");
    } catch (err) {
      setError((err as Error).message);
      setPhase("otp");
    }
  };

  return (
    <Screen style={{ background: t.surface3 }}>
      <StatusBar />

      {/* small mark top-center on secondary screens only — landing has the hero mark */}
      {(phase === "otp" || phase === "verifying" || phase === "done") && (
        <div style={{ display: "flex", justifyContent: "center", padding: "10px 0 0", flexShrink: 0 }}>
          <EchoMark size={26} />
        </div>
      )}

      {phase === "otp" || phase === "verifying" ? (
        <CodeScreen
          email={email}
          code={code}
          setCode={setCode}
          verifying={phase === "verifying"}
          error={error}
          onSubmit={submitCode}
          onChangeEmail={() => {
            setPhase("idle");
            setCode("");
            setError(null);
          }}
        />
      ) : phase === "done" ? (
        <DoneScreen
          onReset={() => {
            setPhase("idle");
            setEmail("");
            setCode("");
          }}
        />
      ) : (
        <LandingScreen
          email={email}
          setEmail={setEmail}
          emailValid={emailValid}
          sending={phase === "sending"}
          error={error}
          onSubmit={submitEmail}
        />
      )}
    </Screen>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Landing — hero + Apple pill + email text box with inline send/loading
// ─────────────────────────────────────────────────────────────────────────

function LandingScreen({
  email,
  setEmail,
  emailValid,
  sending,
  error,
  onSubmit,
}: {
  email: string;
  setEmail: (v: string) => void;
  emailValid: boolean;
  sending: boolean;
  error: string | null;
  onSubmit: () => void;
}) {
  return (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", padding: "0 20px", position: "relative" }}>
      {/* hero — dead-center of the screen; mark → "Nexus" → tagline,
          both text rows same font/size/weight */}
      <div
        style={{
          position: "absolute",
          top: "50%",
          left: 0,
          right: 0,
          transform: "translateY(-50%)",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          pointerEvents: "none",
        }}
      >
        <EchoMark size={64} />
        <div
          style={{
            fontSize: 27,
            fontWeight: 600,
            letterSpacing: -0.6,
            color: t.text,
            fontFamily: tokens.font.display,
            textAlign: "center",
            marginTop: 26,
            lineHeight: 1.25,
          }}
        >
          Nexus
        </div>
        <div
          style={{
            fontSize: 27,
            fontWeight: 600,
            letterSpacing: -0.6,
            color: t.faint,
            fontFamily: tokens.font.display,
            textAlign: "center",
            lineHeight: 1.25,
            marginTop: 10,
          }}
        >
          Your AI research companion.
        </div>
      </div>

      <div style={{ flex: 1 }} />

      {/* auth stack */}
      <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
        {/* Apple — ink pill, icon left of centered label */}
        <Pressable
          scale={0.97}
          onClick={() => {}}
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: 9,
            width: "100%",
            height: 56,
            background: t.ink,
            borderRadius: tokens.radius.full,
          }}
        >
          <Icon name="apple" size={19} color={tokens.color.white} />
          <span style={{ fontSize: 16.5, fontWeight: 600, letterSpacing: -0.2, color: tokens.color.white }}>
            Continue with Apple
          </span>
        </Pressable>

        {/* Email — a text box, not a button; send circle appears when valid */}
        <div
          style={{
            display: "flex",
            alignItems: "center",
            width: "100%",
            height: 56,
            background: sending ? t.surface2 : t.surface,
            border: `1px solid ${sending ? t.surface2 : t.border}`,
            borderRadius: tokens.radius.full,
            padding: "0 6px 0 22px",
            transition: "background .2s, border-color .2s",
          }}
        >
          <input
            type="email"
            inputMode="email"
            autoCapitalize="none"
            autoCorrect="off"
            placeholder="Continue with email"
            value={email}
            disabled={sending}
            onChange={(e) => setEmail(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && onSubmit()}
            style={{
              flex: 1,
              minWidth: 0,
              border: "none",
              outline: "none",
              background: "transparent",
              fontSize: 16.5,
              letterSpacing: -0.2,
              color: t.text,
              fontFamily: tokens.font.ui,
              textAlign: email || sending ? "left" : "center",
            }}
          />
          {(emailValid || sending) && (
            <Pressable
              scale={0.9}
              onClick={onSubmit}
              aria-label="Send code"
              style={{
                width: 44,
                height: 44,
                borderRadius: tokens.radius.full,
                background: t.ink,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                flexShrink: 0,
                animation: "nxFade .2s ease both",
              }}
            >
              {sending ? (
                <Spinner size={16} color={tokens.color.white} />
              ) : (
                <Icon name="arrowUp" size={20} color={tokens.color.white} stroke={2} />
              )}
            </Pressable>
          )}
        </div>

        {error && (
          <div style={{ fontSize: 13, color: tokens.color.error, textAlign: "center", letterSpacing: -0.1 }}>
            {error}
          </div>
        )}
      </div>

      <div style={{ height: 18 }} />
      <Disclaimer />
      <div style={{ height: "max(env(safe-area-inset-bottom), 18px)", flexShrink: 0 }} />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Code entry — bordered card, gray panel, envelope + seal, change email
// ─────────────────────────────────────────────────────────────────────────

function CodeScreen({
  email,
  code,
  setCode,
  verifying,
  error,
  onSubmit,
  onChangeEmail,
}: {
  email: string;
  code: string;
  setCode: (v: string) => void;
  verifying: boolean;
  error: string | null;
  onSubmit: (code: string) => void;
  onChangeEmail: () => void;
}) {
  const submitted = useRef(false);
  const handleChange = (raw: string) => {
    const digits = raw.replace(/\D/g, "").slice(0, 6);
    setCode(digits);
    if (digits.length === 6 && !submitted.current) {
      submitted.current = true;
      onSubmit(digits);
      setTimeout(() => (submitted.current = false), 1500);
    }
  };

  return (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", padding: "0 20px" }}>
      <div style={{ flex: 0.55 }} />

      {/* the card */}
      <div
        style={{
          background: t.surface,
          border: `1px solid ${t.border}`,
          borderRadius: 20,
          padding: "26px 18px 22px",
          display: "flex",
          flexDirection: "column",
          gap: 18,
          animation: "nxFadeRise .3s ease both",
        }}
      >
        <div
          style={{
            fontSize: 18.5,
            fontWeight: 600,
            letterSpacing: -0.4,
            color: t.text,
            textAlign: "center",
            whiteSpace: "nowrap",
            fontFamily: tokens.font.display,
          }}
        >
          Check your email to finish signing in
        </div>

        {/* light purple panel */}
        <div
          style={{
            background: `color-mix(in srgb, ${tokens.color.bloom} 55%, ${tokens.color.white})`,
            borderRadius: 16,
            padding: "18px 16px",
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            gap: 4,
          }}
        >
          <span style={{ fontSize: 14.5, color: t.muted, letterSpacing: -0.1 }}>We sent an email to</span>
          <span style={{ fontSize: 16, fontWeight: 600, letterSpacing: -0.2, color: t.text }}>{email}</span>

          {/* code field */}
          <input
            type="text"
            inputMode="numeric"
            autoComplete="one-time-code"
            autoFocus
            placeholder="Code"
            value={code}
            disabled={verifying}
            onChange={(e) => handleChange(e.target.value)}
            style={{
              width: "100%",
              height: 52,
              margin: "12px 0 0",
              padding: "0 20px",
              fontSize: 17,
              letterSpacing: code ? 6 : -0.2,
              textAlign: "center",
              color: t.text,
              background: t.surface,
              border: `1px solid ${t.border}`,
              borderRadius: tokens.radius.full,
              outline: "none",
              fontFamily: tokens.font.ui,
            }}
          />

          {verifying && (
            <div style={{ display: "flex", alignItems: "center", gap: 8, paddingTop: 10 }}>
              <Spinner size={13} />
              <span style={{ fontSize: 12.5, color: t.muted }}>Verifying…</span>
            </div>
          )}
        </div>

        {error && (
          <div style={{ fontSize: 13, color: tokens.color.error, textAlign: "center", letterSpacing: -0.1 }}>
            {error}
          </div>
        )}

        <Pressable onClick={onChangeEmail} style={{ alignSelf: "center", padding: "2px 10px", borderRadius: 0 }}>
          <span style={{ fontSize: 16, fontWeight: 600, letterSpacing: -0.2, color: t.plum }}>
            Change email address
          </span>
        </Pressable>
      </div>

      <div style={{ flex: 1 }} />
      <Disclaimer />
      <div style={{ height: "max(env(safe-area-inset-bottom), 18px)", flexShrink: 0 }} />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Done + shared disclaimer
// ─────────────────────────────────────────────────────────────────────────

function DoneScreen({ onReset }: { onReset: () => void }) {
  return (
    <div
      style={{
        flex: 1,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        gap: 16,
        padding: 40,
      }}
    >
      <div
        style={{
          width: 64,
          height: 64,
          borderRadius: tokens.radius.full,
          background: tokens.color.bloom,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          animation: "nxPop .44s ease both",
        }}
      >
        <Icon name="check" size={30} color={t.plum} stroke={2.2} />
      </div>
      <div style={{ fontSize: 19, fontWeight: 700, letterSpacing: -0.4, color: t.text }}>You&apos;re in</div>
      <div style={{ fontSize: 13.5, color: t.muted, textAlign: "center", letterSpacing: -0.1 }}>
        Sign-in complete. In the app this lands on the FRE.
      </div>
      <Pressable onClick={onReset} style={{ padding: "8px 14px", borderRadius: 0 }}>
        <span style={{ fontSize: 13.5, fontWeight: 500, color: t.plum }}>Restart flow</span>
      </Pressable>
    </div>
  );
}

// Stub links — real Terms/Privacy pages tracked in PARKING_LOT.md
function Disclaimer() {
  const link: React.CSSProperties = {
    color: t.muted,
    textDecoration: "underline",
    textUnderlineOffset: 2,
  };
  return (
    <div
      style={{
        fontSize: 12.5,
        color: t.faint,
        letterSpacing: -0.1,
        lineHeight: 1.5,
        textAlign: "center",
        padding: "0 14px",
        flexShrink: 0,
      }}
    >
      By continuing, you agree to Nexus&apos;s <a href="#" style={link}>Consumer Terms</a> and{" "}
      <a href="#" style={link}>Usage Policy</a>, and acknowledge their{" "}
      <a href="#" style={link}>Privacy Policy</a>.
    </div>
  );
}
