"use client";

/**
 * Login flow — 3 design variants, one shared state machine.
 *   A — iOS AuthView today: Notion-style bordered option rows, inline email expand
 *   B — Composer-style: FRE visual language, one big email field, plum CTA
 *   C — Minimal: mark + two quiet buttons, maximal whitespace
 *
 * Variant pill floats at the top; ?v=a|b|c is kept in the URL so
 * "I like B" is a copyable link. Apple button is visual-only.
 * MOCK mode: any 6-digit code works. LIVE mode: real OTP email via backend.
 */

import React, { useEffect, useRef, useState } from "react";
import { getClient } from "../../../lib/api";
import { Icon } from "../../../lib/icons";
import { EchoMark } from "../../../lib/logo";
import { Pressable, Screen, Segmented, Spinner, StatusBar } from "../../../lib/primitives";
import { t, tokens } from "../../../lib/tokens";

type Phase =
  | { k: "idle" }
  | { k: "email" }
  | { k: "sending" }
  | { k: "otp"; email: string }
  | { k: "verifying"; email: string }
  | { k: "done" }
  | { k: "error"; message: string; back: Phase };

type VariantKey = "A" | "B" | "C";

export default function LoginFlow() {
  const [variant, setVariant] = useState<VariantKey>("A");
  const [phase, setPhase] = useState<Phase>({ k: "idle" });
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");

  // ?v= sync (copyable variant links) without useSearchParams/Suspense
  useEffect(() => {
    const v = new URLSearchParams(window.location.search).get("v")?.toUpperCase();
    if (v === "A" || v === "B" || v === "C") setVariant(v);
  }, []);
  const pickVariant = (v: string) => {
    const key = v as VariantKey;
    setVariant(key);
    const url = new URL(window.location.href);
    url.searchParams.set("v", key.toLowerCase());
    window.history.replaceState(null, "", url.toString());
    // variant switch resets the walkthrough
    setPhase({ k: "idle" });
    setEmail("");
    setCode("");
  };

  const submitEmail = async (value: string) => {
    const trimmed = value.trim();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]{2,}$/.test(trimmed)) {
      setPhase({ k: "error", message: "Enter a valid email address.", back: { k: "email" } });
      return;
    }
    setPhase({ k: "sending" });
    try {
      await getClient().requestOtp(trimmed);
      setCode("");
      setPhase({ k: "otp", email: trimmed });
    } catch (err) {
      setPhase({ k: "error", message: (err as Error).message, back: { k: "email" } });
    }
  };

  const submitCode = async (value: string) => {
    const em = phase.k === "otp" || phase.k === "verifying" ? phase.email : email;
    setPhase({ k: "verifying", email: em });
    try {
      await getClient().verifyOtp(em, value.trim());
      setPhase({ k: "done" });
    } catch (err) {
      setPhase({ k: "error", message: (err as Error).message, back: { k: "otp", email: em } });
    }
  };

  const shared = { phase, setPhase, email, setEmail, submitEmail };

  return (
    <Screen>
      <StatusBar />

      {/* variant switcher */}
      <div style={{ display: "flex", justifyContent: "center", padding: "6px 0 0", flexShrink: 0 }}>
        <Segmented compact items={["A", "B", "C"]} value={variant} onChange={pickVariant} />
      </div>

      {phase.k === "otp" || phase.k === "verifying" ? (
        <OTPScreen
          email={phase.email}
          code={code}
          setCode={setCode}
          verifying={phase.k === "verifying"}
          onSubmit={submitCode}
          onCancel={() => {
            setPhase({ k: "idle" });
            setCode("");
          }}
          onResend={() => submitEmail(phase.email)}
        />
      ) : phase.k === "done" ? (
        <DoneScreen onReset={() => { setPhase({ k: "idle" }); setEmail(""); setCode(""); }} />
      ) : variant === "A" ? (
        <VariantA {...shared} />
      ) : variant === "B" ? (
        <VariantB {...shared} />
      ) : (
        <VariantC {...shared} />
      )}

      {/* error banner */}
      {phase.k === "error" && (
        <div
          style={{
            position: "absolute",
            left: 20,
            right: 20,
            bottom: "max(env(safe-area-inset-bottom), 24px)",
            display: "flex",
            alignItems: "center",
            gap: 10,
            padding: "12px 14px",
            background: t.surface,
            border: `1px solid ${tokens.color.error}`,
            borderRadius: tokens.radius.base,
            boxShadow: tokens.shadow.md,
            zIndex: 100,
          }}
        >
          <span style={{ fontSize: 13, color: tokens.color.error, flex: 1, letterSpacing: -0.1 }}>
            {phase.message}
          </span>
          <Pressable onClick={() => setPhase(phase.back)} style={{ borderRadius: 0 }}>
            <Icon name="x" size={14} color={t.faint} />
          </Pressable>
        </div>
      )}
    </Screen>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Shared pieces
// ─────────────────────────────────────────────────────────────────────────

interface VariantProps {
  phase: Phase;
  setPhase: (p: Phase) => void;
  email: string;
  setEmail: (v: string) => void;
  submitEmail: (v: string) => void;
}

function LogoBlock({ tagline = true, size = 52 }: { tagline?: boolean; size?: number }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 14 }}>
      <EchoMark size={size} />
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 6 }}>
        <span style={{ fontSize: 26, fontWeight: 700, letterSpacing: -0.6, color: t.text, fontFamily: tokens.font.display }}>
          Nexus
        </span>
        {tagline && (
          <span style={{ fontSize: 14.5, color: t.muted, letterSpacing: -0.1 }}>Your AI research companion</span>
        )}
      </div>
    </div>
  );
}

