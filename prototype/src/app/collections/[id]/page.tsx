"use client";

/**
 * Collection detail — landing redirects to the Nexus tab (SPEC §5a default).
 * Renders a tab shell with Nexus (default) / Sources tabs.
 * The Nexus tab is the hero — AI agent first, sources secondary.
 */

import React, { useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { tokens } from "../../../lib/tokens";
import {
  Icon,
  Pressable,
  MobileFrame,
  StatusBar,
  PillTabs,
} from "../../../lib/components";
import { getCollection } from "../../../lib/mock-data";
import NexusTab from "./nexus/NexusTab";
import SourcesTab from "./sources/SourcesTab";

const t = tokens.color;

export default function CollectionPage() {
  const { id } = useParams<{ id: string }>();
  const collection = getCollection(id);
  const [activeTab, setActiveTab] = useState<"Nexus" | "Sources">("Nexus");

  if (!collection) {
    return (
      <MobileFrame>
        <div
          style={{
            height: "100%",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            background: t.page,
            fontFamily: tokens.font.sans,
          }}
        >
          <div style={{ textAlign: "center", color: t.muted, fontSize: 15 }}>
            Collection not found
          </div>
        </div>
      </MobileFrame>
    );
  }

  return (
    <MobileFrame>
      <div
        style={{
          height: "100%",
          background: t.page,
          display: "flex",
          flexDirection: "column",
          overflow: "hidden",
          fontFamily: tokens.font.sans,
        }}
      >
        <StatusBar />

        {/* Collection header */}
        <div
          style={{
            padding: "4px 14px 10px",
            flexShrink: 0,
          }}
        >
          {/* Back + actions row */}
          <div
            style={{
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
              marginBottom: 10,
            }}
          >
            <Link href="/" style={{ textDecoration: "none" }}>
              <Pressable
                scale={0.88}
                style={{
                  display: "inline-flex",
                  alignItems: "center",
                  gap: 4,
                  padding: "6px 10px 6px 6px",
                  borderRadius: 999,
                  background: t.surface,
                  border: `1px solid ${t.border}`,
                  color: t.ink,
                  fontSize: 14,
                  fontWeight: 500,
                  letterSpacing: -0.1,
                  fontFamily: tokens.font.sans,
                }}
              >
                <Icon name="chevLeft" size={16} color={t.muted} />
                Collections
              </Pressable>
            </Link>
            <Pressable
              scale={0.88}
              style={{
                width: 32,
                height: 32,
                borderRadius: 999,
                background: t.surface,
                border: `1px solid ${t.border}`,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
              }}
            >
              <Icon name="layers" size={16} color={t.muted} />
            </Pressable>
          </div>

          {/* Collection title */}
          <div
            style={{
              fontSize: 22,
              fontWeight: 700,
              letterSpacing: -0.5,
              color: t.ink,
              lineHeight: 1.2,
              marginBottom: 6,
              fontFamily: tokens.font.display,
            }}
          >
            {collection.name}
          </div>

          {/* Source count */}
          <div
            style={{
              fontSize: 13.5,
              color: t.faint,
              letterSpacing: -0.1,
              marginBottom: 14,
            }}
          >
            {collection.source_count}{" "}
            {collection.source_count === 1 ? "source" : "sources"}
          </div>

          {/* Tab switcher */}
          <PillTabs
            tabs={["Nexus", "Sources"]}
            active={activeTab}
            onChange={(tab) => setActiveTab(tab as "Nexus" | "Sources")}
            accent={t.plum}
          />
        </div>

        {/* Tab content */}
        <div
          style={{
            flex: 1,
            minHeight: 0,
            position: "relative",
            overflow: "hidden",
          }}
        >
          {/* Nexus tab */}
          <div
            style={{
              position: "absolute",
              inset: 0,
              opacity: activeTab === "Nexus" ? 1 : 0,
              pointerEvents: activeTab === "Nexus" ? "auto" : "none",
              transition: "opacity 0.22s cubic-bezier(.2,.8,.2,1)",
            }}
          >
            <NexusTab collection={collection} />
          </div>

          {/* Sources tab */}
          <div
            style={{
              position: "absolute",
              inset: 0,
              opacity: activeTab === "Sources" ? 1 : 0,
              pointerEvents: activeTab === "Sources" ? "auto" : "none",
              transition: "opacity 0.22s cubic-bezier(.2,.8,.2,1)",
            }}
          >
            <SourcesTab collection={collection} />
          </div>
        </div>
      </div>
    </MobileFrame>
  );
}
