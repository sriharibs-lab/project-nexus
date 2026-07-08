/**
 * Live client — talks to the real FastAPI backend.
 *
 * Base URL resolution: ?api= query param (persisted) → NEXT_PUBLIC_API_URL →
 * http://<current hostname>:8000 (same-WiFi laptop testing: the phone loads
 * the prototype from the Mac's IP, so the backend is on the same host).
 *
 * Note: if the prototype is served over https (Vercel), a plain-http API is
 * blocked as mixed content — live mode is for LAN dev; Vercel runs mock mode.
 */

import { streamSSE } from "./sse";
import type { Collection, NexusClient, OnStreamEvent, OTPVerifyResult } from "./types";

const TOKEN_KEY = "nx-access-token";

export function apiBaseUrl(): string {
  if (typeof window === "undefined") return "http://localhost:8000";
  const param = new URLSearchParams(window.location.search).get("api");
  if (param) {
    localStorage.setItem("nx-api-url", param);
    return param;
  }
  return (
    localStorage.getItem("nx-api-url") ||
    process.env.NEXT_PUBLIC_API_URL ||
    `http://${window.location.hostname}:8000`
  );
}

function authHeaders(): Record<string, string> {
  const token = typeof window === "undefined" ? null : localStorage.getItem(TOKEN_KEY);
  return token ? { Authorization: `Bearer ${token}` } : {};
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const resp = await fetch(`${apiBaseUrl()}${path}`, {
    ...init,
    headers: { "Content-Type": "application/json", ...authHeaders(), ...init?.headers },
  });
  if (!resp.ok) {
    let detail = `Request failed (${resp.status})`;
    try {
      detail = (await resp.json()).detail ?? detail;
    } catch {
      /* non-JSON error body */
    }
    throw new Error(detail);
  }
  return resp.json() as Promise<T>;
}

// Map backend snake_case items/collections into the prototype's shapes.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function toCollection(raw: any): Collection {
  return {
    id: raw.id,
    name: raw.name,
    description: raw.description ?? undefined,
    source_count: raw.source_count ?? raw.sources?.length ?? 0,
    created_at: raw.created_at ?? new Date().toISOString(),
    ai_framing: raw.ai_framing ?? raw.framing ?? undefined,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    sources: (raw.items ?? raw.sources ?? []).map((s: any) => ({
      id: s.id,
      url: s.url,
      title: s.title ?? s.url,
      content_type: s.content_type ?? "article",
      publisher: s.domain ?? s.publisher ?? "",
      meta: s.meta ?? "",
      tldr: s.summary ?? s.tldr ?? undefined,
      key_insights: s.key_insights ?? undefined,
      tags: s.tags ?? undefined,
      ingest_status: s.ingest_status ?? "completed",
    })),
  };
}

export const liveClient: NexusClient = {
  async requestOtp(email: string) {
    await request("/v1/auth/magic-link", { method: "POST", body: JSON.stringify({ email }) });
  },

  async verifyOtp(email: string, code: string): Promise<OTPVerifyResult> {
    const data = await request<{
      access_token: string;
      refresh_token: string;
      user_id: string;
      is_new: boolean;
    }>("/v1/auth/verify-otp", {
      method: "POST",
      body: JSON.stringify({ email, token: code }),
    });
    localStorage.setItem(TOKEN_KEY, data.access_token);
    return {
      accessToken: data.access_token,
      refreshToken: data.refresh_token,
      userId: data.user_id,
      isNew: data.is_new,
    };
  },

  async listCollections() {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const data = await request<any>("/v1/collections");
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    return (Array.isArray(data) ? data : data.collections ?? []).map((c: any) => toCollection(c));
  },

  async getCollection(id: string) {
    return toCollection(await request(`/v1/collections/${id}`));
  },

  research(topic: string, onEvent: OnStreamEvent) {
    return streamSSE(
      `${apiBaseUrl()}/v1/collections/research`,
      { topic },
      authHeaders(),
      onEvent
    );
  },

  chat(collectionId, message, history, onEvent) {
    return streamSSE(
      `${apiBaseUrl()}/v1/collections/${collectionId}/chat`,
      { message, history },
      authHeaders(),
      onEvent
    );
  },

  async ingest(url, collectionId, contentType) {
    await request("/v1/ingest", {
      method: "POST",
      body: JSON.stringify({ url, collection_id: collectionId, content_type: contentType }),
    });
  },
};
