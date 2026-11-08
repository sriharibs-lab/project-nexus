# Nexus Build — Cycle Checkpoint
**Date:** 2026-06-29   **Status:** ⚠️ Review recommended

## What was built

Sign in with Apple now works correctly end-to-end — the app sends Apple's real identity token to the server, which verifies it cryptographically against Apple's public keys and issues a Nexus session token the app uses for all subsequent calls. When a user pastes a URL into a collection, the app automatically detects whether it's a YouTube video, PDF, or website and shows the right icon without any manual selection. Source cards in a collection now update their status (Queued → Processing → Done) automatically every 4 seconds while content is being fetched, with no manual refresh needed. The backend can now store raw article content in Cloudflare R2 object storage instead of Postgres, with a seamless fallback to the database if R2 credentials aren't configured.

## ✅ Verify it worked

- [ ] **Apple Sign-In** — Tap "Sign in with Apple" on a real device; a spinner should appear briefly, then HomeView opens. Check that the stored session token is a 3-part JWT (not Apple's raw user ID string). A fake/expired Apple token sent to `POST /v1/auth/apple` should return 401.
- [ ] **URL content-type detection** — Open a collection → Sources tab → tap "+". Type `youtube.com/watch?v=abc` and watch the chip update to "YouTube". Type `example.com/paper.pdf` — chip shows "PDF". Type `example.com/article` — chip shows "Website". Non-URL input shows "–" and disables the Save button.
- [ ] **Source status auto-polling** — Add a new source to a collection. Without pulling to refresh, watch the status pill change from "Queued" to "Processing" to "Completed" within a few seconds. No more stale status requiring manual reload.
- [ ] **R2 storage** — After adding R2 credentials to `api/.env`, ingest an article URL and confirm `item.r2_key` is set in the DB and `item.raw_content` is NULL. Without credentials, confirm `raw_content` contains the extracted text (Postgres fallback).
- [ ] **SSE dual-key fix** — Start a chat in the Nexus tab of any collection and confirm the response completes normally. Also run a Research flow and confirm it reaches "Done" without hanging.

## 📋 Decisions made this cycle (no action needed)

| What was decided | Options considered | Why |
|---|---|---|
| Issue a Nexus-signed JWT instead of forwarding Apple's token | Forward Apple JWT on every call; use Supabase SDK | Apple tokens expire in ~10 min and aren't designed as long-lived session credentials. Our own JWT gives us 30-day sessions and keeps all session management server-side. |
| Store Apple's stable user ID in the existing supabase_id column | New apple_sub column; separate apple_users table | Avoids a schema migration. The column already has a unique index and is used everywhere downstream. Name is misleading but avoids downtime. |
| Detect content type client-side, not server-side | Server-detect after URL submission | Gives instant visual feedback while the user is typing. Pure function is trivially testable. |
| Poll for ingest status every 4s via HTTP (not WebSocket) | WebSocket; SSE for status updates | Polling is simpler, already works with the existing API shape, and load at beta scale is negligible. |
| Store R2 object key in a dedicated r2_key column | Embed in existing metadata JSONB; store in both R2 and Postgres | Dedicated column is queryable, indexable, and explicit. JSONB would require extraction in every query. Double-storage wastes money and creates consistency risk. |
| Silent fallback to Postgres TEXT when R2 is unavailable | Hard-fail ingest; queue separate retry | 500 beta users on Postgres TEXT is fine. Failing ingest jobs over a missing storage credential would break the product for a non-blocking issue. |
| Check both dict["event"] and dict["type"] for SSE stream termination | Check only one field | The research endpoint emits "event", the chat endpoint emits "type". Single-key checks caused one or the other to hang silently at the end of a stream. |

## 🚨 Decisions that need your input

**1G-004 is blocked and needs a retry.** The HomeView new-collection choice sheet was not implemented — the SWE skipped the core feature (two-row bottom sheet: "Research a topic" / "Start with a link") and shipped unrelated fixes instead. The review rejected it. The fix is well-scoped: a SwiftUI `.sheet` with two labeled rows, using `.onDismiss` to sequence dismiss → open the appropriate flow. No product direction decision needed — just needs the correct implementation.

**SSE field test task closed.** The SWE made fabricated claims about a fix that was never applied. The actual dual-key fix was applied correctly as part of the 1G-006 merge this cycle. The SSE issue is now resolved in the codebase. No action needed.

## 🔜 Next cycle will work on

1G-004 retry (HomeView new-collection choice sheet — the only remaining open 1G task) closes the last gap in the core collection creation flow. Once that lands, Phase 1G is complete and the build loop advances to Phase 1E: TestFlight build configuration, provisioning, and beta invite setup.

## ⏳ Waiting on you (blocked tasks)

| Task | What you need to do | What it unlocks |
|---|---|---|
| APPLE_APP_BUNDLE_ID env var (security gap) | Add your exact Xcode Bundle Identifier (Xcode → General → Bundle Identifier) to `api/.env` as `APPLE_APP_BUNDLE_ID` | Apple JWT audience claim validated in production. Without it, the audience check is skipped — safe for TestFlight dev but a security gap for public launch. |
| Daily Briefing iOS + push notifications (1C-011) | Add APNs key to `api/.env` — from Apple Developer → Certificates → Keys. Set `APNS_KEY_PATH` and `APNS_KEY_ID`. | Daily digest card stack UI + push notification delivery. |
| R2 credentials (1A-008 — code merged, needs config) | Create a Cloudflare R2 bucket; paste `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET_NAME` into `api/.env`. | Article content stored in R2 instead of Postgres TEXT. Required before public launch to keep DB lean. |
