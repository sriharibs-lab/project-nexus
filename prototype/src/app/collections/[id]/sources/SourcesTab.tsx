"use client";

/**
 * Sources tab — the links/content surface inside a collection (SPEC §5a).
 *
 * Layout:
 *   - Flat list of source rows (no dividers — full-width row cards per DESIGN_LANGUAGE §7)
 *   - Each row: type icon + title + publisher·meta + AI status badge + remove button
 *   - Add a source CTA at the bottom (+ button → glass menu)
 *   - Source rows with completed ingest show tldr on expand
 *
 * Material: inline = solid + hairline border. No glass on row cards.
 * source_count is updated by app layer when sources are added/removed.
 */

import React, { useState } from "react";
import { tokens } from "../../../../lib/tokens";
import {
  Icon,
  Pressable,
  TypeBadge,
  Shimmer,
} from "../../../../lib/components";
import { type Collection, type Source } from "../../../../lib/mock-data";

const t = tokens.color;
const ACCENT = t.plum;

// ── Ingest status badge ──

function StatusBadge({ status }: { status: Source["ingest_status"] }) {
  if (status === "completed") return null; // no badge when done

  const configs = {
    pending: { label: "Queued", color: t.ghost, bg: t.surface2, border: t.hair },
    processing: {
      label: "Reading…",
      color: t.muted,
      bg: t.surface2,
      border: t.hair,
      spinner: true,
    },
    failed: {
      label: "Failed",
      color: "#DC2626",
      bg: "#FEF2F2",
      border: "#FECACA",
    },
  };

  const cfg = configs[status];

  return (
    <div
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: 4,
        padding: "2px 7px",
        borderRadius: 999,
        background: cfg.bg,
        border: `1px solid ${cfg.border}`,
        flexShrink: 0,
      }}
    >
      {(cfg as { spinner?: boolean }).spinner && (
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
      )}
      <span
        style={{ fontSize: 11.5, fontWeight: 600, color: cfg.color, letterSpacing: -0.05 }}
      >
        {cfg.label}
      </span>
    </div>
  );
}

// ── AI summary expander ──

function AISummary({ source }: { source: Source }) {
  if (!source.tldr && !source.key_insights) return null;

  return (
    <div
      style={{
        marginTop: 10,
        padding: "10px 12px",
        background: `${ACCENT}08`,
        borderRadius: 12,
        border: `1px solid ${ACCENT}20`,
        animation: "nxFade 0.25s cubic-bezier(.2,.8,.2,1) both",
      }}
    >
      {source.tldr && (
        <div
          style={{
            fontSize: 13,
            color: t.muted,
            lineHeight: 1.5,
            letterSpacing: -0.1,
            marginBottom: source.key_insights ? 8 : 0,
          }}
        >
          {source.tldr}
        </div>
      )}
      {source.key_insights && (
        <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
          {source.key_insights.slice(0, 3).map((ins, i) => (
            <div
              key={i}
              style={{
                display: "flex",
                gap: 8,
                fontSize: 12.5,
                color: t.muted,
                lineHeight: 1.4,
              }}
            >
              <span style={{ color: ACCENT, fontWeight: 700, flexShrink: 0, marginTop: 1 }}>
                ·
              </span>
              {ins}
            </div>
          ))}
        </div>
      )}
      {source.tags && source.tags.length > 0 && (
        <div style={{ display: "flex", flexWrap: "wrap", gap: 5, marginTop: 8 }}>
          {source.tags.slice(0, 4).map((tag) => (
            <span
              key={tag}
              style={{
                fontSize: 11,
                color: t.faint,
                background: t.surface2,
                border: `1px solid ${t.hair}`,
                padding: "2px 7px",
                borderRadius: 999,
                letterSpacing: -0.05,
              }}
            >
              {tag}
            </span>
          ))}
        </div>
      )}
    </div>
  );
}

// ── Source row ──

