# Nexus Build — Cycle Checkpoint
**Date:** 2026-06-13   **Status:** ⚠️ Review recommended

## What was built

Nexus now enforces the core product rule: every saved item must belong to a Collection, with no floating or orphaned content. The backend was updated so that creating, listing, and deleting items all go through a Collection — the data shape now mirrors what the iOS app will see. Separately, the web prototype's visual design is now fully connected to the design system: all colors, fonts, spacing, and motion values from the token files are live in the browser, including automatic dark-mode switching.

## ✅ Verify it worked

- [ ] **Collections enforcement** — Start the API (`cd api && uvicorn app.main:app`), then `POST /v1/ingest` without a `collection_id` body field. It must return HTTP 422. With a valid `collection_id`, it must return HTTP 202.
- [ ] **Collection ownership** — `GET /v1/collections/{id}/items` with a collection owned by a different user must return HTTP 404.
- [ ] **Token integration** — `cd prototype && npm run dev`, open http://localhost:3000. Body background must show the plum bloom radial gradient (not white/black). Switch OS to dark mode — background should flip to deep gray (#0F0D13). Inspect `:root` in DevTools and confirm ~80 `--nx-*` CSS variables are present.

## 📋 Decisions made this cycle (no action needed)

| What was decided | Options considered | Why |
|---|---|---|
| Items use CSS variables as truth; Tailwind aliases point to var(--nx-*) | Inline values in Tailwind config; build-time JSON plugin | CSS variables let dark mode flip automatically at runtime without extra Tailwind class prefixes |
| Dark mode page gradient not yet defined | Add dark gradient; keep light gradient in dark | The source design token file (colors.json) has no dark.page entry — gap logged, needs a design decision before prototype screens are authored |
| Dead credentials parameter in auth.py left as cleanup | Remove now; escalate | Auth works correctly via the existing header path; the parameter has no security or functional impact — clean up in next cycle |

## 🚨 Decisions that need your input

**Collections: one item = one collection (no multi-collection linking in v1)**
The data model was built so each saved item belongs to exactly one collection, matching SPEC §5a. The alternative — letting items appear in multiple collections via a join table — was explicitly deferred. This is the right call for launch, but worth a quick confirmation: is there any saving flow you envision where a user would want one link to live in two collections simultaneously?

**Dark-mode background gradient missing from design tokens**
The light-mode plum bloom gradient exists in `design-system/tokens/colors.json` but there is no dark-mode equivalent. Right now, dark mode shows a dark background color for most elements but the page body would still render the light gradient. Before any prototype screens are built, a dark-mode page background value needs to be added to `colors.json`. What should the dark-mode page background look like — a deep neutral, a very dark plum tint, or something else?

## 🔜 Next cycle will work on

Next up: the iOS app architecture scaffold (task 1B-001b) — folder structure, MVVM pattern, and root navigation — which unlocks every subsequent iOS screen. In parallel, CSS prototype screens (Home/Collections list and Collection detail) can begin now that tokens are live.

## ⏳ Waiting on you (blocked tasks)

| Task | What you need to do | What it unlocks |
|---|---|---|
| S3/R2 full-text storage (1A-008) | Create an R2 or S3 bucket and paste credentials into `api/.env` | Full-text article content persisted after ingestion; required before TestFlight |
