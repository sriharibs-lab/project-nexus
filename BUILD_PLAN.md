# Project Nexus — Build Plan
**Last Updated:** 2026-06-06  
**Current Phase:** Phase 0A — Design System + Parallel Foundation Work

---

## Status Key
- `[ ]` Not started
- `[~]` In progress
- `[x]` Done
- `[!]` Blocked

---

## Phase 0 — Foundation (Now)
- [x] Write product spec (SPEC.md)
- [x] Resolve open questions (personas, platform roadmap, content types, connections behavior)
- [~] **Design System** — explorative prompt running in parallel tab (Step 1: color palette)
- [~] Set up GitHub repo (monorepo: `/prototype`, `/app-ios`, `/api`, `/design-system`) — in progress
- [ ] Domain + waitlist landing page

### Phase 0A — Design System & Prototype (Before any native build)
**Assets (Figma + source files):**
- [ ] Logo: wordmark + symbol (SVG, light + dark variants, app icon)
- [ ] Custom icon set (SVG, coherent style)
- [ ] Typography selection: display serif + reading font (license or source)
- [ ] Color palette: primitives + semantic tokens (dark mode first)
- [ ] Motion spec: duration + easing curves for key interactions

**Design tokens (platform-agnostic JSON):**
- [~] `/design-system/tokens/colors.json` — scaffold in progress
- [~] `/design-system/tokens/typography.json` — scaffold in progress
- [~] `/design-system/tokens/spacing.json` — scaffold in progress
- [~] `/design-system/tokens/motion.json` — scaffold in progress

**Web Prototype (`/prototype/` — Next.js 14):**
- [~] Project scaffold: Next.js + Tailwind + Framer Motion — in progress via design tab
- [ ] Token integration (CSS custom properties from JSON)
- [ ] Core screens: Library, Item detail/Reader, Daily Briefing, Conversation
- [ ] Signature moments: Save animation, card stack Briefing, Library shelf view
- [ ] Responsive (mobile viewport primary)

---

### Design Prompt v2 — Updated 2026-06-06 (for UX agent in Tab 1)

**Direction**: Notion visual discipline + NotebookLM AI-native model. Light/white background, near-black text, one accent used sparingly. Step-by-step — do not generate everything in one shot. Every step produces a rendered HTML file.

---

```
You are the UX designer for Nexus — an AI-native content curation app.
The product sits at the intersection of NotebookLM (AI is the core, not a feature)
and Notion (clean information architecture, minimal color, white background).

VISUAL REFERENCE:
- Notion: white/off-white background (~#FAFAFA), near-black text (~#191919),
  Inter font, minimal color, one accent sparingly used, clean sidebar nav
- NotebookLM: clean, spacious, AI chat as a primary surface
- Light-first. Dark mode mirrors the same restraint (deep gray, not black).
- No glassmorphism, no gradient backgrounds.
- ONE accent color. Used for signal, not decoration.
- Buttons: rounded corners (8-12px radius), not pill-shaped
- Icons: thin stroke, geometric, monochrome with single accent where needed

THE APP:
- Saves internet content (articles, videos, podcasts, threads)
- AI summarizes, tags, connects, and answers questions about your saved content
- Primary nav: left sidebar (desktop/tablet) or bottom nav (iPhone)
- Core screens: Library, Item/Reader, Daily Briefing, Ask Nexus (AI chat)
- Mobile-first but designed for all platforms

We will work through this one step at a time.
Each step produces a rendered HTML file — not text, not a table. Must be visual.

---

STEP 1 — Color Palette
Produce a rendered HTML file showing 4 light-mode palette options.
Each palette as a visual swatch block showing:
- Background (white or warm/cool off-white)
- Surface (cards, sidebar — slightly different from background)
- Text primary (near-black) + text secondary (medium gray)
- Accent (ONE color — not blue — for links, active states, AI indicators)
- Border (subtle 1px color)

Also show each palette's dark mode equivalent as a second row below it.
Name each concept (e.g. "Paper + Rust", "Milk + Indigo", "Stone + Amber").
Output: single HTML file, all 4 palettes visible without scrolling.

After I pick one, we move to Step 2.

---

STEP 2 — Typography
(Only after Step 1 is chosen)

Show 3 font pairing options rendered in the chosen palette as a full HTML specimen.
Each pairing:
- UI font: for labels, nav, metadata (Notion-clean — Inter or similar)
- Display font: for headlines (can have personality)
- Reader font: for article body text (legible at 16-18px)

Each specimen shows:
- App headline: "Everything you save, organized and understood"
- Library item: title + source + 1-line AI summary
- Short article paragraph (3-4 lines)
- UI labels: "3 min read" / "Saved" / "Ask Nexus"

Google Fonts only. Output: single HTML file, all 3 specimens visible.

After I pick one, we move to Step 3.

---

STEP 3 — Layout Wireframe (IA is decided — implement this)
(Only after Step 2 is chosen)

The IA is already decided. Implement it as a clean HTML wireframe (layout only, no color yet):

Navigation model: Source-centric
- Left sidebar (240px): Nexus logo, search bar, nav items (Library / Briefing / Ask Nexus),
  divider, Collections list (shows both user-created and AI-auto-generated collections)
- Main content area fills the rest
- On mobile (< 768px): sidebar collapses to bottom nav (Library | Briefing | Ask | Profile)
  with search bar pinned at top of content area

No Home screen. Library is the default view. Briefing is the daily moment, not a dashboard.

Render the Library screen only as an HTML wireframe — divs with borders and labels,
proportional layout, actual HTML (not ASCII). Show both desktop and mobile versions side by side.

After I review and approve the layout, we move to Step 4.

---

STEP 4 — Landing Page Wireframe
(Only after Step 3 layout is approved)

Wireframe the landing page as an HTML layout (no color yet, structure only).

Rules for this landing page:
- Single-column, one-box layout — NOT a multi-section marketing page
- No feature grids, no testimonials, no pricing section, no footer nav
- Everything above or just below the fold
- One primary CTA only (email capture or "Get early access")

The wireframe must show:
- Logo / wordmark (top left)
- Headline (large, centered or left-aligned)
- Sub-headline (1-2 lines)
- A single visual element (app screenshot OR abstract illustration — placeholder box)
- Email input + CTA button
- Optional: 1 line of social proof below CTA (e.g. "Join 2,400 people on the waitlist")

Output: HTML wireframe, actual rendered layout with labeled placeholder boxes.
I will approve the structure before any styling is applied.

---

STEP 5 — Landing Page (Final)
(Only after Step 4 wireframe is approved)

Build the fully styled, production-ready landing page in a single HTML file:
- Apply chosen palette, typography, and logo
- Responsive: looks great on mobile (390px) and desktop (1280px)
- Subtle animation: headline fades in, CTA button has a hover state
- Custom "N" logomark SVG in the header (constellation / connected-nodes concept)
- Email capture form (static — no backend needed, just the UI)
- Light mode default; dark mode via prefers-color-scheme media query
- Output: single self-contained HTML file, no external dependencies except Google Fonts
```


