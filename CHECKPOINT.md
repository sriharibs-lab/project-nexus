# Nexus Build — Cycle Checkpoint
**Date:** 2026-06-29   **Status:** ⚠️ Review recommended

## What was built

The app now has a proper account screen: tap the avatar circle in the top-left of your collections list and a sheet slides up showing your name, email, and a Sign Out button — your initials are computed from your Apple ID and displayed in a plum circle. Starting a collection from a link now actually works end-to-end: the three buttons on the first-run screen (Website, PDF, YouTube) open the URL paste sheet pre-set to the right type, and completing it navigates you directly to the new collection. Inside any existing collection, a new "+" button appears in the top-right of the Sources tab — tap it, paste a URL, and the source is added to that collection immediately without creating a new one.

## Verify it worked

- [ ] **Account screen** — Open the app with at least one collection, tap the initials circle in the top-left of the list; sheet should open showing your initials at large size, your display name (or just email if name unavailable), and a Sign Out button. Tapping Sign Out should return to the auth screen.
- [ ] **FRE link buttons** — From the first-run screen, tap "Website," "PDF," or "YouTube" — the URL paste sheet should open with the matching type chip already selected. Paste a valid URL and tap Save — app should navigate to the new collection.
- [ ] **Add source to collection** — Open any collection, tap Sources tab, tap "+" top-right — sheet should open titled "Add a source" with no collection name field. Paste a URL, tap Add — sheet dismisses and the source appears in the list with a Queued status.

## Decisions made this cycle (no action needed)

| What was decided | Options considered | Why |
|---|---|---|
| Avatar in HomeView leading toolbar (left side) | Trailing (conflicts with +), tab bar | iOS convention for profile access; trailing slot taken by + button |
| AvatarCircle as reusable component (not inline) | Inline in HomeView only | AccountView also needs it at 72pt; shared component avoids duplication |
| Initials fallback: name words → email first char → "N"/"?" | Always show SF Symbol person icon | Initials feel personal; "N" is branded fallback; "?" signals incomplete data |
| LinkURLSheetMode enum (create vs addToCollection) | isAddMode Bool, two separate sheets | Named enum is self-documenting and carries collectionId cleanly |
| canSubmit in add mode = URL valid only | Same formula for both modes | Collection name field is hidden in add mode — nothing to validate |
| Refresh triggered at CollectionView call site, not inside sheet | Pass CollectionViewModel into sheet, NotificationCenter | Loose coupling; sheet only signals success, caller decides what to do |

## Decisions that need your input

**1G-001 review flagged a pre-existing auth contract issue:** when you tap Sign In with Apple, the current iOS code sends Apple's raw user identifier directly as a session token, bypassing the `POST /v1/auth/apple` FastAPI exchange. This was present before this cycle and is not introduced by the Account screen work. It needs to be fixed before TestFlight — the backend needs to validate the Apple identity token and issue Nexus JWTs. This is the same decision flagged in the last checkpoint about which auth path you want (iOS → FastAPI → Supabase, which 1F-008 implemented). Confirm you're aligned so the wiring task can be scheduled.

**1G-005 review noted an SSE event field inconsistency:** `streamSSE` now correctly reads `dict["type"]` for terminal events (fixed this cycle), but `handleSSEEvent` in ResearchViewModel still dispatches on `dict["event"]`. These may be two different fields in the backend SSE format — worth confirming with a live test so chat events are not silently dropped.

## Next cycle will work on

1G-003 (URL auto-detect: youtube.com → YouTube chip, .pdf → PDF chip), 1G-004 (HomeView + button opens a choice sheet: "Research a topic" vs "Start with a link"), and 1G-006 (ingest status auto-polling every 4 seconds until all sources reach a terminal state). Completing these closes every identified dead end before TestFlight.

## Waiting on you (blocked tasks)

| Task | What you need to do | What it unlocks |
|---|---|---|
| S3/R2 bucket (1A-008) | Create an R2 or S3 bucket, paste credentials into `api/.env` as `R2_ACCESS_KEY`, `R2_SECRET_KEY`, `R2_BUCKET` | Full-text storage for extracted articles; Reader view shows real content |
| APNs key (1C-011) | Download an APNs key from Apple Developer portal, add path + key ID + team ID to `api/.env` | Daily Briefing push notifications delivered to device |
