"use client";

/**
 * Nexus tab — AI agent surface (SPEC §5a: default landing inside every collection).
 *
 * Layout (top → bottom):
 *   1. AI framing paragraph (pre-computed on collection creation)
 *   2. Starter prompts (contextual chips — replaced by real context once ≥3 sources)
 *   3. Chat thread (grows upward as conversation builds)
 *   4. Composer (ask anything, audio mode, mic)
 *
 * The Echo pulse animation signals the AI is active and source-grounded.
 * Grounded responses cite the actual saved items — never free-form hallucination.
 */

import React, { useRef, useState } from "react";
import { tokens } from "../../../../lib/tokens";
import { Icon, Pressable } from "../../../../lib/components";
import { STARTER_PROMPTS, type Collection } from "../../../../lib/mock-data";

const t = tokens.color;
const ACCENT = t.plum;

interface Message {
  id: string;
  role: "user" | "assistant";
  content: string;
  citations?: string[]; // source titles cited
}

// ── Echo pulse (AI identity mark) ──

function EchoPulse() {
  return (
    <div
      style={{
        width: 32,
        height: 32,
        position: "relative",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        flexShrink: 0,
      }}
    >
      {/* Pulse rings */}
      {[0, 1].map((i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            width: 28,
            height: 28,
            borderRadius: 999,
            border: `1px solid ${ACCENT}`,
            opacity: 0,
            animation: `nxEcho 2.4s ${i * 0.8}s ease-out infinite`,
          }}
        />
      ))}
      {/* Icon */}
      <div
        style={{
          width: 28,
          height: 28,
          borderRadius: 999,
          background: `${ACCENT}15`,
          border: `1px solid ${ACCENT}40`,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        <Icon name="nexus" size={16} color={ACCENT} />
      </div>
    </div>
  );
}

// ── Framing paragraph (AI-generated intro) ──

function FramingParagraph({ text }: { text: string }) {
  return (
    <div
      style={{
        display: "flex",
        gap: 10,
        padding: "14px 16px",
        background: t.surface,
        borderRadius: 18,
        border: `1px solid ${t.border}`,
        marginBottom: 16,
        boxShadow: "0 1px 4px rgba(19,14,26,0.04)",
        animation: "nxFade 0.4s cubic-bezier(.2,.8,.2,1) both",
      }}
    >
      <EchoPulse />
      <div
        style={{
          fontSize: 14.5,
          color: t.muted,
          lineHeight: 1.55,
          letterSpacing: -0.15,
          flex: 1,
          minWidth: 0,
          paddingTop: 4,
        }}
      >
        {text}
      </div>
    </div>
  );
}

// ── Starter prompt chip ──

function StarterChip({
  prompt,
  onClick,
}: {
  prompt: string;
  onClick: () => void;
}) {
  return (
    <Pressable
      scale={0.95}
      onClick={onClick}
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: 7,
        padding: "9px 13px",
        borderRadius: 999,
        background: t.surface,
        border: `1px solid ${t.border}`,
        fontSize: 13.5,
        fontWeight: 500,
        color: t.ink,
        letterSpacing: -0.15,
        textAlign: "left",
        fontFamily: tokens.font.sans,
        boxShadow: "0 1px 3px rgba(19,14,26,0.04)",
        animation: "nxFade 0.35s cubic-bezier(.2,.8,.2,1) both",
      }}
    >
      <Icon name="sparkle" size={13} color={t.faint} />
      {prompt}
    </Pressable>
  );
}

// ── Citation pill ──

function CitationPill({ title }: { title: string }) {
  return (
    <div
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: 5,
        padding: "3px 9px",
        borderRadius: 999,
        background: `${ACCENT}10`,
        border: `1px solid ${ACCENT}25`,
        fontSize: 12,
        fontWeight: 500,
        color: ACCENT,
        letterSpacing: -0.1,
        maxWidth: 200,
        overflow: "hidden",
        textOverflow: "ellipsis",
        whiteSpace: "nowrap",
      }}
    >
      <Icon name="layers" size={11} color={ACCENT} />
      {title}
    </div>
  );
}

// ── Chat message bubble ──

