# Nexus Build — Cycle Checkpoint
**Date:** 2026-06-20   **Status:** ⚠️ Review recommended

## What was built

The Nexus reader now lets you highlight any passage with a tap and leave a personal annotation — highlights are stored on-device and reappear every time you return to that article. Separately, every screen in the app (home, collection list, reader, chat, and search) now shows purposeful, designed states for when content is loading, when a collection is empty, or when something goes wrong — instead of blank screens or silent failures.

## ✅ Verify it worked

- [ ] **Empty / loading / error states** — Open Nexus on a fresh install (or clear app data), navigate to each main screen, and confirm you see a designed placeholder rather than a blank white area. Force a network error (airplane mode) and confirm an error state with a retry button appears.
- [ ] **Highlight + annotation** — Open any article in the reader, tap and hold a word or phrase to select it, choose a highlight color (amber or sage), and confirm the highlight persists when you close and reopen the article. Tap an existing highlight to bring up the remove sheet and delete it.

## 📋 Decisions made this cycle (no action needed)

| What was decided | Options considered | Why |
|---|---|---|
| Highlight colors (amber + sage) initialized inline rather than as full design tokens | Promote to Color.Nexus.amber/sage immediately vs. defer | Both colors are spec-correct for v1; token promotion deferred to keep this PR focused — filed as a follow-up |
| FileManager I/O for annotations runs synchronously on main thread | Async migration vs. keep synchronous | JSON sidecars are tiny at v1 scale; no real-world perf risk; async migration noted for future |
| Reader network errors (fetch failures) fall silently to "not extracted" notice | Fix in this PR vs. file follow-up | Pre-existing gap not introduced by this PR; filed as a follow-up to wire vm.error into fullTextSection with a retry affordance |
| LoadingStateView uses hand-drawn skeleton shapes, not SwiftUI .redacted modifier | .redacted(.placeholder) vs. custom skeleton | Custom shapes give more design control over the exact card anatomy shown; stale doc comment will be cleaned up |

## 🔜 Next cycle will work on

1D-006 (App Store assets — icon, screenshots, preview video script, description copy) is now unblocked since both 1D-001 and 1D-002 are complete. Completing this task unlocks the full 1E Launch Prep phase: TestFlight beta, bug bash, and App Store submission.

## ⏳ Waiting on you (blocked tasks)

| Task | What you need to do | What it unlocks |
|---|---|---|
| **1A-008 — Cloud storage (S3/R2)** | Add S3 or Cloudflare R2 bucket credentials to `api/.env` | Full-text storage for large articles; currently falls back to the database |
| **1C-011 — Daily Briefing push notifications** | Provide APNs key from Apple Developer portal (Certificates, Identifiers & Profiles → Keys) | Push-delivered daily digest to iPhone |
