"use client";

/**
 * Data-mode selection: ?mode=live|mock → localStorage → default MOCK
 * (so the Vercel deploy always works when the laptop is off).
 */

import { useEffect, useState } from "react";
import { liveClient } from "./live";
import { mockClient } from "./mock";
import type { NexusClient } from "./types";

export type DataMode = "mock" | "live";

const MODE_KEY = "nx-data-mode";

export function currentMode(): DataMode {
  if (typeof window === "undefined") return "mock";
  const param = new URLSearchParams(window.location.search).get("mode");
  if (param === "live" || param === "mock") {
    localStorage.setItem(MODE_KEY, param);
    return param;
  }
  return (localStorage.getItem(MODE_KEY) as DataMode) || "mock";
}

export function setMode(mode: DataMode) {
  localStorage.setItem(MODE_KEY, mode);
}

export function getClient(): NexusClient {
  return currentMode() === "live" ? liveClient : mockClient;
}

/** Reactive mode hook — used by the flows layout badge. */
export function useDataMode(): [DataMode, (m: DataMode) => void] {
  const [mode, set] = useState<DataMode>("mock");
  useEffect(() => {
    set(currentMode());
  }, []);
  const update = (m: DataMode) => {
    setMode(m);
    set(m);
  };
  return [mode, update];
}

export type { NexusClient, StreamEvent, OTPVerifyResult } from "./types";
