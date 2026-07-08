"use client";

/**
 * Flows shell — every flow renders inside the MobileFrame with an
 * unobtrusive data-mode badge (tap to toggle mock ↔ live).
 */

import React from "react";
import { usePathname, useRouter } from "next/navigation";
import { MobileFrame } from "../../lib/primitives";
import { useDataMode } from "../../lib/api";
import { t, tokens } from "../../lib/tokens";

export default function FlowsLayout({ children }: { children: React.ReactNode }) {
  const [mode, setMode] = useDataMode();
  const pathname = usePathname();
  const router = useRouter();
  const isIndex = pathname === "/flows";

  return (
    <MobileFrame>
      {children}
      {/* floating chrome: back-to-index + mode badge */}
      <div
        style={{
          position: "absolute",
          top: "max(env(safe-area-inset-top), 12px)",
          right: 10,
          zIndex: 200,
          display: "flex",
          gap: 6,
          alignItems: "center",
        }}
      >
        {!isIndex && (
          <button
            onClick={() => router.push("/flows")}
            style={{
              fontSize: 10.5,
              fontWeight: 600,
              letterSpacing: 0.3,
              color: t.faint,
              background: "rgba(255,255,255,0.72)",
              backdropFilter: "blur(8px)",
              WebkitBackdropFilter: "blur(8px)",
              border: `1px solid ${t.hair}`,
              borderRadius: tokens.radius.full,
              padding: "4px 9px",
              cursor: "pointer",
            }}
          >
            FLOWS
          </button>
        )}
        <button
          onClick={() => setMode(mode === "mock" ? "live" : "mock")}
          style={{
            fontSize: 10.5,
            fontWeight: 700,
            letterSpacing: 0.3,
            color: mode === "live" ? tokens.color.success : t.faint,
            background: "rgba(255,255,255,0.72)",
            backdropFilter: "blur(8px)",
            WebkitBackdropFilter: "blur(8px)",
            border: `1px solid ${mode === "live" ? tokens.color.success : t.hair}`,
            borderRadius: tokens.radius.full,
            padding: "4px 9px",
            cursor: "pointer",
          }}
        >
          {mode === "live" ? "● LIVE" : "MOCK"}
        </button>
      </div>
    </MobileFrame>
  );
}
