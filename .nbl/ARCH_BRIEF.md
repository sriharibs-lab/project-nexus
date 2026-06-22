# Nexus Architect Brief — 2026-06-20 (cycle 7)
**Health: YELLOW** | Phase: 1D — Polish & QA (remaining tasks)

_Authoritative guidance for all downstream agents (Planner, SWE, Review) this cycle._

---

## Summary

Phase 1D is partially complete. Three tasks remain before iOS Simulator testing:
1D-002 (empty/loading/error states), 1D-004 (highlight+annotation), and 1D-006
(App Store assets). 1D-001 (onboarding), 1D-003 (offline cache), and 1D-005
(pipeline performance) are merged and done. The previous YELLOW status holds —
two human gates (S3/R2, APNs) remain open and the `draft/active` collection data
model fix from cycle 6 is still not implemented.

The three remaining tasks are well-scoped and architecturally low-risk individually.
The one compound risk is sequencing: 1D-006 has a dep on 1D-002 (per BUILD_PLAN
`deps=[1D-001,1D-002]`), so 1D-002 must land first.

---

## ARCHITECTURE ASSESSMENT — Each Remaining Task

### 1D-002 — Empty / Loading / Error States

**Scope (confirmed):** Five screens need all three state classes.

| Screen | Empty trigger | Loading trigger | Error trigger |
|---|---|---|---|
| **Home** | `collections.isEmpty` + not loading | Initial `vm.load()` call | API error on load/reload |
| **Collection (Sources tab)** | `items.isEmpty` after load | `vm.isLoading` on tab open | API error fetching items |
| **Collection (Nexus tab / chat)** | Zero messages, no sources added yet | Streaming in progress (EchoPulse already exists) | SSE error (ErrorBanner already exists) |
| **Reader (ItemDetailView)** | Full text not available (already handled inline) | `isLoadingFullContent` (already handled) | Network error on `fetchFullContent` (non-fatal, already handled) |
| **Search** | `.idle` pre-query + `.empty` post-query (both already have state stubs in comments) | `.searching` state (stub in comments) | `.failed` state (stub in comments) |

**Key findings from code audit:**
- HomeView already has a real empty state ("What are you curious about?" + CTA). Done.
- ItemDetailView handles all three states inline already. Done.
- NexusTabView has EchoPulse (loading) and ErrorBanner (error). The empty state
  (zero sources in collection) needs explicit treatment — currently falls through to
  the framing paragraph with "0 sources" which is confusing, not guiding.
- SearchView has state enum stubs in comments (`.idle`, `.searching`, `.results`,
  `.empty`, `.failed`) but the actual `stateContent` view builder is not fully wired.
  This is the largest remaining gap.
- CollectionView/SourcesTabView: loading spinner exists, but empty state when
  sources tab has zero items is missing.

**Architectural guidance:**
- No new ViewModels needed. All state is already tracked in existing VMs. This is
  purely a view-layer addition.
- Empty states must be opinionated: they should name the action the user should take,
  not just say "No items." Use SPEC §5a terminology exactly (e.g., "Add a source" not
  "No content").
- NexusTabView empty state when `collection.sourceCount == 0`: show a prompt to add
  a source before the AI can help. Do not show the chat composer in this state.
- Error states: reuse the existing ErrorBanner pattern from NexusTabView — consistent
  with what's already in the design system.
- Loading states: use `processingPlaceholder` pattern from ItemDetailView or a simple
  `ProgressView()` — do NOT add a new skeleton shimmer system unless directed.

**Effort:** 2–3 hours. No architecture risk.

---

### 1D-004 — Highlight + Annotation in Reader

**Scope:** Tap-to-highlight passages in ItemDetailView, store locally, show on
re-open. Export and AI explain are Phase 2 (SPEC §6.7 "Should Have" for MVP is
highlight + local store only).

**Architecture decision: Local-only storage is correct for v1.**

Rationale:
1. The API has no highlights endpoint. Adding one touches DB schema, migration,
   auth-scoped RLS, and a new API route — that is 1D+1E risk right before TestFlight.
2. The SPEC lists highlights in "Should Have" (not "Must Have") and explicitly scopes
   AI explain/export to a later capability.
3. UserDefaults (or better: FileManager JSON sidecar per item ID, same pattern as
   OfflineContentCache) is sufficient for v1. Highlights are tied to an item UUID,
   so they survive app restarts and work offline.
4. The API integration path is clean: when the highlights endpoint is built in Phase 2,
   the local store becomes a sync buffer (local-first, push on next open).

