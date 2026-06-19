# Nexus Build — Cycle Checkpoint
**Date:** 2026-06-18   **Status:** 🚨 Action required

## What was built

Nexus can now authenticate users. The backend has four auth endpoints: provision a user after Apple Sign In or magic link OTP (both handled by Supabase), proxy the magic link email request so the secret key never touches the iOS app, refresh tokens, and return the signed-in user profile. A user interest profile table has been added to the database so the AI layer can track what topics each user cares about over time.

## ✅ Verify it worked

- [ ] **Auth provision** — `curl -X POST https://<api>/v1/auth/provision -H "Authorization: Bearer <supabase_jwt>"` — should return `{user: {id, email}, is_new: true}` on first call
- [ ] **Magic link proxy** — `curl -X POST https://<api>/v1/auth/magic-link -H "Content-Type: application/json" -d '{"email":"test@example.com"}'` — should return 200 with message (Supabase sends the email)
- [ ] **User profile** — `curl https://<api>/v1/auth/me -H "Authorization: Bearer <supabase_jwt>"` — should return user object
- [ ] **Database migration** — `cd api && alembic upgrade head` — should apply migration 0002 creating `user_interest_profiles` table without errors

## 📋 Decisions made this cycle (no action needed)

| What was decided | Options considered | Why |
|---|---|---|
| Supabase handles Apple OAuth; API only provisions users after auth | Build custom Apple token verifier on the API | Supabase already does the hard part. Our API just records who signed in — cleaner separation. |
| Magic link OTP proxied through our API | Let iOS call Supabase directly | The service_role key needed for OTPs grants full DB access — it must never leave the server. |
| Single `/v1/auth/provision` endpoint for both auth methods | Separate endpoints per auth type | Both methods produce a Supabase JWT. One endpoint handles both cleanly. |
| User interest profile stored as a JSONB blob (one row per user) | Normalized relational tables | The topic schema will evolve as the AI matures. A flexible blob avoids a migration every time the AI team adds a new signal. |

## 🚨 Decisions that need your input

**1B-003 (Share Extension) and 1B-006 (Feedback UI) have failed review twice.** The same bugs keep resurfacing:

- All three content extractors (`jina.py`, `youtube.py`, `deepgram_extractor.py`) use uppercase enum names (`ContentType.ARTICLE`) that don't exist — every real save will crash with an AttributeError.
- The `POST /v1/save` endpoint (the Share Extension's primary API call) was never created.
- The iOS Share Extension Swift files don't exist.
- The feedback router is implemented but never registered — `POST /v1/feedback` returns 404.

The SWE agent's summaries claimed these were fixed, but the actual files don't match. These are mechanical one-line fixes, not architectural problems. The next cycle will retry both tasks with explicit line-by-line verification required before the cycle closes.

## 🔜 Next cycle will work on

Retry 1B-003 (Share Extension with POST /v1/save) and 1B-006 (Feedback UI), with mandatory file-level verification of every claimed fix before the cycle closes. Once these two are merged, the first end-to-end save flow (open a link in Safari → Share → Nexus → saved and summarized) will be testable on a real device.

## ⏳ Waiting on you (blocked tasks)

| Task | What you need to do | What it unlocks |
|---|---|---|
| S3/R2 bucket (1A-008) | Create a Cloudflare R2 or AWS S3 bucket, paste the credentials into `api/.env` | Full-text article storage (currently text is stored inline in Postgres which won't scale) |
| Supabase Apple OAuth config | In Supabase dashboard: Project Settings → Auth → Apple → add App ID, Services ID, private key | Sign in with Apple will fail until this is configured (code is ready, Supabase config is not) |
| Supabase `SUPABASE_SERVICE_ROLE_KEY` in env | Find in Supabase dashboard: Project Settings → API → service_role key → add to Railway/Fly.io env | Magic link email sending won't work without it |