function SourceRow({
  source,
  onRemove,
  expanded,
  onToggle,
}: {
  source: Source;
  onRemove: () => void;
  expanded: boolean;
  onToggle: () => void;
}) {
  const [removing, setRemoving] = useState(false);

  const handleRemove = () => {
    setRemoving(true);
    setTimeout(onRemove, 300);
  };

  return (
    <div
      style={{
        overflow: "hidden",
        maxHeight: removing ? 0 : 400,
        opacity: removing ? 0 : 1,
        transform: removing ? "scale(0.97)" : "none",
        transition:
          "max-height 0.3s cubic-bezier(.2,.8,.2,1) 0.06s, opacity 0.22s ease, transform 0.24s ease",
        marginBottom: 2,
      }}
    >
      <Pressable
        onClick={onToggle}
        scale={0.99}
        style={{
          display: "flex",
          alignItems: "flex-start",
          gap: 12,
          padding: "12px 4px 12px 2px",
          width: "100%",
          textAlign: "left",
          fontFamily: tokens.font.sans,
        }}
      >
        <TypeBadge contentType={source.content_type} size={34} />

        <div style={{ flex: 1, minWidth: 0 }}>
          {/* Title or shimmer */}
          {source.ingest_status === "pending" ? (
            <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
              <Shimmer width="72%" />
              <Shimmer width="42%" height={11} />
            </div>
          ) : (
            <>
              <div
                style={{
                  fontSize: 15,
                  fontWeight: 600,
                  letterSpacing: -0.2,
                  color: t.ink,
                  lineHeight: 1.3,
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                  whiteSpace: expanded ? "normal" : "nowrap",
                  marginBottom: 3,
                }}
              >
                {source.title}
              </div>
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 7,
                  flexWrap: "wrap",
                }}
              >
                <span style={{ fontSize: 12.5, color: t.faint, letterSpacing: -0.1 }}>
                  {source.publisher} · {source.meta}
                </span>
                <StatusBadge status={source.ingest_status} />
              </div>
            </>
          )}

          {/* AI summary (expanded) */}
          {expanded && source.ingest_status === "completed" && (
            <AISummary source={source} />
          )}
        </div>

        {/* Remove button */}
        <Pressable
          scale={0.82}
          onClick={(e) => {
            e?.stopPropagation();
            handleRemove();
          }}
          style={{
            width: 30,
            height: 30,
            borderRadius: 999,
            background: "transparent",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            flexShrink: 0,
            marginTop: 2,
          }}
        >
          <Icon name="x" size={14} color={t.ghost} />
        </Pressable>
      </Pressable>
    </div>
  );
}

// ── Add source glass-style menu ──

function AddMenu({
  open,
  onClose,
  onAdd,
}: {
  open: boolean;
  onClose: () => void;
  onAdd: (type: string) => void;
}) {
  if (!open) return null;

  const options = [
    { icon: "globe" as const, label: "Website" },
    { icon: "video" as const, label: "YouTube" },
    { icon: "file" as const, label: "PDF" },
    { icon: "mic" as const, label: "Podcast" },
  ];

  return (
    <>
      {/* Tap-away scrim — transparent per design language */}
      <div
        onClick={onClose}
        style={{
          position: "absolute",
          inset: 0,
          zIndex: 40,
        }}
      />
      {/* Liquid Glass menu */}
      <div
        style={{
          position: "absolute",
          bottom: 80,
          left: 16,
          right: 16,
          zIndex: 50,
          background: "rgba(255,255,255,0.82)",
          backdropFilter: "blur(8px) saturate(195%) brightness(1.05)",
          WebkitBackdropFilter: "blur(8px) saturate(195%) brightness(1.05)",
          borderRadius: 22,
          border: `1px solid ${t.border}`,
          boxShadow:
            "0 22px 58px rgba(19,14,26,0.16), inset 0 1px 0 rgba(255,255,255,0.9), inset 0 -1px 0 rgba(19,14,26,0.04)",
          overflow: "hidden",
          animation: "nxFade 0.22s cubic-bezier(.18,1.5,.4,1) both",
        }}
      >
        {/* Tint/gloss overlay */}
        <div
          style={{
            position: "absolute",
            inset: 0,
            background:
              "linear-gradient(135deg, rgba(255,255,255,0.35) 0%, rgba(255,255,255,0) 50%, rgba(255,255,255,0.08) 100%)",
            pointerEvents: "none",
          }}
        />

        <div style={{ padding: "6px 0" }}>
          {options.map((opt, i) => (
            <Pressable
              key={opt.label}
              scale={0.97}
              onClick={() => {
                onAdd(opt.label);
                onClose();
              }}
              style={{
                display: "flex",
                alignItems: "center",
                gap: 14,
                width: "100%",
                padding: "13px 18px",
                borderBottom:
                  i < options.length - 1 ? `1px solid ${t.hair}` : "none",
                fontFamily: tokens.font.sans,
              }}
            >
              <div
                style={{
                  width: 32,
                  height: 32,
                  borderRadius: 10,
                  background: t.surface2,
                  border: `1px solid ${t.border}`,
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  flexShrink: 0,
                }}
              >
                <Icon name={opt.icon} size={17} color={t.muted} />
              </div>
              <span
                style={{
                  fontSize: 16,
                  fontWeight: 500,
                  color: t.ink,
                  letterSpacing: -0.2,
                }}
              >
                {opt.label}
              </span>
            </Pressable>
          ))}
        </div>
      </div>
    </>
  );
}

