---
nbl_version: "1"
cycle_policy:
  max_tasks_per_run: 3
  allow_phases: ["0A", "1A", "1B", "1C"]
---

# Project Nexus — Build Plan
**Last Updated:** 2026-06-11 (cleanup: design tokens filled, stale Design Prompt v2 removed)  
**Current Phase:** Phase 1D — Polish & QA → DONE → 1E Launch Prep

---

## Status Key
- `[ ]` Not started
- `[~]` In progress
- `[x]` Done
- `[!]` Blocked

---

## Phase 0 — Foundation (Now)
- [x] Write product spec (SPEC.md) <!-- nbl:id=0-001 status=done -->
- [x] Resolve open questions (personas, platform roadmap, content types, connections behavior) <!-- nbl:id=0-002 status=done -->
- [x] **Design System** — v1 complete, handoff package in nexus-design-system-extracted/ <!-- nbl:id=0A-design status=done -->
- [x] Set up GitHub repo (monorepo: `/prototype`, `/app-ios`, `/api`, `/design-system`) <!-- nbl:id=0-003 status=done -->
- [x] Domain + waitlist landing page <!-- nbl:id=0-004 agent=swe deps=[] est=3h -->

### Phase 0A — Design System & Prototype (Before any native build)
**Assets (Figma + source files):**
- [ ] Logo: wordmark + symbol (SVG, light + dark variants, app icon)
- [ ] Custom icon set (SVG, coherent style)
- [ ] Typography selection: display serif + reading font (license or source)
- [ ] Color palette: primitives + semantic tokens (dark mode first)
- [ ] Motion spec: duration + easing curves for key interactions

**Design tokens (platform-agnostic JSON):**
- [x] `/design-system/tokens/colors.json` — filled from lTheme() + README.md <!-- nbl:id=0A-tok-colors status=done -->
- [x] `/design-system/tokens/typography.json` <!-- nbl:id=0A-tok-type status=done -->
- [x] `/design-system/tokens/spacing.json` <!-- nbl:id=0A-tok-spacing status=done -->
- [x] `/design-system/tokens/motion.json` <!-- nbl:id=0A-tok-motion status=done -->

**Web Prototype (`/prototype/` — Next.js 14):**
- [x] Project scaffold: Next.js + Tailwind + Framer Motion <!-- nbl:id=0A-proto-scaffold status=done -->
- [x] Token integration (CSS custom properties from JSON) <!-- nbl:id=0A-tok-css agent=swe deps=[0A-tok-colors,0A-tok-type] est=2h -->
- [x] Core screens: Home (collections), Collection detail, Nexus tab, Sources tab <!-- nbl:id=0A-screens agent=swe deps=[0A-tok-css] est=6h -->
- [x] Responsive (mobile 390px primary, desktop 1280px) <!-- nbl:id=0A-responsive agent=swe deps=[0A-screens] est=2h -->

---

## Phase 1 — MVP (Target: T+10 weeks)

### 1A — Backend Foundation (Weeks 1–3)
- [x] Supabase project setup (auth, DB) — project yrzsbkljaqtwtbzeoirs, live <!-- nbl:id=1A-001 status=done -->
- [x] PostgreSQL schema: users, items, tags, embeddings, feedback, ai_telemetry, performance_logs, audit_logs — migrations 0001+0002 live <!-- nbl:id=1A-002 status=done -->
- [x] pgvector extension + OpenAI text-embedding-3-small — wired in ingestion pipeline <!-- nbl:id=1A-003 status=done -->
- [x] FastAPI skeleton: auth (JWKS/ES256), items CRUD, feedback, ingest — live <!-- nbl:id=1A-004 status=done -->
- [x] Content extraction service — Jina+trafilatura(fallback) wired into _process_job <!-- nbl:id=1A-005 status=done -->
- [x] YouTube transcript ingestion — wired <!-- nbl:id=1A-006 status=done -->
- [x] Podcast transcript ingestion (Deepgram Nova-3) — wired <!-- nbl:id=1A-007 status=done -->
- [!] S3/R2 bucket for full-text storage <!-- nbl:id=1A-008 agent=none gate=HUMAN:cloud_storage_credentials -->
- [x] Anthropic API integration: summarize + insights pipeline — Claude Haiku 4.5, cost-tracked <!-- nbl:id=1A-009 status=done -->
- [x] Background job queue (async AI processing) — upgraded to pgqueuer (durable, Postgres-backed); Procfile added <!-- nbl:id=1A-010 status=done -->
- [x] Feedback API: POST /v1/feedback + DB model + screenshot_url field <!-- nbl:id=1A-011 status=done -->
- [x] Collections model + migration — items need collection_id per SPEC §5a (IA locked: no global library) <!-- nbl:id=1A-012 agent=swe deps=[1A-001] est=2h -->
- [x] Items ↔ Collections many-to-many — collection_items join table; updated ingest + items router; migration 0003 live; source_count in CollectionResponse <!-- nbl:id=1A-013 status=done -->