/** Notion-style bordered option row — 52pt, icon in fixed left slot, centered label. */
function AuthOptionRow({
  icon,
  label,
  loading = false,
  onClick,
}: {
  icon: "apple" | "envelope";
  label: string;
  loading?: boolean;
  onClick?: () => void;
}) {
  return (
    <Pressable
      scale={0.97}
      onClick={onClick}
      style={{
        display: "flex",
        alignItems: "center",
        width: "100%",
        height: 52,
        background: t.surface,
        border: `1px solid ${t.borderStrong}`,
        borderRadius: 12,
      }}
    >
      {loading ? (
        <div style={{ flex: 1, display: "flex", justifyContent: "center" }}>
          <Spinner color={t.ink} />
        </div>
      ) : (
        <>
          <div style={{ width: 52, display: "flex", justifyContent: "center", flexShrink: 0 }}>
            <Icon name={icon} size={icon === "apple" ? 20 : 17} color={t.ink} />
          </div>
          <span style={{ flex: 1, textAlign: "center", fontSize: 16.5, fontWeight: 400, letterSpacing: -0.2, color: t.text }}>
            {label}
          </span>
          <div style={{ width: 52, flexShrink: 0 }} />
        </>
      )}
    </Pressable>
  );
}

function EmailInput({
  value,
  onChange,
  onSubmit,
  autoFocus = true,
  placeholder = "your@email.com",
}: {
  value: string;
  onChange: (v: string) => void;
  onSubmit: () => void;
  autoFocus?: boolean;
  placeholder?: string;
}) {
  const [focused, setFocused] = useState(false);
  return (
    <input
      type="email"
      inputMode="email"
      autoCapitalize="none"
      autoCorrect="off"
      autoFocus={autoFocus}
      placeholder={placeholder}
      value={value}
      onChange={(e) => onChange(e.target.value)}
      onFocus={() => setFocused(true)}
      onBlur={() => setFocused(false)}
      onKeyDown={(e) => e.key === "Enter" && onSubmit()}
      style={{
        width: "100%",
        height: 52,
        padding: "0 16px",
        fontSize: 16.5,
        letterSpacing: -0.2,
        color: t.text,
        background: t.surface,
        border: `1px solid ${focused ? t.plum : t.borderStrong}`,
        borderRadius: 12,
        outline: "none",
        fontFamily: tokens.font.ui,
        boxShadow: focused ? tokens.shadow.focus : "none",
        transition: "border-color .15s, box-shadow .15s",
      }}
    />
  );
}

