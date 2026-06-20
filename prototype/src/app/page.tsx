"use client";

import { useState } from "react";

// ── Echo mark (SVG inline — canonical from logo.jsx) ──
function EchoMark({ size = 40, color = "#7054AB" }: { size?: number; color?: string }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 48 48"
      style={{ display: "block", flexShrink: 0 }}
      aria-hidden="true"
    >
      <g stroke={color} strokeWidth="3" strokeLinecap="round" fill="none">
        <path d="M18.5 16 A11 11 0 0 0 18.5 32" />
        <path d="M29.5 16 A11 11 0 0 1 29.5 32" />
      </g>
      <g stroke={color} strokeWidth="2.2" strokeLinecap="round" fill="none" opacity="0.32">
        <path d="M13.5 9.5 A17.5 17.5 0 0 0 13.5 38.5" />
        <path d="M34.5 9.5 A17.5 17.5 0 0 1 34.5 38.5" />
      </g>
      <circle cx="24" cy="24" r="4.4" fill={color} />
    </svg>
  );
}

// ── Wordmark lockup ──
function NexusLockup() {
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 10,
      }}
    >
      <EchoMark size={32} color="#7054AB" />
      <span
        style={{
          fontFamily: "var(--font-geist-sans), -apple-system, 'Helvetica Neue', sans-serif",
          fontSize: 22,
          fontWeight: 600,
          letterSpacing: "-0.04em",
          color: "#130E1A",
          lineHeight: 1,
        }}
      >
        Nexus
      </span>
    </div>
  );
}

// ── Waitlist form state ──
type FormState = "idle" | "loading" | "success" | "error";