## Phase 1 — MVP (Target: T+10 weeks)

### 1A — Backend Foundation (Weeks 1–3)
- [ ] Supabase project setup (auth, DB)
- [x] PostgreSQL schema: users, items, tags, embeddings, briefings — models + Alembic done
- [~] pgvector extension + embedding pipeline — embed stub done; real model TBD
- [x] FastAPI skeleton: auth, items CRUD — done (models, auth, queue stub, Alembic)
- [ ] Content extraction service (Readability / Jina for articles)
- [ ] YouTube transcript ingestion (YouTube Data API + transcript extraction)
- [ ] Podcast transcript ingestion (RSS feed parse + Whisper/Deepgram for audio-to-text)
- [ ] S3/R2 bucket for full-text storage
- [x] Anthropic API integration: summarize + insights pipeline — pipeline.py done (claude-haiku-4-5); **blocked: needs ANTHROPIC_API_KEY**
- [ ] Background job queue (async AI processing per save)

### 1B — iPhone App Foundation (Weeks 1–3, parallel)
- [ ] Xcode project setup, SwiftUI architecture (MVVM or TCA)
- [ ] Sign in with Apple + auth flow
- [ ] Share Extension: capture URL from any app
- [ ] API client layer (async/await)
- [ ] Design tokens: colors, typography, spacing

### 1C — Core Features (Weeks 4–7)
- [ ] Library view: list/grid, beautiful card design
- [ ] Item detail / Reader view: clean, full-screen reading experience
- [ ] AI summary + key insights displayed per item
- [ ] Semantic tags per item
- [ ] "Connections" panel (related items)
- [ ] Full-text + semantic search
- [ ] "Ask your library" — simple query interface
- [ ] Interest profile (background computation)
- [ ] Daily Briefing: backend pipeline + push notification delivery
- [ ] Briefing card stack UI in app

### 1D — Polish & QA (Weeks 8–9)
- [ ] Offline reading (cache reader content)
- [ ] Highlight + annotation in reader
- [ ] Onboarding flow (beautiful, minimal)
- [ ] Empty states, loading states, error states
- [ ] Performance: save-to-summary < 10 seconds
- [ ] App Store assets: screenshots, preview video, description

### 1E — Launch Prep (Week 10)
- [ ] TestFlight beta (500 users)
- [ ] Bug bash
- [ ] Waitlist landing page live
- [ ] App Store submission

---

## Phase 2 — Growth (T+10 to T+24 weeks)
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

---

## Open Questions (Blocking or Near-Blocking)
1. Freemium gate: which features are free vs Pro? — **deferred to post-beta**
