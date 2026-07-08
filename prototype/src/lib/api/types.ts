/**
 * API types — shared between mock and live implementations.
 * Entity types (Source, Collection) live in ../mock-data.ts and match SPEC §5a.
 */

import type { Collection, Source } from "../mock-data";

export type { Collection, Source };

// ── Auth ──

export interface OTPVerifyResult {
  accessToken: string;
  refreshToken: string;
  userId: string;
  isNew: boolean;
}

// ── Streaming events — normalized discriminated union ──
// Backend inconsistency (flagged for NBL cleanup): research SSE keys on
// `event:`, chat SSE keys on `type:`. Both normalize to this union.

export type StreamEvent =
  | { kind: "searching"; topic: string }
  | { kind: "source"; source: Partial<Source> & { title: string } }
  | { kind: "sources"; sources: Array<Partial<Source> & { title: string }> }
  | { kind: "chunk"; text: string }
  | { kind: "done"; collectionId?: string }
  | { kind: "error"; message: string };

export type OnStreamEvent = (e: StreamEvent) => void;

/** Returns an abort function. */
export type StreamHandle = () => void;

// ── The client interface both modes implement ──

export interface NexusClient {
  requestOtp(email: string): Promise<void>;
  verifyOtp(email: string, code: string): Promise<OTPVerifyResult>;
  listCollections(): Promise<Collection[]>;
  getCollection(id: string): Promise<Collection | undefined>;
  research(topic: string, onEvent: OnStreamEvent): StreamHandle;
  chat(
    collectionId: string,
    message: string,
    history: Array<{ role: "user" | "assistant"; content: string }>,
    onEvent: OnStreamEvent
  ): StreamHandle;
  ingest(url: string, collectionId: string, contentType: string): Promise<void>;
}
