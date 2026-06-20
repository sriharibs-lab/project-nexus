# Nexus Build — Cycle Checkpoint
**Date:** 2026-06-20   **Status:** ⚠️ Review recommended

## What was built

Nexus can now hold a full conversation about any collection. The chat tab streams AI responses grounded in your saved sources, inline cites each source with a tappable chip, and remembers the last 6 turns of the conversation — all inside a polished iOS prototype you can open in a browser right now. The Sources tab is also significantly more usable: every source now shows a colour-coded content-type badge, AI-generated topic tags, and you can swipe left to delete a source or pull down to refresh the list.

A critical startup bug was also fixed: the backend was crashing at boot because of a missing Python enum — this is now resolved and all API endpoints are reachable again.

## ✅ Verify it worked

- [ ] **Nexus chat UI** — Open `nexus-design-system-extracted/design_handoff_nexus_ios/nexus-tab-chat.html` in a browser. Tap a starter prompt chip → you should see the EchoPulse animation, then text stream in token by token with `[Source N]` becoming tappable citation chips. Switch to the Sources tab and back — chat state is preserved.
- [ ] **Sources tab polish** — Open `nexus-design-system-extracted/design_handoff_nexus_ios/home.html`, navigate to a collection → Sources tab. Each row should show a colour-coded icon badge (blue=article, red=video, plum=PDF) and 2–3 tag chips below the title. Drag a row left past ~72px — a red Delete button should snap into view. Drag to the top and pull down — pull-to-refresh indicator should appear.
- [ ] **Startup fix** — `from app.models import CollectionCreatedBy` in any Python shell (pointing at the api directory) should succeed without ImportError.

## 📋 Decisions made this cycle (no action needed)

| What was decided | Options considered | Why |
|---|---|---|
| CollectionCreatedBy as Python str+enum, not a Postgres native enum type | Postgres enum, plain string constants | DB column is already VARCHAR from migration 0003 — no migration needed; str mixin means JSON serialization and Pydantic work with zero config |
| Conversation history is client-owned (rolling 6 turns), not stored in DB | Store in PostgreSQL (SPEC §9a Pillar 4), store in Redis | Unblocks multi-turn chat with zero schema changes; full episodic memory (50 turns, persistent) is deferred to 1D |
| EchoPulse uses the Echo brand mark for the AI "thinking" animation | Generic spinner, typing dots, skeleton shimmer | The Echo mark IS the brand — reinforcing it on every AI response builds identity |
| Citation chips parse [Source N] from model output, not a custom syntax | Custom [[1]] syntax, structured JSON citations | The model already outputs this format; no prompt changes needed; unambiguous and matches NotebookLM |
| PDF gets plum accent in ContentTypeIcon; all other types get desaturated tints | Plum for all types, single muted gray for all | Limits accent bleed to one high-value type — restrained and intentional, per CLAUDE.md |
| SwipeRow uses Pointer Events (not Touch Events) | Touch Events, react-use-gesture library | Works on both desktop prototype (mouse) and iPhone (touch) with a single code path; no new library dependency |

## 🚨 Decisions that need your input

**Multi-turn memory is client-owned for now.** The SPEC calls for persistent conversation memory (last 50 turns in PostgreSQL). This cycle we implemented client-side rolling 6-turn history instead — it works for the prototype but the full episodic memory is deferred to 1D. If you want to move this up in priority, let me know — it's a backend schema change + iOS client change that need to land together.

## 🔜 Next cycle will work on

The 1C phase is nearly complete — the only remaining 1C items are the Daily Briefing iOS UI (1C-011, blocked on your APNs key) and Share Extension (1B-003). Next cycle can move into 1D polish: empty/loading/error states, onboarding flow, and offline reading cache — making the app feel complete enough for TestFlight.

## ⏳ Waiting on you (blocked tasks)

| Task | What you need to do | What it unlocks |
|---|---|---|
| Daily Briefing iOS UI (1C-011) | Generate an APNs key in Apple Developer portal → paste into `api/.env` as `APNS_KEY` | Push notifications + Daily Briefing card stack UI on the home screen |
| S3/R2 full-text storage (1A-008) | Create an R2 or S3 bucket → paste credentials into `api/.env` | Full article text stored in cloud storage instead of Postgres TEXT; required before TestFlight |