**Implementation approach:**
- Storage: `HighlightStore` using FileManager JSON (same pattern as
  `OfflineContentCache.swift`). Key: `highlight_<item_uuid>.json`. Each highlight is
  `{ id: UUID, range: (start: Int, end: Int), text: String, color: String, createdAt }`.
- UI: `Text` in SwiftUI does not support arbitrary tap-on-character selection natively.
  Required approach: render `raw_content` using `UITextView` wrapped in
  `UIViewRepresentable` with a custom `UIMenuController` / long-press gesture to
  capture selected range. This is the non-trivial part — SwiftUI has no built-in
  text selection with highlight overlay support.
- Display: On re-open, re-apply highlight backgrounds over the rendered text ranges.
  This is straightforward once ranges are persisted.

**Risk: MEDIUM.** UIViewRepresentable wrapping UITextView is a departure from the
pure SwiftUI pattern everywhere else in the codebase. Test on device (not just
Simulator) for text selection feel. Estimate: 5–8 hours. Not a blocker for Simulator
testing if deferred, but it is in the 1D task list. Recommendation: implement after
1D-002 and 1D-006, with UITextView isolated in its own file.

---

### 1D-006 — App Store Assets

**Scope confirmed:** Three deliverables.

1. **App icon file** — 1024×1024px PNG (required for App Store Connect). The Echo
   mark SVG exists in the design system (`logo.jsx`). Task: export/rasterize at
   1024×1024 and wire into Xcode's `Assets.xcassets/AppIcon.appiconset`. SWE can do
   this; no designer required if the SVG is final.

2. **Screenshot HTML templates** — Required sizes: 6.7" (1290×2796px) and 6.1"
   (1179×2556px). Task: produce HTML/CSS files (matching existing design-system
   step*.html pattern) showing the 5 key screens: Home (collections), Collection
   Nexus tab, Collection Sources tab, Reader, Search. These are marketing-quality
   renders, not live app screenshots, so they can be coded as static HTML with the
   design token colors/fonts. Live simulator screenshots come later in 1E.

3. **Description copy** — Short description (170 chars) + full description (4000
   chars). This is founder copy, not SWE work. Provide a draft for Srihari to approve.
   Suggested structure: hook → problem → solution (3 bullet JTBDs) → CTA.

**Architectural note:** The 1D-006 dep on 1D-002 is meaningful — screenshots must
show polished states, not blank screens. Do not generate screenshots until empty
states are done.

**Effort:** 4–6 hours total (icon: 1h, screenshots: 3h, copy: 1h).
No architecture risk.

---

## SEQUENCING — THIS CYCLE

Execute in this order:

1. **1D-002** — Unblocks 1D-006 and is the highest user-visibility item.
2. **1D-006** — Icon + screenshots + copy draft. Parallelizable with 1D-004 if
   two agents are running.
3. **1D-004** — Highlights. Implement UITextView wrapper in isolation; do not
   refactor existing reader layout.

---

## CARRY-FORWARD RISKS (unresolved from prior cycles)

### CRITICAL — draft/active collection migration not done
The `POST /collections/research` endpoint still creates collections before the user
confirms sources, leaving orphan `source_count = 0` rows. This is a data model bug
that is easier to fix pre-TestFlight than post. Add `status: draft | active` column
(migration 0004), filter HomeView to `status = active`. This is not a 1D task but
must land before 1E.

### WARNING — research_topic source staggering
iOS FRE flow still shows 8 sources appearing simultaneously. iOS-side animation
stagger (430ms between each) is the approved fix. Can land in 1D as a small SWE task.

### GATE — S3/R2 credentials (1A-008)
Srihari to provide R2 credentials before TestFlight. `raw_content` is still in
Postgres TEXT column; at 500 beta users with 5 articles each (avg 20KB), that is
~50MB of unstructured text in the DB. Not catastrophic at this scale, but the
migration to R2 should land before the public App Store submission.

### GATE — APNs key (1C-011)
Daily Briefing push notification delivery still blocked. The briefing scheduler stub
(from last cycle's recommendations) should be wired in this cycle so it's ready to
activate when the key is provided.

---

## BLOCKERS BEFORE SIMULATOR TESTING

None that are code-level. The three remaining 1D tasks can be built and tested in
Simulator without any external credentials. Simulator can exercise:
- Empty/error state rendering (mock data)
- Highlight tap selection (UITextView works in Simulator)
- App icon appearance in SpringBoard

The `draft/active` migration should also be done before Simulator testing to prevent
confusing orphan collections in the test environment.

---

_1D target: complete in this cycle. 1E (TestFlight 500 users) is the next phase.
Critical path: 1D-002 → 1D-006 → TestFlight prep → draft/active migration → 1E._