### 1B — iPhone App Foundation (Weeks 1–3, parallel)
- [x] Xcode project setup — SwiftUI, iOS 17+, bundle ID app.nexus, at app-ios/Nexus/ <!-- nbl:id=1B-001 status=done -->
- [x] SwiftUI architecture scaffold — MVVM, DesignSystem/Core/Models/Features, NexusApp root routing with auth state, dev bypass button <!-- nbl:id=1B-001b status=done -->
- [x] Sign in with Apple + Magic link email — both in v1 (Apple required by App Store; magic link = passwordless, no reset flows, cross-platform ready) <!-- nbl:id=1B-002 agent=swe deps=[1B-001,1A-001] est=4h -->
- [x] Share Extension: capture URL from any app — NexusShare target, custom SwiftUI UI, collection picker, App Groups token sharing <!-- nbl:id=1B-003 status=done -->
- [x] API client layer (async/await) — URLSession+async/await, snake_case ↔ camelCase, auth header injection, typed endpoints <!-- nbl:id=1B-004 status=done -->
- [x] Design tokens: colors, typography, spacing (Swift from design-system/tokens/*.json) — Colors.swift, Typography.swift, Spacing.swift, Motion.swift <!-- nbl:id=1B-005 status=done -->
- [x] In-app feedback UI: Settings → "Send Feedback" → auto-screenshot capture → text + screenshot toggle → POST /feedback <!-- nbl:id=1B-006 agent=swe deps=[1B-001,1A-011] est=3h -->

### 1C — Core Features (Weeks 4–7)
- [x] `POST /collections/research` SSE endpoint — AI-seeded collection creation, streams source rows (Claude Sonnet); gates the "Research a topic" FRE hero flow <!-- nbl:id=1C-001 agent=swe deps=[1A-009,1A-013] est=4h -->
- [x] Library view: collection home screen, item cards with title/tags/summary preview, ingest status indicator <!-- nbl:id=1C-002 agent=swe deps=[1B-001b,1B-004,1B-005] est=5h -->
- [x] Item detail / Reader view: clean full-screen reading, title, summary, key insights, tags <!-- nbl:id=1C-003 agent=swe deps=[1C-002] est=4h -->
- [x] Sources tab polish: tag chips, content-type icon, swipe-to-delete, pull-to-refresh — **SwiftUI only, app-ios/Nexus/Nexus/Features/Collection/SourcesTabView.swift** <!-- nbl:id=1C-004 agent=swe deps=[1C-002] est=3h -->
- [x] "Research a topic" FRE flow: iOS screen that calls `POST /collections/research`, streams and shows sources arriving <!-- nbl:id=1C-005 status=done -->
- [x] Full-text + semantic search: `GET /v1/search?q=` backend + iOS search bar + results screen <!-- nbl:id=1C-006 status=done -->
- [x] "Ask your library" — Nexus tab: streaming chat UI calling `POST /collections/{id}/chat` (SSE) — **SwiftUI only, app-ios/Nexus/Nexus/Features/Collection/NexusTabView.swift** <!-- nbl:id=1C-007 agent=swe deps=[1C-003] est=6h -->
- [x] `POST /collections/{id}/chat` SSE endpoint — RAG over collection items (pgvector similarity + Claude Sonnet streaming) <!-- nbl:id=1C-008 agent=swe deps=[1A-003,1A-009,1A-013] est=5h -->
- [x] Interest profile background computation — update `user_interest_profiles` after each ingest <!-- nbl:id=1C-009 agent=swe deps=[1A-010] est=2h -->
- [x] Daily Briefing backend pipeline — digest generation from user's interest profile + recent items <!-- nbl:id=1C-010 status=done -->
- [!] Daily Briefing iOS card stack UI + push notification delivery <!-- nbl:id=1C-011 agent=swe deps=[1C-010] est=4h gate=HUMAN:apns_key -->

### 1D — Polish & QA (Weeks 8–9)
- [x] Onboarding flow (beautiful, minimal — 3 screens: welcome, topic picker, first collection prompt) <!-- nbl:id=1D-001 agent=swe deps=[1C-007] est=4h -->
- [x] Empty states, loading states, error states (all screens: home, collection, reader, chat, search) <!-- nbl:id=1D-002 agent=swe deps=[1C-002] est=4h -->
- [x] Offline reading: cache article raw_content in UserDefaults/FileManager on reader open <!-- nbl:id=1D-003 agent=swe deps=[1C-003] est=3h -->
- [x] Highlight + annotation in reader (tap-to-highlight, stored locally, shown in reader) <!-- nbl:id=1D-004 agent=swe deps=[1C-003] est=5h -->
- [x] Performance: save-to-summary target < 10s — audit ingest pipeline, add timing logs, optimize Jina timeout <!-- nbl:id=1D-005 agent=swe deps=[1C-009] est=3h -->
- [x] App Store assets: icon, screenshots (6.7" + 6.1"), preview video script, description copy <!-- nbl:id=1D-006 agent=swe deps=[1D-001,1D-002] est=4h -->

### 1F — FRE & UX Polish (bugs + enhancements from first device test)

**Critical fixes:**
- [x] Auth screen: replace `AuthPlaceholderView` stub with proper sign-in UI (Sign in with Apple button + "Continue as dev" secondary CTA) matching Nexus design system <!-- nbl:id=1F-001 agent=swe deps=[] est=2h -->
- [x] Wire chat submit: NexusTabView composer send button + return key currently do nothing — connect to `vm.send()` <!-- nbl:id=1F-002 status=done -->

**Bugs:**
- [x] FRE trending icon: `arrow.up.right` looks like "open in new tab" — replace with `chart.line.uptrend.xyaxis` SF Symbol <!-- nbl:id=1F-003 agent=swe deps=[] est=0.5h -->
- [x] Keyboard dismiss: tapping outside chat composer in NexusTabView does not dismiss keyboard <!-- nbl:id=1F-004 agent=swe deps=[1C-007] est=0.5h -->

**Enhancements:**
- [x] Avatar button: add circular avatar button top-right of FRE input screen (shows initials, taps to open settings) <!-- nbl:id=1F-005 agent=swe deps=[1F-001] est=1h -->
- [x] FRE rotating topics from user profile: pull `freTopics` from stored user interest profile instead of hardcoded array <!-- nbl:id=1F-006 agent=swe deps=[1C-009] est=1.5h -->
- [x] Live trending chips: fetch top 4 trending topics from public source (NewsAPI headlines or Google Trends RSS) at FRE load time; fall back to static list if unavailable <!-- nbl:id=1F-007 agent=swe deps=[] est=2h -->
- [x] FRE composer `+` button: tapping opens a link/URL paste sheet so user can start a collection from a URL directly from the composer <!-- nbl:id=1F-008 agent=swe deps=[] est=1.5h -->

### 1G — Full Flow Wiring (device-tested gaps)

**Account & Settings:**
- [ ] Account screen — `AccountView.swift` showing user initials avatar + email from `AuthManager.shared`; "Sign Out" button; presented as sheet from avatar menu "Account" row (wire `FREAvatarMenuCard` `onClose` → present AccountView) and as a row in `SettingsView` <!-- nbl:id=1G-001 agent=swe deps=[1F-005] est=2h -->

**Starting a collection from a link:**
- [ ] FRELinkButtons tap → open LinkURLSheetView — wire Website/PDF/YouTube buttons in `FRELinkButtons` to present `LinkURLSheetView(initialContentType:)`; `onComplete(collectionId)` calls parent `ResearchFlowView.onComplete` to navigate to new `CollectionView` <!-- nbl:id=1G-002 agent=swe deps=[1F-008] est=2h -->
- [ ] URL content-type auto-detect — in `LinkURLSheetView`, when URL text changes detect: youtube.com/youtu.be → `.youtube`; ends with `.pdf` → `.pdf`; otherwise `.website`; update `contentType` chip automatically <!-- nbl:id=1G-003 agent=swe deps=[1G-002] est=1h -->
- [ ] HomeView new-collection choice — when user has existing collections and taps "+", present bottom sheet offering "Research a topic" (opens ResearchFlowView) and "Start with a link" (opens LinkURLSheetView directly); both navigate to the new collection on complete <!-- nbl:id=1G-004 agent=swe deps=[1G-002] est=1.5h -->

**Managing sources in a collection:**
- [ ] Add source to existing collection — "+" button in SourcesTabView toolbar opens `LinkURLSheetView` pre-bound to the current `collectionId`; skips collection creation step (posts only to `/v1/ingest`); dismisses and refreshes sources list on success <!-- nbl:id=1G-005 agent=swe deps=[1F-008] est=2h -->
- [ ] Source ingest auto-polling — `CollectionViewModel` polls `GET /v1/collections/{id}/items` every 4s while any item has `ingestStatus` ∈ {queued, processing}; cancels when all items reach a terminal state; updates items array in place without full reload <!-- nbl:id=1G-006 agent=swe deps=[1G-005] est=1.5h -->

### 1E — Launch Prep (Week 10)
- [ ] TestFlight beta (500 users)
- [ ] Bug bash
- [ ] Waitlist landing page live
- [ ] App Store submission

---

## Phase 2 — Growth (T+10 to T+24 weeks)
- [ ] Sign in with Google (extends auth to Android + web users)
- [ ] Conversation Mode (full RAG chat with library)
- [ ] Discovery engine (AI-suggested content from interest graph)
- [ ] Sharing: public collections
- [ ] Web clipper (Safari extension / browser extension)
- [ ] Weekly Synthesis report
- [ ] Bulk import from Pocket / Instapaper / Readwise
- [ ] Android scoping

---

## Phase 3 — Platform (T+24 weeks+)
- [ ] Team Spaces
- [ ] Android app
- [ ] Web app
- [ ] Integrations: Notion, Obsidian, Slack
- [ ] Creator tools / public Nexus profiles
- [ ] API (developer access)

---

## Key Decisions Log
| Date | Decision | Rationale |
|---|---|---|
| 2026-06-04 | iPhone first | Fastest to market, highest-value users, best UX control |
| 2026-06-04 | Claude (Anthropic) as AI backbone | Best long-context reasoning, zero data retention available |
| 2026-06-04 | Subscription-only monetization | No ads, no data selling, aligned incentives |
| 2026-06-04 | pgvector over Pinecone/Weaviate | Fewer moving parts, unified DB, sufficient for v1 scale |
| 2026-06-04 | FastAPI over Node/Rails | Python AI ecosystem, async-native, team expertise |
| 2026-06-04 | Podcast + YouTube in v1 | Full transcript ingestion + summary for both |
| 2026-06-04 | No AI persona name | The product is Nexus; AI is the engine, not a character |
| 2026-06-04 | Connections: proactive + on-demand | Auto-surface related items AND support on-demand queries |
| 2026-06-04 | Team features: Phase 3 | Focus MVP on single-user experience |
| 2026-06-04 | Monetization gate: deferred | Decide after usage data from beta |
| 2026-06-05 | Platform roadmap: iOS → Android → Web → Desktop/Mac | Start focused, expand with shared design system |
| 2026-06-05 | Central design system before any native build | All tokens/assets are platform-agnostic source of truth |
| 2026-06-05 | Web prototype in Next.js to validate design language | Fastest to iterate, becomes reference for native builds |
| 2026-06-06 | Product framing: NotebookLM brain + Notion shell | Clearest analogy; defensible market position |
| 2026-06-06 | Design: light-first, white bg, one accent, Notion restraint | Dark mode mirrors same discipline; not dark-first |
| 2026-06-06 | IA: Source-centric (Option A), no Home screen | Briefing IS the home moment; Library is the workspace |
| 2026-06-06 | Collections: user-created + AI-auto-generated | Same container; user can rename/merge AI collections |
| 2026-06-06 | 5 JTBDs locked | Capture / Understand / Research / Answer / Stay informed |
| 2026-06-12 | Auth: Sign in with Apple + Magic link email in v1 | Apple required by App Store if any third-party login; magic link = passwordless, no reset flows, works cross-platform when web launches; Sign in with Google deferred to Phase 2 |
| 2026-06-12 | Apple Developer Program enrolled | Srihari's existing Apple ID enrolled at $99/year; unblocks Xcode provisioning and App Store distribution |
| 2026-06-13 | Items ↔ Collections: many-to-many | A link can appear in multiple collections; replace items.collection_id FK with collection_items join table before any iOS work depends on the API shape |
| 2026-06-13 | Dark mode page background | Deferred — Srihari to check Claude design system for reference before deciding |

---

## Open Questions (Blocking or Near-Blocking)
1. Freemium gate: which features are free vs Pro? — **deferred to post-beta**
