# Project Nexus — Build Plan
**Last Updated:** 2026-06-04  
**Current Phase:** Pre-Development / Spec

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
- [ ] **Design System** (see below — precedes all dev work)
- [ ] Set up GitHub repo (monorepo: `/prototype`, `/app-ios`, `/api`, `/design-system`)
- [ ] Domain + waitlist landing page

### Phase 0A — Design System & Prototype (Before any native build)
**Assets (Figma + source files):**
- [ ] Logo: wordmark + symbol (SVG, light + dark variants, app icon)
- [ ] Custom icon set (SVG, coherent style)
- [ ] Typography selection: display serif + reading font (license or source)
- [ ] Color palette: primitives + semantic tokens (dark mode first)
- [ ] Motion spec: duration + easing curves for key interactions

**Design tokens (platform-agnostic JSON):**
- [ ] `/design-system/tokens/colors.json`
- [ ] `/design-system/tokens/typography.json`
- [ ] `/design-system/tokens/spacing.json`
- [ ] `/design-system/tokens/motion.json`

**Web Prototype (`/prototype/` — Next.js 14):**
- [ ] Project scaffold: Next.js + Tailwind + Framer Motion
- [ ] Token integration (CSS custom properties from JSON)
- [ ] Core screens: Library, Item detail/Reader, Daily Briefing, Conversation
- [ ] Signature moments: Save animation, card stack Briefing, Library shelf view
- [ ] Responsive (mobile viewport primary)

---

### Design Prompt (for v0 or Claude Code sub-agent — Step-by-Step Explorative Mode)

Use this prompt to kick off the design exploration. It is **deliberately multi-step** — do not try to generate everything in one shot.

---

```
You are designing the visual identity and UI for **Nexus** — a premium, AI-native 
content curation app. Think: Apple Books meets Linear meets The Economist. 
The app is mobile-first (iPhone), but will expand to Android, Web, and Mac.

The design must be:
- Premium and editorial — not generic SaaS
- Glassmorphism where appropriate (frosted panels, subtle blur, layered depth)
- Gradient backgrounds — deep, subtle, not garish (dark mode first)
- Fully rounded corners on buttons (pill-shaped, 9999px radius)
- Premium icons — custom style, minimal but effective color use
- Delightful micro-interactions at every touch point (Framer Motion spring physics)
- Dark mode AND light mode (design dark first)
- Share extension UI (compact, beautiful save confirmation)
- Offline sync indicator (subtle, non-intrusive)

We will work through this **one step at a time**. Do not generate full screens yet.

---

**STEP 1 — Color Palette**
Show me 5 distinct color theme options as swatches. Each theme should have:
- A background (dark mode, near-black with personality — not pure #000)
- A surface (card/panel color, slightly lighter)
- A primary accent (the brand color — not blue, not generic)
- A secondary accent (supporting color)
- A text color (primary + secondary)

Format each as a named concept with hex values and a 1-line mood description.
Examples of direction (don't copy): "Obsidian + Amber", "Midnight + Coral", "Slate + Gold".

After I pick one, we move to Step 2.

---

**STEP 2 — Typography** (only after Step 1 is chosen)
Show 4 font pairing options for the chosen color theme. Each pairing should have:
- A display/heading font (editorial, distinctive — serif or stylized sans)
- A body/reading font (highly legible at small sizes)
- A UI font (clean, for labels and navigation)

For each, show a sample rendering: a headline ("Your daily briefing"), 
a body paragraph (2–3 lines of article text), and a UI label ("3 min read").
Include Google Fonts or system font names so they're web-safe for the prototype.

After I pick one, we move to Step 3.

---

**STEP 3 — Icon Style** (only after Step 2 is chosen)
Show 3 icon style directions, each with 6 sample icons:
(save, article, video, podcast, search, connection/link)

Styles to explore:
- Option A: Thin stroke, monochrome with single accent color dot
- Option B: Filled with subtle gradient, rounded shapes
- Option C: Duotone — two-color fills, slightly playful but refined

Render each set in the chosen palette.

After I pick one, we move to Step 4.

---

**STEP 4 — Layout Sketches** (only after Step 3 is chosen)
Show ASCII/text wireframe sketches of 4 core screens at mobile size (390px wide):
1. Library (the main content shelf)
2. Item / Reader view (clean reading experience)
3. Daily Briefing (the card stack)
4. Conversation / Ask Nexus

Keep these rough — layout, hierarchy, and key components only. No color, no detail.
I will approve layout direction before you build anything.

---

**STEP 5 — Full Prototype** (only after Step 4 is approved)
Now build the full Next.js 14 prototype with:
- All chosen design decisions applied
- Framer Motion animations for: card swipe (Briefing), save micro-animation, 
  page transitions, hover states on cards
- Glassmorphism on modals and bottom sheets
- Gradient mesh backgrounds (subtle, dark)
- Both dark and light mode via CSS variables from design tokens
- Custom "N" logomark in the header (constellation/connected-nodes concept)
- Bottom navigation: Library, Briefing, Chat, Profile
- Share extension component (compact save sheet, appears from bottom)
- Offline indicator (subtle chip, top of screen)
- All buttons: pill-shaped (border-radius: 9999px)
- Output as Next.js 14 App Router components + Tailwind CSS
```

---

---

## Phase 1 — MVP (Target: T+10 weeks)

### 1A — Backend Foundation (Weeks 1–3)
- [ ] Supabase project setup (auth, DB)
- [ ] PostgreSQL schema: users, items, tags, embeddings, briefings
- [ ] pgvector extension + embedding pipeline
- [ ] FastAPI skeleton: auth, items CRUD
- [ ] Content extraction service (Readability / Jina for articles)
- [ ] YouTube transcript ingestion (YouTube Data API + transcript extraction)
- [ ] Podcast transcript ingestion (RSS feed parse + Whisper/Deepgram for audio-to-text)
- [ ] S3/R2 bucket for full-text storage
- [ ] Anthropic API integration: summarize + insights pipeline
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

---

## Open Questions (Blocking or Near-Blocking)
1. Freemium gate: which features are free vs Pro? — **deferred to post-beta**
