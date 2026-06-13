"use client";

/**
 * Home screen — Collections list.
 *
 * SPEC §5a: Collections are the root. No global library.
 * Layout: Recent / All pivots (header) → collection cards list → New Collection CTA.
 * source_count is displayed from the denormalized field (never a COUNT query).
 */

import React, { useState } from "react";
import Link from "next/link";
import { tokens } from "../lib/tokens";
import {
  Icon,
  Pressable,
  Avatar,
  MobileFrame,
  StatusBar,
  BottomTabBar,
} from "../lib/components";
import { MOCK_COLLECTIONS, relativeTime, type Collection } from "../lib/mock-data";

const t = tokens.color;

// ── Pivot tabs (Recent / All) ──

function PivotButton({
  label,
  active,
  onClick,
}: {
  label: string;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <Pressable
      onClick={onClick}
      scale={0.96}
      style={{
        fontSize: 19,
        fontWeight: active ? 700 : 600,
        letterSpacing: -0.4,
        color: active ? t.ink : t.faint,
        padding: "8px 14px",
        borderRadius: 999,
        background: active ? t.surface2 : "transparent",
        transition: "background 0.15s, color 0.15s",
        fontFamily: tokens.font.display,
      }}
    >
      {label}
    </Pressable>
  );
}

// ── Collection card ──

function CollectionCard({ collection }: { collection: Collection }) {
  const hasAi = !!collection.ai_framing;
  const processingCount = collection.sources.filter(
    (s) => s.ingest_status === "processing" || s.ingest_status === "pending"
  ).length;

  return (
    <Link href={`/collections/${collection.id}`} style={{ textDecoration: "none" }}>
      <Pressable
        scale={0.985}
        style={{
          display: "block",
          width: "100%",
          background: t.surface,
          borderRadius: 20,
          border: `1px solid ${t.border}`,
          padding: "16px 16px 14px",
          textAlign: "left",
          marginBottom: 10,
          boxShadow: "0 1px 4px rgba(19,14,26,0.04)",
          animation: "nxFade 0.3s cubic-bezier(.2,.8,.2,1) both",
        }}
      >
        {/* Title row */}
        <div
          style={{
            display: "flex",
            alignItems: "flex-start",
            justifyContent: "space-between",
            gap: 8,
            marginBottom: 6,
          }}
        >
          <div
            style={{
              fontSize: 16,
              fontWeight: 700,
              letterSpacing: -0.3,
              color: t.ink,
              lineHeight: 1.3,
              flex: 1,
              minWidth: 0,
            }}
          >
            {collection.name}
          </div>
          <Icon name="chevRight" size={16} color={t.ghost} />
        </div>

        {/* Description */}
        {collection.description && (
          <div
            style={{
              fontSize: 13.5,
              color: t.muted,
              lineHeight: 1.4,
              letterSpacing: -0.1,
              marginBottom: 12,
              overflow: "hidden",
              display: "-webkit-box",
              WebkitLineClamp: 2,
              WebkitBoxOrient: "vertical",
            }}
          >
            {collection.description}
          </div>
        )}

        {/* Meta row: source count + AI indicator + time */}
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 10,
          }}
        >
          {/* Source count badge */}
          <div
            style={{
              display: "inline-flex",
              alignItems: "center",
              gap: 5,
              padding: "3px 9px",
              borderRadius: 999,
              background: t.surface2,
              border: `1px solid ${t.hair}`,
            }}
          >
            <Icon name="layers" size={12} color={t.muted} />
            <span
              style={{
                fontSize: 12.5,
                fontWeight: 600,
                color: t.muted,
                letterSpacing: -0.1,
              }}
            >
              {collection.source_count} {collection.source_count === 1 ? "source" : "sources"}
            </span>
          </div>

          {/* AI-ready indicator */}
          {hasAi && (
            <div
              style={{
                display: "inline-flex",
                alignItems: "center",
                gap: 4,
                padding: "3px 9px",
                borderRadius: 999,
                background: `${t.plum}14`,
                border: `1px solid ${t.plum}30`,
              }}
            >
              <Icon name="nexus" size={12} color={t.plum} />
              <span
                style={{
                  fontSize: 12.5,
                  fontWeight: 600,
                  color: t.plum,
                  letterSpacing: -0.1,
                }}
              >
                Nexus ready
              </span>
            </div>
          )}

          {/* Processing indicator */}
          {processingCount > 0 && (
            <div
              style={{
                display: "inline-flex",
                alignItems: "center",
                gap: 4,
                padding: "3px 9px",
                borderRadius: 999,
                background: t.surface2,
                border: `1px solid ${t.hair}`,
              }}
            >
              <div
                style={{
                  width: 7,
                  height: 7,
                  borderRadius: 999,
                  border: `1.5px solid ${t.ghost}`,
                  borderTopColor: t.muted,
                  animation: "nxSpin 0.8s linear infinite",
                  flexShrink: 0,
                }}
              />
              <span style={{ fontSize: 12.5, color: t.faint, letterSpacing: -0.1 }}>
                {processingCount} reading
              </span>
            </div>
          )}

          <div style={{ flex: 1 }} />

          <span style={{ fontSize: 12, color: t.ghost, letterSpacing: -0.1 }}>
            {relativeTime(collection.created_at)}
          </span>
        </div>
      </Pressable>
    </Link>
  );
}