function ChatMessage({ message }: { message: Message }) {
  const isUser = message.role === "user";
  return (
    <div
      style={{
        display: "flex",
        flexDirection: "column",
        alignItems: isUser ? "flex-end" : "flex-start",
        gap: 6,
        marginBottom: 14,
        animation: "nxFade 0.3s cubic-bezier(.2,.8,.2,1) both",
      }}
    >
      <div
        style={{
          maxWidth: "85%",
          padding: isUser ? "10px 14px" : "12px 14px",
          borderRadius: isUser ? "18px 18px 4px 18px" : "4px 18px 18px 18px",
          background: isUser ? t.ink : t.surface,
          border: isUser ? "none" : `1px solid ${t.border}`,
          fontSize: 14.5,
          color: isUser ? t.white : t.ink,
          lineHeight: 1.5,
          letterSpacing: -0.15,
          boxShadow: isUser ? "none" : "0 1px 3px rgba(19,14,26,0.04)",
        }}
      >
        {!isUser && (
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 6,
              marginBottom: 6,
            }}
          >
            <Icon name="nexus" size={13} color={ACCENT} />
            <span
              style={{
                fontSize: 11.5,
                fontWeight: 600,
                color: ACCENT,
                letterSpacing: 0.2,
                textTransform: "uppercase",
              }}
            >
              Nexus
            </span>
          </div>
        )}
        {message.content}
      </div>

      {/* Citations */}
      {!isUser && message.citations && message.citations.length > 0 && (
        <div style={{ display: "flex", flexWrap: "wrap", gap: 5, maxWidth: "85%" }}>
          {message.citations.map((cite, i) => (
            <CitationPill key={i} title={cite} />
          ))}
        </div>
      )}
    </div>
  );
}

// ── Typing indicator ──

function TypingDots() {
  return (
    <div
      style={{
        display: "flex",
        gap: 10,
        padding: "12px 14px",
        borderRadius: "4px 18px 18px 18px",
        background: t.surface,
        border: `1px solid ${t.border}`,
        alignItems: "center",
        width: "fit-content",
        marginBottom: 14,
      }}
    >
      <Icon name="nexus" size={13} color={ACCENT} />
      {[0, 1, 2].map((i) => (
        <div
          key={i}
          style={{
            width: 5,
            height: 5,
            borderRadius: 999,
            background: t.faint,
            animation: `nxDot 1.2s ${i * 0.2}s ease infinite`,
          }}
        />
      ))}
    </div>
  );
}

// ── Composer ──

function NexusComposer({
  onSend,
  disabled,
}: {
  onSend: (query: string) => void;
  disabled: boolean;
}) {
  const [query, setQuery] = useState("");

  const handleSend = () => {
    if (!query.trim() || disabled) return;
    onSend(query.trim());
    setQuery("");
  };

  return (
    <div
      style={{
        background: t.surface,
        borderRadius: 24,
        border: `1px solid ${query ? t.borderStrong : t.border}`,
        boxShadow: query
          ? `0 0 0 3px ${t.surface2}, 0 2px 10px rgba(19,14,26,0.05)`
          : "0 1px 4px rgba(19,14,26,0.04)",
        padding: "13px 13px 11px",
        transition: "border-color 0.18s, box-shadow 0.18s",
      }}
    >
      <div style={{ padding: "0 4px 12px", minHeight: 22 }}>
        <input
          type="text"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && handleSend()}
          placeholder="Ask anything about these sources…"
          style={{
            width: "100%",
            background: "transparent",
            border: "none",
            outline: "none",
            fontSize: 16,
            color: query ? t.ink : t.ghost,
            letterSpacing: -0.2,
            lineHeight: 1.4,
            fontFamily: tokens.font.sans,
          }}
        />
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
        <Pressable
          scale={0.9}
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
          <Icon name="plus" size={17} color={t.muted} />
        </Pressable>
        <div style={{ flex: 1 }} />
        <Pressable
          scale={0.9}
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
          <Icon name="mic" size={17} color={t.muted} />
        </Pressable>
        {/* Send / Audio button */}
        <Pressable
          scale={0.88}
          onClick={handleSend}
          style={{
            width: 32,
            height: 32,
            borderRadius: 999,
            background: query && !disabled ? ACCENT : t.ink,
            border: "none",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            flexShrink: 0,
            transition: "background 0.2s",
          }}
        >
          {query ? (
            <Icon name="send" size={16} color="#fff" stroke={2} />
          ) : (
            // Four-bar waveform (the ink-filled affordance)
            <Icon name="waveform" size={18} color="#fff" />
          )}
        </Pressable>
      </div>
    </div>
  );
}

// ── Mock AI response generator ──

