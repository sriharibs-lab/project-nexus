"use client";

import React from "react";
import { EchoMark } from "../../../lib/logo";
import { Screen, StatusBar } from "../../../lib/primitives";
import { t } from "../../../lib/tokens";

export function FlowStub({ title, next }: { title: string; next?: string }) {
  return (
    <Screen>
      <StatusBar />
      <div
        style={{
          flex: 1,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          gap: 14,
          padding: 32,
          textAlign: "center",
        }}
      >
        <EchoMark size={40} color={t.ghost} />
        <div style={{ fontSize: 17, fontWeight: 600, letterSpacing: -0.3, color: t.muted }}>{title}</div>
        <div style={{ fontSize: 13, color: t.faint, letterSpacing: -0.1, lineHeight: 1.5 }}>
          {next ?? "Coming in the next build batch."}
        </div>
      </div>
    </Screen>
  );
}