// ── Sources tab main ──

interface SourcesTabProps {
  collection: Collection;
}

export default function SourcesTab({ collection }: SourcesTabProps) {
  const [sources, setSources] = useState<Source[]>(collection.sources);
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [addMenuOpen, setAddMenuOpen] = useState(false);
  const [plusRotated, setPlusRotated] = useState(false);

  const handleRemove = (id: string) => {
    setSources((prev) => prev.filter((s) => s.id !== id));
  };

  const handleToggle = (id: string) => {
    setExpandedId((prev) => (prev === id ? null : id));
  };

  const handleAdd = (type: string) => {
    // Mock: add a new pending source
    const newSource: Source = {
      id: `src-new-${Date.now()}`,
      url: "https://example.com/new",
      title: "Fetching…",
      content_type:
        type === "YouTube" ? "video" : type === "Podcast" ? "podcast" : "article",
      publisher: type,
      meta: "Just added",
      ingest_status: "pending",
    };
    setSources((prev) => [newSource, ...prev]);
    // Simulate fetching title after 2s
    setTimeout(() => {
      setSources((prev) =>
        prev.map((s) =>
          s.id === newSource.id
            ? {
                ...s,
                title: `New ${type} source`,
                ingest_status: "processing" as const,
              }
            : s
        )
      );
    }, 2000);
  };

  const handlePlusToggle = () => {
    setAddMenuOpen((v) => !v);
    setPlusRotated((v) => !v);
  };

  return (
    <div
      style={{
        height: "100%",
        display: "flex",
        flexDirection: "column",
        overflow: "hidden",
        position: "relative",
      }}
    >
      {/* Sources list */}
      <div
        style={{
          flex: 1,
          minHeight: 0,
          overflowY: "auto",
          padding: "10px 16px 100px",
        }}
      >
        {sources.length === 0 ? (
          <div
            style={{
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              paddingTop: 60,
              gap: 10,
            }}
          >
            <Icon name="layers" size={28} color={t.ghost} />
            <div style={{ fontSize: 15, color: t.muted, letterSpacing: -0.2 }}>
              No sources yet
            </div>
            <div
              style={{
                fontSize: 13,
                color: t.faint,
                textAlign: "center",
                maxWidth: 200,
                lineHeight: 1.5,
              }}
            >
              Tap + to add a source
            </div>
          </div>
        ) : (
          sources.map((source) => (
            <SourceRow
              key={source.id}
              source={source}
              onRemove={() => handleRemove(source.id)}
              expanded={expandedId === source.id}
              onToggle={() => handleToggle(source.id)}
            />
          ))
        )}
      </div>

      {/* Add source CTA */}
      <div
        style={{
          position: "absolute",
          bottom: 0,
          left: 0,
          right: 0,
          padding: "16px 16px 24px",
          background: `linear-gradient(to top, ${t.surface3} 60%, transparent)`,
          zIndex: 30,
        }}
      >
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 8,
            background: t.surface,
            borderRadius: 999,
            border: `1px solid ${addMenuOpen ? t.borderStrong : t.border}`,
            boxShadow: "0 1px 4px rgba(19,14,26,0.04)",
            padding: "7px 8px",
            transition: "border-color 0.18s",
          }}
        >
          <Pressable
            scale={0.9}
            onClick={handlePlusToggle}
            style={{
              width: 32,
              height: 32,
              borderRadius: 999,
              background: t.surface2,
              border: `1px solid ${addMenuOpen ? t.borderStrong : t.border}`,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              flexShrink: 0,
              transition: "border-color 0.18s",
            }}
          >
            <span
              style={{
                display: "inline-flex",
                transform: plusRotated ? "rotate(45deg)" : "none",
                transition: "transform 0.22s cubic-bezier(.2,.8,.2,1)",
              }}
            >
              <Icon name="plus" size={17} color={t.ink} />
            </span>
          </Pressable>
          <span
            style={{
              flex: 1,
              fontSize: 15,
              color: t.ghost,
              letterSpacing: -0.2,
              lineHeight: 1.4,
            }}
          >
            Add a source…
          </span>
          <Pressable
            scale={0.88}
            style={{
              width: 32,
              height: 32,
              borderRadius: 999,
              background: t.surface2,
              border: `1px solid ${t.border}`,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              flexShrink: 0,
            }}
          >
            <Icon name="mic" size={16} color={t.muted} />
          </Pressable>
        </div>
      </div>

      {/* Add menu */}
      <AddMenu
        open={addMenuOpen}
        onClose={() => {
          setAddMenuOpen(false);
          setPlusRotated(false);
        }}
        onAdd={handleAdd}
      />
    </div>
  );
}
