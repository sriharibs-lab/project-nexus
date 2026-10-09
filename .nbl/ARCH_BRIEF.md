# Architect Brief — Cycle 2026-06-29 (evening)

**Health: GREEN** | Phase: 1G — Full Flow Wiring (final tasks)

_Authoritative guidance for all downstream agents (Planner, SWE, Review) this cycle._

---

## Direction

1G-001, 1G-002, and 1G-005 shipped this cycle. Remaining 1G tasks are 1G-003, 1G-004, 1G-006 — all unblocked. These three tasks close every identified dead end before TestFlight. Complete them, then move to 1E.

**One new task must be inserted before 1E: restore the Apple Sign-In JWT exchange (call it 1G-007).** CHECKPOINT.md documents that the iOS app currently sends Apple's raw user identifier as a bearer token, bypassing the `POST /v1/auth/apple` FastAPI exchange. This is a security defect and a TestFlight blocker. Every user session created against this code is based on an unvalidated identity claim. It must be fixed before 500 beta users sign in.

**SSE field inconsistency needs a live device test.** CHECKPOINT notes that `streamSSE` reads `dict["type"]` for terminal events, but `handleSSEEvent` in ResearchViewModel still dispatches on `dict["event"]`. These are semantically different fields — `event` is the SSE protocol line, `type` is the JSON payload field. If both are expected, the code is fine; if only one exists in the backend payload, Research flow will silently hang at "Researching...". Verify on device before TestFlight; do not ship without confirming.

---

## Recommended task order this cycle

1. **1G-007** (new) — Apple Sign-In JWT exchange fix. Highest risk. Schedule before 1E.
2. **1G-003** — URL content-type auto-detect. Small, closes URL paste dead end.
3. **1G-004** — HomeView new-collection choice sheet. Closes the primary "+" dead end.
4. **1G-006** — Source ingest auto-polling. Completes the add-source flow.
5. Live device SSE test — confirm Research flow terminal events land correctly.

---

## Compounding Risks

1. **Auth contract defect (1G-007 — HIGH).** Apple's raw user ID accepted as a bearer token. This is wrong by design and pre-existing. Every cycle that builds account features on top of this makes the fix more expensive. Fix before TestFlight. Do not send beta invites until this is verified.

2. **SSE field inconsistency (MEDIUM).** `dict["event"]` vs `dict["type"]` in Research flow. If wrong, users see a hung "Researching..." state with no error. Verify on device; costs nothing to check.

3. **R2 storage (1A-008 — LOW for beta, HIGH for launch).** This gate has been open since cycle 1. Reader view shows no article text until wired. Fine for 500 TestFlight users; not fine at public launch scale. Srihari must create the R2 bucket and paste credentials before 1E submission.

4. **Highlight tokens missing from design system (LOW).** Amber/sage highlight colors in AnnotationStore are hardcoded outside Colors.swift. Add them before Phase 2 or they become a design drift debt across Android/Web.