function generateAIResponse(query: string, collection: Collection): Message {
  const lq = query.toLowerCase();
  const firstSource = collection.sources[0];
  const completedSources = collection.sources.filter(
    (s) => s.ingest_status === "completed"
  );

  let content = "";
  let citations: string[] = [];

  if (lq.includes("key idea") || lq.includes("main idea") || lq.includes("summary")) {
    content =
      firstSource?.tldr ??
      `Across the ${completedSources.length} sources in this collection, the central thesis is that ${collection.name.toLowerCase()} represents a fundamental shift in how we think about the domain. The most consistently cited insight is that existing frameworks underestimate the speed of change.`;
    citations = completedSources.slice(0, 3).map((s) => s.title);
  } else if (lq.includes("read first") || lq.includes("start")) {
    const best = completedSources.find((s) => s.key_insights?.length) ?? completedSources[0];
    content = best
      ? `Start with "${best.title}" from ${best.publisher}. It gives the clearest conceptual framework and will make the other sources click into place. After that, the ${completedSources[1]?.publisher ?? "second"} piece adds the critical counterarguments.`
      : "I'd suggest starting with the article that has the broadest overview, then narrowing into the more specialized pieces.";
    citations = best ? [best.title] : [];
  } else if (lq.includes("contradict") || lq.includes("disagree")) {
    content = `I noticed a tension between the sources: some argue the shift is structural and irreversible, while others see it as cyclical. The ${completedSources[0]?.publisher} piece is most bullish; the ${completedSources[completedSources.length - 1]?.publisher ?? "last"} piece raises the strongest doubts.`;
    citations = completedSources.slice(0, 2).map((s) => s.title);
  } else if (lq.includes("missing") || lq.includes("gap")) {
    content = `The collection covers the "what" and "why" well but is light on the "how" — specifically, implementation details and timelines. I'd suggest adding a practitioner perspective or a case study to round it out.`;
    citations = [];
  } else if (lq.includes("bullet") || lq.includes("3 bullet") || lq.includes("three")) {
    const insights = firstSource?.key_insights ?? [
      "The landscape is shifting faster than most incumbents can adapt",
      "First-mover advantages are eroding as the technology becomes more accessible",
      "Regulatory frameworks are 18–24 months behind the current state of play",
    ];
    content =
      insights
        .slice(0, 3)
        .map((ins, i) => `${i + 1}. ${ins}`)
        .join("\n\n");
    citations = completedSources.slice(0, 2).map((s) => s.title);
  } else {
    content = `Based on the ${completedSources.length} sources I've read, here's what I can tell you: the consensus across these pieces points toward a significant structural shift. The sources from ${completedSources[0]?.publisher ?? "the key outlets"} are particularly clear on this. Would you like me to go deeper on any specific angle?`;
    citations = completedSources.slice(0, 2).map((s) => s.title);
  }

  return {
    id: `ai-${Date.now()}`,
    role: "assistant",
    content,
    citations,
  };
}

// ── Nexus tab main ──

interface NexusTabProps {
  collection: Collection;
}

export default function NexusTab({ collection }: NexusTabProps) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [isTyping, setIsTyping] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);

  const handleSend = (query: string) => {
    if (isTyping) return;

    const userMsg: Message = {
      id: `user-${Date.now()}`,
      role: "user",
      content: query,
    };

    setMessages((prev) => [...prev, userMsg]);
    setIsTyping(true);

    // Simulate AI processing
    setTimeout(() => {
      const aiMsg = generateAIResponse(query, collection);
      setMessages((prev) => [...prev, aiMsg]);
      setIsTyping(false);
      // Scroll to bottom
      requestAnimationFrame(() => {
        scrollRef.current?.scrollTo({
          top: scrollRef.current.scrollHeight,
          behavior: "smooth",
        });
      });
    }, 1400 + Math.random() * 600);
  };

  const hasMessages = messages.length > 0;

  return (
    <div
      style={{
        height: "100%",
        display: "flex",
        flexDirection: "column",
        overflow: "hidden",
      }}
    >
      {/* Scrollable content area */}
      <div
        ref={scrollRef}
        style={{
          flex: 1,
          minHeight: 0,
          overflowY: "auto",
          padding: "14px 16px 8px",
        }}
      >
        {/* Framing paragraph */}
        {collection.ai_framing && (
          <FramingParagraph text={collection.ai_framing} />
        )}

        {/* Starter prompts — shown before any messages */}
        {!hasMessages && (
          <div
            style={{
              display: "flex",
              flexDirection: "column",
              gap: 8,
              marginBottom: 16,
            }}
          >
            <div
              style={{
                fontSize: 11.5,
                fontWeight: 600,
                letterSpacing: 0.7,
                textTransform: "uppercase",
                color: t.faint,
                marginBottom: 4,
                paddingLeft: 2,
              }}
            >
              Try asking
            </div>
            {STARTER_PROMPTS.map((prompt, i) => (
              <StarterChip
                key={i}
                prompt={prompt}
                onClick={() => handleSend(prompt)}
              />
            ))}
          </div>
        )}

        {/* Chat thread */}
        {messages.map((msg) => (
          <ChatMessage key={msg.id} message={msg} />
        ))}

        {/* Typing indicator */}
        {isTyping && <TypingDots />}
      </div>

      {/* Composer */}
      <div style={{ padding: "8px 16px 20px", flexShrink: 0 }}>
        <NexusComposer onSend={handleSend} disabled={isTyping} />
      </div>
    </div>
  );
}