function PrimaryButton({
  label,
  loading = false,
  onClick,
  background = t.ink,
}: {
  label: string;
  loading?: boolean;
  onClick?: () => void;
  background?: string;
}) {
  return (
    <Pressable
      scale={0.97}
      onClick={onClick}
      style={{
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        width: "100%",
        height: 52,
        background,
        borderRadius: 12,
      }}
    >
      {loading ? (
        <Spinner color={tokens.color.white} />
      ) : (
        <span style={{ fontSize: 16.5, fontWeight: 500, letterSpacing: -0.2, color: tokens.color.white }}>{label}</span>
      )}
    </Pressable>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Variant A — iOS AuthView today (Notion-style rows, inline email expand)
// ─────────────────────────────────────────────────────────────────────────

function VariantA({ phase, setPhase, email, setEmail, submitEmail }: VariantProps) {
  const emailOpen = phase.k === "email" || phase.k === "sending";
  return (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", padding: "0 26px" }}>
      <div style={{ flex: 1.2 }} />
      <LogoBlock />
      <div style={{ flex: 2 }} />

      <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
        <span style={{ fontSize: 14.5, fontWeight: 600, letterSpacing: -0.2, color: t.text }}>
          Log in to your Nexus account
        </span>

        {!emailOpen && <AuthOptionRow icon="apple" label="Sign in with Apple" onClick={() => {}} />}

        {emailOpen ? (
          <div style={{ display: "flex", flexDirection: "column", gap: 10, animation: "nxFadeRise .3s ease both" }}>
            <EmailInput value={email} onChange={setEmail} onSubmit={() => submitEmail(email)} />
            <PrimaryButton label="Continue" loading={phase.k === "sending"} onClick={() => submitEmail(email)} />
            <Pressable
              onClick={() => setPhase({ k: "idle" })}
              style={{ alignSelf: "center", padding: "4px 10px", borderRadius: 0 }}
            >
              <span style={{ fontSize: 13.5, color: t.muted }}>Cancel</span>
            </Pressable>
          </div>
        ) : (
          <AuthOptionRow icon="envelope" label="Continue with email" onClick={() => setPhase({ k: "email" })} />
        )}

        {!emailOpen && (
          <div style={{ display: "flex", justifyContent: "center", gap: 4, paddingTop: 2 }}>
            <span style={{ fontSize: 13.5, color: t.muted }}>New user?</span>
            <span style={{ fontSize: 13.5, fontWeight: 500, color: t.plum, cursor: "pointer" }} onClick={() => setPhase({ k: "email" })}>
              Sign up
            </span>
          </div>
        )}
      </div>
      <div style={{ height: "max(env(safe-area-inset-bottom), 24px)", flexShrink: 0 }} />
      <div style={{ height: 24, flexShrink: 0 }} />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Variant B — composer-style: FRE language, one field is the hero
// ─────────────────────────────────────────────────────────────────────────

function VariantB({ phase, email, setEmail, submitEmail }: VariantProps) {
  const sending = phase.k === "sending";
  return (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", padding: "0 24px" }}>
      <div style={{ flex: 1 }} />
      <EchoMark size={44} />
      <div style={{ height: 22 }} />
      <div style={{ fontSize: 30, fontWeight: 700, letterSpacing: -0.8, color: t.text, lineHeight: 1.15 }}>
        Think, don&apos;t
        <br />
        just save.
      </div>
      <div style={{ fontSize: 15, color: t.muted, letterSpacing: -0.1, marginTop: 10, lineHeight: 1.45 }}>
        Enter your email — we&apos;ll send a code.
        <br />
        No passwords, ever.
      </div>

      <div style={{ height: 28 }} />

      {/* composer-style card */}
      <div
        style={{
          background: t.surface,
          borderRadius: 22,
          border: `1px solid ${t.borderStrong}`,
          boxShadow: `0 0 0 3px ${t.surface2}`,
          padding: "6px 6px 6px 16px",
          display: "flex",
          alignItems: "center",
          gap: 8,
        }}
      >
        <input
          type="email"
          inputMode="email"
          autoCapitalize="none"
          autoCorrect="off"
          placeholder="your@email.com"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && submitEmail(email)}
          style={{
            flex: 1,
            minWidth: 0,
            border: "none",
            outline: "none",
            fontSize: 16.5,
            letterSpacing: -0.2,
            color: t.text,
            background: "transparent",
            fontFamily: tokens.font.ui,
            height: 44,
          }}
        />
        <Pressable
          scale={0.9}
          onClick={() => submitEmail(email)}
          style={{
            width: 40,
            height: 40,
            borderRadius: tokens.radius.full,
            background: email.trim() ? t.plum : t.surface2,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            flexShrink: 0,
            transition: "background .2s",
          }}
        >
          {sending ? (
            <Spinner size={15} color={tokens.color.white} />
          ) : (
            <Icon name="arrowUp" size={19} color={email.trim() ? tokens.color.white : t.faint} stroke={2} />
          )}
        </Pressable>
      </div>

      <div style={{ display: "flex", alignItems: "center", gap: 10, marginTop: 22 }}>
        <div style={{ flex: 1, height: 1, background: t.hair }} />
        <span style={{ fontSize: 11.5, color: t.ghost, letterSpacing: 0.3 }}>OR</span>
        <div style={{ flex: 1, height: 1, background: t.hair }} />
      </div>

      <Pressable
        scale={0.97}
        onClick={() => {}}
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          gap: 8,
          height: 46,
          marginTop: 16,
          borderRadius: 12,
          background: "transparent",
          border: `1px solid ${t.border}`,
        }}
      >
        <Icon name="apple" size={17} color={t.text} />
        <span style={{ fontSize: 15, fontWeight: 500, letterSpacing: -0.2, color: t.text }}>Sign in with Apple</span>
      </Pressable>

      <div style={{ flex: 1.4 }} />
      <div style={{ height: "max(env(safe-area-inset-bottom), 20px)", flexShrink: 0 }} />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Variant C — minimal: mark + two quiet buttons, maximal whitespace
// ─────────────────────────────────────────────────────────────────────────

function VariantC({ phase, setPhase, email, setEmail, submitEmail }: VariantProps) {
  const emailOpen = phase.k === "email" || phase.k === "sending";
  return (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", padding: "0 40px" }}>
      <div style={{ flex: 1.6 }} />
      <LogoBlock tagline={false} size={60} />
      <div style={{ flex: 1 }} />

      {emailOpen ? (
        <div style={{ width: "100%", display: "flex", flexDirection: "column", gap: 10, animation: "nxFadeRise .3s ease both" }}>
          <EmailInput value={email} onChange={setEmail} onSubmit={() => submitEmail(email)} />
          <PrimaryButton label="Send code" loading={phase.k === "sending"} onClick={() => submitEmail(email)} background={t.plum} />
          <Pressable onClick={() => setPhase({ k: "idle" })} style={{ alignSelf: "center", padding: "6px 10px", borderRadius: 0 }}>
            <span style={{ fontSize: 13.5, color: t.muted }}>Back</span>
          </Pressable>
        </div>
      ) : (
        <div style={{ width: "100%", display: "flex", flexDirection: "column", gap: 10 }}>
          <PrimaryButton label=" Continue with Apple" onClick={() => {}} />
          <Pressable
            scale={0.97}
            onClick={() => setPhase({ k: "email" })}
            style={{
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              width: "100%",
              height: 52,
              background: "transparent",
              border: `1px solid ${t.borderStrong}`,
              borderRadius: 12,
            }}
          >
            <span style={{ fontSize: 16.5, fontWeight: 500, letterSpacing: -0.2, color: t.text }}>Continue with email</span>
          </Pressable>
        </div>
      )}

      <div style={{ flex: 1.6 }} />
      <span style={{ fontSize: 12, color: t.ghost, letterSpacing: -0.1, paddingBottom: 12 }}>
        Privacy-first. No ads, ever.
      </span>
      <div style={{ height: "max(env(safe-area-inset-bottom), 16px)", flexShrink: 0 }} />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// OTP entry — shared across variants (post-choice, one design)
// ─────────────────────────────────────────────────────────────────────────

function OTPScreen({
  email,
  code,
  setCode,
  verifying,
  onSubmit,
  onCancel,
  onResend,
}: {
  email: string;
  code: string;
  setCode: (v: string) => void;
  verifying: boolean;
  onSubmit: (code: string) => void;
  onCancel: () => void;
  onResend: () => void;
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
    <div style={{ flex: 1, display: "flex", flexDirection: "column", padding: "0 26px" }}>
      <div style={{ flex: 1 }} />
      <LogoBlock tagline={false} size={44} />
      <div style={{ flex: 0.8 }} />

      <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
        <span style={{ fontSize: 17, fontWeight: 600, letterSpacing: -0.3, color: t.text }}>Check your email</span>
        <span style={{ fontSize: 13.5, color: t.muted, letterSpacing: -0.1 }}>
          We sent a 6-digit code to {email}
        </span>
      </div>

      <div style={{ height: 18 }} />

      <input
        type="text"
        inputMode="numeric"
        autoComplete="one-time-code"
        autoFocus
        placeholder="000000"
        value={code}
        onChange={(e) => handleChange(e.target.value)}
        style={{
          width: "100%",
          height: 58,
          padding: "0 16px",
          fontSize: 26,
          fontWeight: 600,
          letterSpacing: 10,
          textAlign: "center",
          color: t.text,
          background: t.surface,
          border: `1px solid ${t.borderStrong}`,
          borderRadius: 12,
          outline: "none",
          fontFamily: tokens.font.ui,
        }}
      />

      <div style={{ height: 12 }} />
      <PrimaryButton label="Verify" loading={verifying} onClick={() => onSubmit(code)} />

      <div style={{ display: "flex", justifyContent: "space-between", paddingTop: 16 }}>
        <span style={{ fontSize: 13.5, fontWeight: 500, color: t.plum, cursor: "pointer" }} onClick={onResend}>
          Resend code
        </span>
        <span style={{ fontSize: 13.5, color: t.muted, cursor: "pointer" }} onClick={onCancel}>
          Cancel
        </span>
      </div>

      <div style={{ flex: 2 }} />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Done — sign-in success confirmation
// ─────────────────────────────────────────────────────────────────────────

function DoneScreen({ onReset }: { onReset: () => void }) {
  return (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 16, padding: 40 }}>
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