export default function LandingPage() {
  const [email, setEmail] = useState("");
  const [formState, setFormState] = useState<FormState>("idle");
  const [errorMessage, setErrorMessage] = useState("");

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!email.trim() || formState === "loading" || formState === "success") return;

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email.trim())) {
      setErrorMessage("Enter a valid email address.");
      setFormState("error");
      return;
    }

    setFormState("loading");
    setErrorMessage("");

    // POST to /api/waitlist — gracefully degrade to success if not wired
    try {
      const res = await fetch("/api/waitlist", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: email.trim() }),
      });
      if (res.ok) {
        setFormState("success");
      } else {
        const data = await res.json().catch(() => ({}));
        setErrorMessage(data?.message || "Something went wrong. Try again.");
        setFormState("error");
      }
    } catch {
      // In dev/preview without the backend, show success anyway
      setFormState("success");
    }
  }

  return (
    <main
      style={{
        minHeight: "100dvh",
        background: "radial-gradient(135% 60% at 50% -8%, #E7DCF4 0%, #F9F8FC 50%)",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        padding: "24px 20px",
        fontFamily:
          "var(--font-geist-sans), -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif",
        WebkitFontSmoothing: "antialiased",
      }}
    >
      {/* Floating header nav */}
      <header
        style={{
          position: "fixed",
          top: 20,
          left: 0,
          right: 0,
          display: "flex",
          justifyContent: "center",
          zIndex: 10,
          pointerEvents: "none",
        }}
      >
        <div
          style={{
            pointerEvents: "auto",
            padding: "10px 20px",
            borderRadius: 999,
            background: "rgba(255,255,255,0.72)",
            backdropFilter: "blur(16px) saturate(180%)",
            WebkitBackdropFilter: "blur(16px) saturate(180%)",
            border: "1px solid rgba(233,229,242,0.8)",
            boxShadow: "0 2px 16px rgba(19,14,26,0.06)",
          }}
        >
          <NexusLockup />
        </div>
      </header>

      {/* Hero content */}
      <div
        style={{
          width: "100%",
          maxWidth: 480,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          gap: 0,
          marginTop: 0,
        }}
      >
        {/* Echo mark — large, centered */}
        <div
          style={{
            marginBottom: 28,
            opacity: 0.9,
          }}
        >
          <EchoMark size={64} color="#7054AB" />
        </div>

        {/* Headline */}
        <h1
          style={{
            margin: 0,
            fontSize: "clamp(32px, 8vw, 48px)",
            fontWeight: 700,
            letterSpacing: "-0.04em",
            lineHeight: 1.08,
            color: "#130E1A",
            textAlign: "center",
            textWrap: "balance",
          }}
        >
          Think, don&apos;t just save.
        </h1>

        {/* Sub-headline */}
        <p
          style={{
            margin: "16px 0 0",
            fontSize: 17,
            fontWeight: 400,
            lineHeight: 1.55,
            color: "#68607A",
            textAlign: "center",
            textWrap: "balance",
            maxWidth: 340,
          }}
        >
          Nexus is an AI-native curation platform — it reads everything you save and helps you actually understand it.
        </p>

        {/* Waitlist box */}
        <div
          style={{
            marginTop: 40,
            width: "100%",
            background: "#FFFFFF",
            borderRadius: 20,
            border: "1px solid #E9E5F2",
            boxShadow:
              "0 1px 2px rgba(19,14,26,0.04), 0 8px 32px rgba(19,14,26,0.06)",
            padding: "28px 24px",
          }}
        >
          {formState === "success" ? (
            <div
              style={{
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                gap: 12,
                padding: "8px 0",
              }}
            >
              {/* Checkmark icon */}
              <div
                style={{
                  width: 44,
                  height: 44,
                  borderRadius: 999,
                  background: "rgba(112,84,171,0.10)",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                }}
              >
                <svg
                  width={22}
                  height={22}
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="#7054AB"
                  strokeWidth={2}
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <path d="m5 12.5 4.5 4.5L19 7" />
                </svg>
              </div>
              <p
                style={{
                  margin: 0,
                  fontSize: 16,
                  fontWeight: 600,
                  color: "#130E1A",
                  textAlign: "center",
                  letterSpacing: "-0.02em",
                }}
              >
                You&apos;re on the list.
              </p>
              <p
                style={{
                  margin: 0,
                  fontSize: 14,
                  color: "#68607A",
                  textAlign: "center",
                  lineHeight: 1.5,
                }}
              >
                We&apos;ll reach out when early access opens.
              </p>
            </div>
          ) : (
            <form onSubmit={handleSubmit} noValidate>
              <label
                htmlFor="email"
                style={{
                  display: "block",
                  fontSize: 13,
                  fontWeight: 600,
                  letterSpacing: "0.04em",
                  textTransform: "uppercase",
                  color: "#9A93AC",
                  marginBottom: 10,
                }}
              >
                Get early access
              </label>

              {/* Email input */}
              <div
                style={{
                  display: "flex",
                  gap: 8,
                  flexWrap: "wrap",
                }}
              >
                <input
                  id="email"
                  type="email"
                  placeholder="your@email.com"
                  value={email}
                  onChange={(e) => {
                    setEmail(e.target.value);
                    if (formState === "error") setFormState("idle");
                  }}
                  disabled={formState === "loading"}
                  autoComplete="email"
                  inputMode="email"
                  style={{
                    flex: "1 1 180px",
                    height: 46,
                    padding: "0 14px",
                    borderRadius: 12,
                    border: `1px solid ${formState === "error" ? "#DC2626" : "#E9E5F2"}`,
                    background: "#FBFAFD",
                    fontSize: 15,
                    color: "#130E1A",
                    outline: "none",
                    fontFamily: "inherit",
                    transition: "border-color 0.15s",
                  }}
                  onFocus={(e) => {
                    e.target.style.borderColor = "#DCD7EA";
                  }}
                  onBlur={(e) => {
                    e.target.style.borderColor =
                      formState === "error" ? "#DC2626" : "#E9E5F2";
                  }}
                />
                <button
                  type="submit"
                  disabled={formState === "loading" || !email.trim()}
                  style={{
                    height: 46,
                    padding: "0 22px",
                    borderRadius: 12,
                    border: "none",
                    background:
                      formState === "loading" || !email.trim()
                        ? "#DCD7EA"
                        : "#7054AB",
                    color:
                      formState === "loading" || !email.trim()
                        ? "#9A93AC"
                        : "#FFFFFF",
                    fontSize: 15,
                    fontWeight: 600,
                    letterSpacing: "-0.02em",
                    cursor:
                      formState === "loading" || !email.trim()
                        ? "not-allowed"
                        : "pointer",
                    transition: "background 0.15s, color 0.15s",
                    fontFamily: "inherit",
                    flexShrink: 0,
                    display: "flex",
                    alignItems: "center",
                    gap: 8,
                  }}
                >
                  {formState === "loading" ? (
                    <>
                      <SpinnerIcon />
                      Joining...
                    </>
                  ) : (
                    "Join waitlist"
                  )}
                </button>
              </div>

              {/* Error message */}
              {formState === "error" && errorMessage && (
                <p
                  style={{
                    margin: "8px 0 0",
                    fontSize: 13,
                    color: "#DC2626",
                    lineHeight: 1.4,
                  }}
                >
                  {errorMessage}
                </p>
              )}

              <p
                style={{
                  margin: "14px 0 0",
                  fontSize: 12,
                  color: "#B7B1C4",
                  lineHeight: 1.4,
                }}
              >
                iPhone launch first. No spam, unsubscribe any time.
              </p>
            </form>
          )}
        </div>

        {/* Platform badge */}
        <div
          style={{
            marginTop: 24,
            display: "flex",
            alignItems: "center",
            gap: 6,
          }}
        >
          <svg
            width={16}
            height={16}
            viewBox="0 0 24 24"
            fill="none"
            aria-hidden="true"
          >
            <rect
              x="5"
              y="2"
              width="14"
              height="20"
              rx="3"
              stroke="#B7B1C4"
              strokeWidth="1.6"
            />
            <circle cx="12" cy="18.5" r="1.2" fill="#B7B1C4" />
          </svg>
          <span
            style={{
              fontSize: 12,
              color: "#B7B1C4",
              letterSpacing: "0.01em",
            }}
          >
            Coming to iPhone
          </span>
        </div>
      </div>

      {/* Footer */}
      <footer
        style={{
          position: "fixed",
          bottom: 20,
          left: 0,
          right: 0,
          display: "flex",
          justifyContent: "center",
        }}
      >
        <span style={{ fontSize: 12, color: "#B7B1C4" }}>
          &copy; {new Date().getFullYear()} Nexus
        </span>
      </footer>
    </main>
  );
}

// ── Spinner icon ──
function SpinnerIcon() {
  return (
    <svg
      width={14}
      height={14}
      viewBox="0 0 24 24"
      fill="none"
      style={{ animation: "spin 0.8s linear infinite" }}
      aria-hidden="true"
    >
      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
      <circle
        cx="12"
        cy="12"
        r="9"
        stroke="currentColor"
        strokeWidth="2.5"
        strokeDasharray="28 14"
        strokeLinecap="round"
      />
    </svg>
  );
}
