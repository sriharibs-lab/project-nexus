# Architect Brief — Cycle 2026-06-29

**Health: GREEN** | Phase: 1G — Full Flow Wiring

_Authoritative guidance for all downstream agents (Planner, SWE, Review) this cycle._

---

## Direction

Phase 1F is complete. All six tasks shipped and merged. The next obvious move is 1E (TestFlight prep), but that would be premature — 1G tasks must come first.

**Do not start 1E until 1G is done.** Without AccountView, the HomeView new-collection bottom sheet, and source ingest polling, a beta tester hits dead ends in the first 60 seconds: no way to sign out, no way to add a source to an existing collection, and no visual feedback while ingest runs.

**Wire chat submit (1F-002) first.** It was rejected twice and is still open. It is the single task that completes the FRE → save → chat end-to-end loop on device. The fix is surgical (APIClient SSE key `dict["event"]` → `dict["type"]`). Make this the first task every cycle until it ships.

**Plan/log state drift is a risk.** 1C-006 (search) and 1C-010 (Daily Briefing backend) are marked `[x]` in BUILD_PLAN.md but the agent log shows they were both rejected with request_changes. Before any agent builds on top of search or briefing, SWE should verify these are actually on main via `git log --oneline`.

---

## Recommended 1G Sequencing

1. **1F-002** — Wire chat submit (the SSE key fix). Unblocks end-to-end device test.
2. **1G-001** — AccountView. Closes the avatar menu loop; needed before any real device testing with accounts.
3. **1G-002 + 1G-003** — FRELinkButtons → LinkURLSheetView wiring + URL content-type auto-detect. These are tightly coupled; build together.
4. **1G-004** — HomeView new-collection bottom sheet. Needs 1G-002 done first.
5. **1G-005 + 1G-006** — Add source to existing collection + source ingest polling. Build together; both touch CollectionViewModel.

---

## Compounding Risks

1. **S3/R2 gate (1A-008) has been open 10+ cycles.** The Reader view shows no content to any beta user until this is wired. At 500 TestFlight users saving 5 articles each at ~20KB average, that is ~50MB of article text in Postgres TEXT columns — not a crisis at this scale, but it becomes one post-launch. Srihari must act on this before 1E submission.

2. **Auth contract acknowledgment outstanding.** CHECKPOINT flagged that 1F-008 restored the full FastAPI auth path (iOS → `POST /v1/auth/apple` → Supabase, not Supabase directly from iOS). This is the right architecture but Srihari has not confirmed alignment. If there is a misunderstanding, auth will fail silently during TestFlight signups. Needs a confirmation before 1E.

3. **Highlight colors (amber/sage) not in design tokens.** Shipped in 1D-004 as hardcoded values outside Colors.swift. Low urgency now; becomes expensive to audit post-launch when more screens reference these colors. Add to Colors.swift in any 1G cycle that touches AnnotationStore.

4. **BUILD_PLAN.md / git state drift.** 1C-006 and 1C-010 marked done but may not be on main. Any agent that assumes these are complete and builds on top of them will produce a broken branch. One-time verification required before Phase 1E.
