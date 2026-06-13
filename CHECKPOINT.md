# Nexus Build — Cycle Checkpoint
**Date:** 2026-06-13   **Status:** ⚠️ Review recommended

## What was built

Nexus now has four fully designed and interactive prototype screens you can open in a browser: a Home screen showing your collections as cards (with AI-ready badges and source counts), a Collection detail screen with two tabs, a Nexus AI tab (chat interface with starter prompts and typing indicator), and a Sources tab (list of saved links with expandable AI summaries). These screens use the locked design tokens — plum accent, soft bloom background, correct typography — and represent the reference that the iOS build will match exactly.

On the backend, a Collection database model was added with a denormalized source count field (so the home screen never needs a slow database count query). The content type validation bug was also fixed: the ingest API now rejects invalid content types instead of silently passing them through to the AI pipeline.

## ✅ Verify it worked

- [ ] **Prototype screens** — `cd prototype && npm run dev`, then open http://localhost:3000 — should show the Home screen with 4 collection cards inside an iPhone frame
- [ ] **Collection detail** — tap any collection card → lands on Nexus tab (AI chat) by default; Sources tab shows saved links with expandable summaries
- [ ] **Nexus AI chat** — tap any starter prompt chip → typing indicator appears ~1.4s → AI response with citation pills appears
- [ ] **Invalid content type rejected** — `POST /v1/ingest` with `content_type: "garbage"` should return 422 Unprocessable Entity (was previously accepted silently)

## 📋 Decisions made this cycle (no action needed)

| What was decided | Options considered | Why |
|---|---|---|
| Next.js prototype uses inline CSS token values, not Tailwind layout classes | Tailwind utilities, CSS Modules, styled-components | Design uses exact pixel values (#7054AB, precise radii, letter-spacing) that don't map cleanly to Tailwind's scale — inline styles give 1:1 fidelity to iOS handoff values |
| Nexus/Sources tab switch uses fade (not slide) | Horizontal slide, mount/unmount | These are distinct modes (chat vs document list), not sibling views — a fade signals "mode switch" better than navigation |
| Mock AI responses generated client-side | Call real API, static placeholder | Prototype validates full interaction flow without requiring credentials or network |
| Collection.items relationship uses passive_deletes=True | cascade="all, delete-orphan" | Fixes ORM/FK conflict flagged in review — the DB FK handles deletion, ORM should not also try to delete-orphan |

## 🚨 Decisions that need your input

**Task 1A-013 (many-to-many items↔collections) was not merged — request_changes verdict.**

The SWE's retry introduced a duplicate Alembic revision ID "0002" (two migration files claim the same revision). This breaks `alembic upgrade head` entirely. The review also found that `content_type` in the ingest request was still a plain string, not the enum, and a leftover `ContentType = Literal[...]` remained in `pipeline.py`. All three issues are auto-fixable by the SWE — no product decision needed from you. The worktree is preserved at `.claude/worktrees/wf_2188d297-b65-9/` for the next retry.

Note: the many-to-many schema change (allowing a link to live in multiple collections) is recorded in the Key Decisions Log but has not been implemented yet. It will be re-attempted next cycle.

## 🔜 Next cycle will work on

Retry 1A-013 (fix the three code issues and merge the many-to-many schema). Once that lands, the next unblocked tasks are iOS SwiftUI architecture scaffold (1B-001b) and the API client layer (1B-004) — these are the first steps toward a working iPhone app.

## ⏳ Waiting on you (blocked tasks)

| Task | What you need to do | What it unlocks |
|---|---|---|
| S3/R2 storage (1A-008) | Create an R2 or S3 bucket and paste credentials into `api/.env` | Stores full article text in cloud instead of PostgreSQL TEXT — needed before production launch, not before TestFlight |
