# Nexus Build — Cycle Checkpoint
**Date:** 2026-06-28   **Status:** ⚠️ Review recommended

## What was built

The FRE (First Run Experience) now feels like a real product. When you open the app, the avatar button in the top-right shows your actual initials, taps open a Liquid Glass bloom menu with Settings, Feedback, and Sign Out. The rotating words underneath "Start a collection on" come from your personal interest profile stored on the server — not hardcoded. The trending chips (AI platform shifts, Ozempic & longevity, etc.) are now pulled live from Google Trends RSS at load time with a silent fallback. And the "+" button in the composer opens a full URL paste sheet where you can paste any link, pick the content type (Website, PDF, YouTube), and save it as a new collection — the app creates the collection and starts ingesting the content immediately in the background.

## Verify it worked

- [ ] **Avatar button** — Open the app on device, tap the circular button top-right of the FRE screen — menu should bloom out from the top-right with a spring animation; avatar button should disappear while menu is open. Tap Settings — settings sheet should rise after ~0.22s delay.
- [ ] **Personalized topics** — Sign in, wait 5 seconds, then open the FRE screen — the rotating word should cycle through topics fetched from `GET /v1/users/me/interest-topics` (or defaults if no profile yet).
- [ ] **Live trending chips** — Open the FRE Topics screen (onboarding step 2): within 5 seconds of appearing, the TRENDING NOW row should show a green dot and 4 chips from Google Trends. Kill network and reload — 4 static chips appear, no error shown.
- [ ] **URL paste sheet** — Copy any https:// URL to clipboard, tap "+" in the FRE composer or any of the Website/PDF/YouTube buttons — sheet opens at medium detent with URL auto-filled. Tap Save — collection created, app navigates to it.
- [ ] **Backend tests** — `cd api && python -m pytest tests/routers/test_users_interest_topics.py tests/test_1f007_trending.py -v` — 23 tests should pass.

## Decisions made this cycle (no action needed)

| What was decided | Options considered | Why |
|---|---|---|
| Google Trends RSS for live trending (no API key) | NewsAPI (paid key), Twitter trending (OAuth + paid) | Free, no credentials, available before user signs in |
| Avatar data persisted in UserDefaults app group | Memory only, API fetch per launch | Apple only sends name/email on first Sign in with Apple — must persist |
| Fire-and-forget ingest after URL paste save | Block until ingest done, show progress in sheet | Ingest takes seconds-to-minutes; blocking the user is bad UX |
| 15-minute in-process TTL cache for trending | Redis, CDN, no cache | No new dependencies; FRE is low-traffic at beta scale |
| Shimmer skeleton while trending loads | Spinner, nothing | Prevents layout shift when data arrives |

## Decisions that need your input

**1F-008 restores the full auth contract (AuthView, AuthViewModel, backend auth.py with `verify_otp` and `sign_in_with_apple`).** This means the iOS app now calls our backend to exchange Apple's identity token, not Supabase directly. The Supabase service_role key stays server-side only. This was the original design — but it's worth confirming you're aligned before the next iOS device test: when you tap "Sign in with Apple," it calls `POST /v1/auth/apple` on our FastAPI backend, which exchanges with Supabase and returns Nexus tokens. The dev bypass ("Continue without account") still works as before.

## Next cycle will work on

1F-002 (wire chat submit) is the last unresolved FRE blocker — fixing the SSE event key from `dict["event"]` to `dict["type"]` in APIClient. Once that's done, the entire FRE → save → chat loop runs on real device. That unlocks the first true end-to-end iPhone test.

## Waiting on you (blocked tasks)

| Task | What you need to do | What it unlocks |
|---|---|---|
| S3/R2 bucket (1A-008) | Create an R2 or S3 bucket, paste credentials into `api/.env` as `R2_ACCESS_KEY`, `R2_SECRET_KEY`, `R2_BUCKET` | Full-text storage for extracted articles; Reader view shows real content |
| APNs key (1C-011) | Download an APNs key from Apple Developer portal, paste path into project config | Daily Briefing push notifications |

---

# Nexus Build — Cycle Checkpoint (1G-005)
**Date:** 2026-06-29   **Status:** ⚠️ Review recommended

## What was built

Sources tab now has an "Add a source" flow. When you're on the Sources tab of any Collection, a "+" button appears in the navigation bar top-right. Tapping it opens the same URL paste sheet from Phase 1F, but in a new "add mode" — the collection name field is hidden (you're already in the collection), the title reads "Add a source", and the save button says "Add". Tapping "Add" POSTs directly to `/v1/ingest` with the collection's ID already bound — no collection creation step. On success the sheet dismisses and the Sources list refreshes. Also fixed in this cycle: the SSE terminal-event key bug (dict["event"] → dict["type"]) that was blocking end-to-end chat testing, and the auth/profile API surface that was accidentally deleted.

## Verify it worked

- [ ] **Add a source** — Open any Collection, tap "Sources" tab — a "+" should appear top-right. Tap it. Sheet opens titled "Add a source" with no collection name field. Paste a URL. Tap "Add" — sheet closes, Sources list refreshes showing the new item with "Queued" status.
- [ ] **Chat submit** — Open any Collection, tap "Nexus" tab, type a message, tap the send arrow or press Return — message should appear in the chat thread and the AI should respond (requires backend running with ANTHROPIC_API_KEY).
- [ ] **Auth flow** — Sign out, sign back in with Apple or magic link — should work end-to-end (auth API surface restored).

## Decisions made this cycle (no action needed)

| What was decided | Options considered | Why |
|---|---|---|
| Separate `LinkURLSheetMode` enum for create vs add | Two separate sheet views, flag param | Single view with mode makes the two flows easy to maintain together without diverging |
| canSubmit in add mode = isURLValid only (no name check) | Same canSubmit for both modes | In add mode the collection name field is hidden — there's nothing to validate |
| Toolbar "+" hidden on Nexus tab | Always visible | The button is only meaningful on Sources tab; showing it on Nexus tab is confusing |
| Sheet presented at .medium then .large detent | Fixed .large, fixed .medium | Medium first feels like a quick action; user can expand if they need to see more |

## Waiting on you (blocked tasks)

| Task | What you need to do | What it unlocks |
|---|---|---|
| S3/R2 bucket (1A-008) | Create an R2 or S3 bucket, paste credentials into `api/.env` | Reader view shows real article content |
| APNs key (1C-011) | Download an APNs key from Apple Developer portal | Daily Briefing push notifications |
