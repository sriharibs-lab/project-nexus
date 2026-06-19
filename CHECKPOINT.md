# Nexus Build — Cycle Checkpoint
**Date:** 2026-06-19   **Status:** ⚠️ Review recommended

## What was built

Users can now send feedback directly from within the Nexus app. From the Settings screen, tapping "Send Feedback" automatically captures a screenshot of the current screen before opening the feedback form. The form lets users pick a category (Bug, Suggestion, or Other), write a message, and choose whether to include the screenshot. Submitting sends everything to the backend and shows a confirmation screen.

## ✅ Verify it worked

- [ ] **In-app feedback (backend)** — `cd "/Users/srihari/Documents/Projects/Project Nexus/api" && python3 -m pytest tests/routers/test_feedback.py -v` — all 11 tests must pass
- [ ] **In-app feedback (iOS)** — Open Nexus app in Simulator → Settings → Send Feedback → the screenshot shown should capture the Settings screen (not a blank form); submit a test message → spinner appears → thank-you screen shows; Done dismisses
- [ ] **Screenshot toggle** — In feedback form, toggle the screenshot switch off → preview collapses with animation, "Screenshot excluded" label appears
- [ ] **Empty text validation** — Leave text field blank → Send button stays disabled (grayed out)
- [ ] **Category picker** — All three categories (Bug / Suggestion / Other) selectable via segmented control

## 📋 Decisions made this cycle (no action needed)

| What was decided | Options considered | Why |
|---|---|---|
| Screenshot stored inline as base64 in the database (for now) | Upload to Supabase Storage instead | No storage credentials configured yet; base64 works immediately. ~150–400KB per row is fine for MVP volume. Can migrate to a storage URL later with a simple search-and-replace. |
| Screenshot captured before the feedback form opens | Capture on form appear, or manual button | Capturing after navigation would show the feedback form itself — useless. Capturing on tap shows the actual screen the user was looking at. |
| Screenshot passed as an init parameter to the feedback view | Shared ViewModel, UserDefaults | Single-use data for one submission — simplest design with no shared state. |
| JPEG at 50% quality before encoding | PNG (3–5x larger), raw pixel buffer | Keeps POST body under ~500KB in practice. |

## 🚨 Decisions that need your input

**Auth bug in Share Extension (1B-003) — blocked after 2 retries.**
The Save URL feature (Share Extension) has been attempted twice and failed both times. The core bug — a one-line fix in `api/app/middleware/auth.py` changing `= None` to `= Depends(bearer_scheme)` — was not applied correctly in either retry. The second retry also accidentally deleted half of `requirements.txt` (making the API unable to boot) and removed the collection ownership requirement, violating the locked product spec ("Collections are the root. No global library.").

The task needs a clean retry starting from main, touching only `auth.py`. No action needed from you — the next cycle will attempt this again — but you should know this is now blocked twice and the agent will make a third attempt.

**Screenshot storage debt (minor, 1B-006 note).**
Storing screenshots as base64 in Postgres is fine for MVP but will balloon at TestFlight volume. The fix (upload to Supabase Storage, store the URL) should be added as a 1C cleanup task. No action needed now.

## 🔜 Next cycle will work on

1B-003 (Share Extension) will be retried with a narrow, surgical fix — only `auth.py` changes, nothing else. Once that lands, iOS users will be able to share URLs from Safari or any app directly into Nexus without opening the app.

## ⏳ Waiting on you (blocked tasks)

| Task | What you need to do | What it unlocks |
|---|---|---|
| S3/R2 storage bucket (1A-008) | Create a Cloudflare R2 or AWS S3 bucket and paste credentials into `api/.env` | Full-text storage for saved articles; required before production-scale content ingestion and the Reader view |
