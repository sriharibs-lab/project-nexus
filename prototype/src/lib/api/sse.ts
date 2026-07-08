/**
 * Shared POST-SSE consumer.
 * Both streaming endpoints are POST, so EventSource doesn't apply — we read
 * the body stream manually: split on blank lines, strip "data: ", JSON.parse.
 *
 * Normalizes the two backend event vocabularies into StreamEvent:
 *   research (research.py): {"event": "searching"|"source"|"done"|"error", ...}
 *   chat (collections.py):  {"type": "sources"|"chunk"|"done"|"error", ...}
 * (Backend inconsistency flagged as an NBL cleanup task.)
 */

import type { OnStreamEvent, StreamEvent } from "./types";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function normalize(raw: any): StreamEvent | null {
  const key = raw.event ?? raw.type;
  switch (key) {
    case "searching":
      return { kind: "searching", topic: raw.topic ?? "" };
    case "source":
      return { kind: "source", source: raw.source ?? raw };
    case "sources":
      return { kind: "sources", sources: raw.sources ?? [] };
    case "chunk":
      return { kind: "chunk", text: raw.text ?? raw.delta ?? "" };
    case "done":
      return { kind: "done", collectionId: raw.collection_id ?? raw.collectionId };
    case "error":
      return { kind: "error", message: raw.message ?? raw.detail ?? "Something went wrong" };
    default:
      return null; // unknown event — skip, don't crash the stream
  }
}

export function streamSSE(
  url: string,
  body: unknown,
  headers: Record<string, string>,
  onEvent: OnStreamEvent
): () => void {
  const controller = new AbortController();

  (async () => {
    try {
      const resp = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json", ...headers },
        body: JSON.stringify(body),
        signal: controller.signal,
      });
      if (!resp.ok || !resp.body) {
        onEvent({ kind: "error", message: `Request failed (${resp.status})` });
        return;
      }

      const reader = resp.body.getReader();
      const decoder = new TextDecoder();
      let buffer = "";

      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });

        const frames = buffer.split("\n\n");
        buffer = frames.pop() ?? ""; // keep the trailing partial frame

        for (const frame of frames) {
          for (const line of frame.split("\n")) {
            if (!line.startsWith("data: ")) continue;
            try {
              const evt = normalize(JSON.parse(line.slice(6)));
              if (evt) {
                onEvent(evt);
                if (evt.kind === "done" || evt.kind === "error") return;
              }
            } catch {
              // malformed frame — skip
            }
          }
        }
      }
    } catch (err) {
      if ((err as Error).name !== "AbortError") {
        onEvent({ kind: "error", message: "Connection lost — is the backend running?" });
      }
    }
  })();

  return () => controller.abort();
}
