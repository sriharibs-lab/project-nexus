# Nexus Build — Cycle Checkpoint
**Date:** 2026-06-20   **Status:** ⚠️ Review recommended

## What was built

Nexus now has a polished first-run experience: new users are guided through a 3-screen welcome flow where they pick topics they care about and are immediately dropped into their first collection. Articles opened in the reader are automatically saved for offline access, so users can read content later with no internet connection. And the backend pipeline has been tuned to reliably hit the sub-10-second save-to-summary target — from the moment a link is saved to seeing the AI summary.

## ✅ Verify it worked

- [ ] **Onboarding** — Delete app from iOS Simulator, reinstall, launch. You should see the animated welcome screen, then a topic picker, then a "Create your first collection" prompt. After tapping "Research a topic", the app should land on the Home screen with the Research sheet already open. Relaunching the app should skip onboarding entirely.
- [ ] **Offline reading** — Open any article in the Reader while online. Then enable Airplane Mode and reopen the same article. The full text should appear with a subtle "Offline" badge next to the "Full Text" header. Opening an article you've never read before in Airplane Mode should show a "not yet extracted" notice (no crash).
- [ ] **Pipeline performance** — In `api/`, run `LOG_LEVEL=debug python -m uvicorn app.main:app` and ingest any article URL. Watch the logs for `stage=total elapsed_ms=<N> slo_ok=true`. Most articles should complete under 10 000ms. If Jina is slow, you'll see it fail fast at 8s and hand off to the local trafilatura fallback.
- [ ] **Tests (1D-001)** — `cd api && python3 -m pytest tests/ui/test_onboarding_1d001.py -v` — 81 tests pass.
- [ ] **Tests (1D-003)** — `cd api && python3 -m pytest tests/cache/test_offline_content_cache.py -v` — 21 tests pass.
- [ ] **Tests (1D-005)** — `cd api && python3 -m pytest tests/pipeline/test_jina_1d005.py tests/queue/test_ingestion_timing_1d005.py -v` — 17 tests pass.

## 📋 Decisions made this cycle (no action needed)

| What was decided | Options considered | Why |
|---|---|---|
| Onboarding completion stored in UserDefaults | Keychain, in-memory, AppStorage | UserDefaults is lightest for a one-time feature flag; AppStorage won't work before the first SwiftUI view is created |
| TabView(.page) for onboarding slide animation | Custom ZStack offset, NavigationStack | Native iOS feel, respects reduced-motion, drag-to-skip disabled via gesture override |
| FileManager (not UserDefaults) for offline article cache | UserDefaults, Core Data, SQLite | Article text can be 50–200 KB; UserDefaults is not designed for large blobs and loads everything at app launch |
| Swift actor for the offline cache | DispatchQueue, NSLock | Compiler-enforced thread safety; no manual lock discipline needed |
| Offline indicator as a subtle icon in the reader header | Toast, full-screen banner | User is reading — a disruptive banner would pull focus away from the content |
| Jina timeout split into 5s connect + 8s read | Single 30s wall timeout | The old 30s timeout could silently consume the entire SLO budget on a connection hang; 5s connect fails fast, 8s read leaves ~2s for AI + DB |
| Summarize + embed run concurrently (asyncio.gather) | Sequential | Saves the embedding latency (~200ms) on the hot path with no extra complexity |

## 🚨 Decisions that need your input

**Topic interests not persisted to the backend.** During onboarding, users pick topics they care about (e.g. "AI", "Design"). Right now those selections are only used to display pills on the final onboarding screen — they are not sent to the API or stored anywhere. Wiring this to a `/user/interests` endpoint was explicitly deferred because no such endpoint exists yet. This means the personalization system has no signal from onboarding. You'll need to decide: build the interests API before next cycle, or accept that the first Research collection is the first personalization signal (no onboarding data).

## 🔜 Next cycle will work on

1D-002 (empty/loading/error states) is blocked and will retry next cycle to add the missing database migration and Collection.status field. After that, next cycle finishes the remaining 1D polish tasks: highlights and annotations in the reader (1D-004) and App Store assets (1D-006). Once those land, the app is ready for TestFlight prep (1E).

## ⏳ Waiting on you (blocked tasks)

| Task | What you need to do | What it unlocks |
|---|---|---|
| **1D-002 — Empty/loading/error states** | No action needed from you — this is a SWE retry. The next build loop will create the missing `api/alembic/versions/0007_collection_status_draft_active.py` migration and add `status` to the Collection model. | Prevents orphan "draft" collections from appearing in the library when a Research flow is cancelled |
| **1A-008 — Full-text storage** | Create an S3 or Cloudflare R2 bucket and paste the credentials into `api/.env` | Allows storing full article text externally instead of in the database, needed before scaling beyond ~1000 articles |
| **1C-011 — Daily Briefing push notifications** | Provide your APNs key from the Apple Developer portal | Enables the daily briefing card stack and push notification delivery |
