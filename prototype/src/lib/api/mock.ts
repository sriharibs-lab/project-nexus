/**
 * Mock client — works with the laptop closed (Vercel deploys default here).
 * Simulated streaming reuses the timing choreography from the design-handoff
 * fre-flow.jsx (~2.4s search beat, then sources dripping in ~430ms apart) so
 * loading experiences FEEL like the real backend.
 */

import { MOCK_COLLECTIONS, type Source } from "../mock-data";
import type { NexusClient, OnStreamEvent, OTPVerifyResult } from "./types";

const MOCK_RESEARCH_SOURCES: Array<Partial<Source> & { title: string }> = [
  { title: "The state of the field — a practitioner's overview", publisher: "Substack", content_type: "article", meta: "Article · 12 min" },
  { title: "Deep dive: what the latest research actually shows", publisher: "arXiv", content_type: "article", meta: "Paper · 24 min" },
  { title: "Expert panel discussion (full recording)", publisher: "YouTube", content_type: "video", meta: "Video · 48 min" },
  { title: "Why everyone is wrong about this — a contrarian take", publisher: "Medium", content_type: "blog", meta: "Blog · 7 min" },
  { title: "The definitive podcast episode with the leading researcher", publisher: "The Knowledge Project", content_type: "podcast", meta: "Podcast · 1 h 12 min" },
  { title: "Primary source: the original announcement", publisher: "Official blog", content_type: "announcement", meta: "Announcement · 4 min" },
];

const MOCK_ANSWER =
  "Based on the sources in this collection, there are three core threads worth understanding. " +
  "First, the fundamentals: the field has consolidated rapidly over the past 18 months, and the sources agree the platform layer is where durable value accrues. " +
  "Second, the contrarian view — one source argues the consensus underestimates open-source, and its evidence is worth weighing. " +
  "Third, the practical takeaway: for someone entering now, the recommended starting point is the practitioner's overview, followed by the panel discussion for nuance.";

function delay(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}

export const mockClient: NexusClient = {
  async requestOtp() {
    await delay(700); // simulate network + email dispatch
  },

  async verifyOtp(_email: string, code: string): Promise<OTPVerifyResult> {
    await delay(600);
    if (code.length !== 6) throw new Error("Invalid or expired code — request a new one");
    // Mock accepts any 6-digit code
    return { accessToken: "mock-token", refreshToken: "mock-refresh", userId: "mock-user", isNew: false };
  },

  async listCollections() {
    await delay(350);
    return MOCK_COLLECTIONS;
  },

  async getCollection(id: string) {
    await delay(250);
    return MOCK_COLLECTIONS.find((c) => c.id === id);
  },

  research(topic: string, onEvent: OnStreamEvent) {
    let aborted = false;
    (async () => {
      onEvent({ kind: "searching", topic });
      await delay(2400); // fre-flow.jsx choreography: search beat
      for (let i = 0; i < MOCK_RESEARCH_SOURCES.length; i++) {
        if (aborted) return;
        onEvent({ kind: "source", source: MOCK_RESEARCH_SOURCES[i] });
        await delay(430); // sources drip in
      }
      if (!aborted) onEvent({ kind: "done", collectionId: "col-1" });
    })();
    return () => {
      aborted = true;
    };
  },

  chat(_collectionId, _message, _history, onEvent: OnStreamEvent) {
    let aborted = false;
    (async () => {
      await delay(1400); // EchoPulse wait beat
      if (aborted) return;
      onEvent({
        kind: "sources",
        sources: MOCK_RESEARCH_SOURCES.slice(0, 3),
      });
      const words = MOCK_ANSWER.split(" ");
      for (let i = 0; i < words.length; i += 3) {
        if (aborted) return;
        onEvent({ kind: "chunk", text: words.slice(i, i + 3).join(" ") + " " });
        await delay(55); // word-chunk streaming feel
      }
      if (!aborted) onEvent({ kind: "done" });
    })();
    return () => {
      aborted = true;
    };
  },

  async ingest() {
    await delay(500);
  },
};