// ── New Collection CTA button ──

function NewCollectionButton() {
  return (
    <Link href="/collections/new" style={{ textDecoration: "none" }}>
      <Pressable
        scale={0.97}
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          gap: 8,
          width: "100%",
          height: 50,
          borderRadius: 999,
          background: t.ink,
          color: t.white,
          fontFamily: tokens.font.sans,
          fontSize: 15.5,
          fontWeight: 600,
          letterSpacing: -0.2,
          border: "none",
          marginTop: 4,
        }}
      >
        <Icon name="plus" size={18} color={t.white} stroke={2} />
        New Collection
      </Pressable>
    </Link>
  );
}

// ── Main Home screen ──

export default function HomePage() {
  const [pivot, setPivot] = useState<"Recent" | "All">("Recent");

  const collections = pivot === "Recent"
    ? [...MOCK_COLLECTIONS].sort(
        (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
      )
    : MOCK_COLLECTIONS;

  return (
    <MobileFrame>
      {/* Full-screen page with bloom background */}
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

        {/* Header */}
        <div style={{ padding: "4px 14px 0", flexShrink: 0 }}>
          <div
            style={{
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
            }}
          >
            <div style={{ display: "flex", gap: 2 }}>
              <PivotButton
                label="Recent"
                active={pivot === "Recent"}
                onClick={() => setPivot("Recent")}
              />
              <PivotButton
                label="All"
                active={pivot === "All"}
                onClick={() => setPivot("All")}
              />
            </div>
            <Pressable scale={0.9} style={{ borderRadius: 999 }}>
              <Avatar initials="S" />
            </Pressable>
          </div>
        </div>

        {/* Collections list */}
        <div
          style={{
            flex: 1,
            minHeight: 0,
            overflowY: "auto",
            padding: "14px 16px 100px",
          }}
        >
          {collections.map((col) => (
            <CollectionCard key={col.id} collection={col} />
          ))}

          {/* Empty state */}
          {collections.length === 0 && (
            <div
              style={{
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                justifyContent: "center",
                paddingTop: 80,
                gap: 12,
              }}
            >
              <div
                style={{
                  width: 56,
                  height: 56,
                  borderRadius: 18,
                  background: t.surface2,
                  border: `1px solid ${t.border}`,
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                }}
              >
                <Icon name="layers" size={26} color={t.ghost} />
              </div>
              <div
                style={{
                  fontSize: 17,
                  fontWeight: 600,
                  color: t.ink,
                  letterSpacing: -0.3,
                }}
              >
                What are you curious about?
              </div>
              <div
                style={{
                  fontSize: 14,
                  color: t.muted,
                  textAlign: "center",
                  maxWidth: 240,
                  lineHeight: 1.5,
                }}
              >
                Create your first collection to start researching.
              </div>
            </div>
          )}
        </div>

        {/* Bottom CTA */}
        <div
          style={{
            position: "absolute",
            bottom: 80,
            left: 16,
            right: 16,
          }}
        >
          <NewCollectionButton />
        </div>

        <BottomTabBar active="home" />
      </div>
    </MobileFrame>
  );
}
