# Project Nexus — Product Specification
**Version:** 0.3  
**Date:** 2026-06-06  
**Status:** Draft

**Platform Roadmap:** iOS (launch) → Android → Web → Desktop/Mac

---

## 1. Thesis

The internet produces more signal than any human can process. RSS readers, bookmarking apps, and read-later tools have tried to solve this — but they're digital filing cabinets. They store; they don't help you think.

Nexus is built on a different premise: **curation is a cognitive task, and AI should carry most of it.**

**The clearest product analogy:** Nexus is what you'd get if you combined NotebookLM and Notion — NotebookLM's AI-native, source-grounded intelligence with Notion's clean, organized, workspace-grade UX. NotebookLM treats AI as the product's organizing principle (not a feature). Notion proves that clean information architecture and minimal design can make complexity feel simple. Nexus inherits both.

Nexus is not an app with AI features. It is an AI system with an app as its interface. Every interaction — saving, organizing, surfacing, summarizing, connecting — is powered by an AI core that learns what you care about and gets better over time.

---

## 2. Market Research & Opportunity

### The Problem Space
- The average knowledge worker reads 200+ articles/month but retains and applies a fraction.
- Content volume doubles every 2 years (internet traffic trends, Cisco VNI).
- Existing tools (Pocket, Instapaper, Readwise, Matter) are passive stores — they surface content chronologically and rely on the user to do the cognitive work.
- Newsletter fatigue, bookmark graveyard, and "I'll read it later" syndrome are universal.

### What Exists Today (Competitive Landscape)

| Tool | Strength | Critical Gap |
|---|---|---|
| Pocket | Large user base, clean reader | No AI, passive queue |
| Instapaper | Great typography | Stagnant, no intelligence |
| Matter | Good audio + articles | Limited AI, no memory |
| Readwise Reader | Best-in-class highlights | Focused on re-reading, not discovery |
| Notion Web Clipper | Flexible | Not built for curation, heavy |
| Perplexity | AI-native search | Not a save/curate tool |
| Apple Notes | Frictionless save | Zero intelligence |
| Feedly | RSS + AI summaries | AI is shallow, no personalization |

### The Gap
No product exists that combines:
1. **Frictionless capture** (any content type, any source)
2. **Deep AI understanding** (not just summarize — synthesize, connect, surface)
3. **Persistent memory** (learns your interests, vocabulary, mental models)
4. **Beautiful, mobile-first UX**

---

## 3. Total Addressable Market (TAM)

### Primary Market: Knowledge Workers
- Global knowledge workers: ~1.25 billion (Statista, 2024)
- Subset actively consuming and curating online content: ~300M
- Willingness to pay for productivity tools: $10–20/month
- **TAM: ~$36B/year**

### Secondary Market: Creators & Researchers
- Journalists, researchers, newsletter writers, investors, founders — people whose job is to synthesize information
- ~50M globally
- Higher WTP: $20–50/month
- **SAM (serviceable): ~$5B/year**

### Beachhead (Year 1)
- Tech-forward early adopters in the US + English-speaking markets
- iPhone users who already use tools like Reeder, Matter, Readwise
- ~5–10M addressable, target: 100K paying users in Year 1
- **SOM (Year 1): ~$12M ARR at $10/month**

---

## 4. Personas

### Persona 1: "The Perpetually Curious" — Arjun, 31, Product Manager
- Saves 30+ links/week across Twitter, newsletters, podcasts
- Has 2,000 unread items in Pocket; gave up on it 6 months ago
- Wants to feel informed without drowning
- Key need: Summarization + "what's new in my field" briefings

### Persona 2: "The Signal Hunter" — Maya, 27, Startup Founder
- Reads to build conviction — market research, competitor moves, investor memos
- Needs to connect dots across sources and time
- Currently uses Notion + Readwise but it's high-friction
- Key need: Cross-content synthesis, memory ("what did I save about X last month?")

### Persona 3: "The Deep Diver" — Raj, 38, Investor / Analyst
- Needs to go deep on specific topics — builds thesis from 20+ sources
- Heavy newsletter subscriber, podcast listener
- Values sourcing and credibility
- Key need: Topic clustering, export to notes, citations

### Persona 4: "The Casual Learner" — Sam, 24, recent grad
- Wants to stay informed without it being a job
- Shares content with friends
- Values aesthetics and simplicity
- Key need: Easy save, beautiful daily digest, social/sharing layer

---

## 5. Jobs To Be Done (JTBDs)

| # | JTBD | Trigger moment |
|---|---|---|
| 1 | **Capture without friction** | "I found something interesting and don't want to lose it" |
| 2 | **Understand without reading** | "I saved 20 things this week — which ones matter and why?" |
| 3 | **Research a topic** | "I've been saving things about X for months — synthesize it for me" |
| 4 | **Answer from my own knowledge** | "I know I read something about this — let me ask instead of search" |
| 5 | **Stay informed without drowning** | "Give me a smart daily briefing from what I've saved, not an algorithm" |

---

## 5a. Information Architecture

### Navigation Model: Collection-Centric
Collections are the root unit. Not a library of items — a set of focused research spaces, each with its own AI agent. Closest reference: NotebookLM.

```
App
├── Collections (Home — list/grid of all collections)
│   └── [Collection]
│       ├── Nexus  ← AI agent tab (DEFAULT landing)
│       │   ├── Framing paragraph (AI-generated on collection creation)
│       │   ├── Starter prompts (contextual)
│       │   └── Chat thread
│       └── Sources  ← the links/content tab
│           ├── Source list (add / remove)
│           └── Source detail
│
├── New Collection (creation flow)
│   ├── "Research a topic"  ← AI-seeded: topic → AI finds authoritative sources
│   └── "Start with a link"  ← Manual: empty collection, add sources yourself
│
└── Profile / Settings
```

**No global library. No global "Ask Nexus".** Every AI interaction is scoped to a collection.  
The AI tab (Nexus) is the default landing view inside every collection — the hero, not a secondary feature.

### Collection Creation Flows

**AI-seeded ("Research a topic"):**
1. User types topic: "Ozempic and longevity"
2. System state: "Researching..."
3. Shows N sources found — user can review/remove before confirming
4. Collection created → lands on Nexus tab with AI framing paragraph

**Manual ("Start with a link"):**
1. Collection created empty
2. User adds sources: paste a link, upload PDF/image, share from another app
3. Each source is added to the Sources tab
4. Nexus tab available once ≥1 source exists

### Terminology (locked)

| Concept | String |
|---|---|
| Primary container | Collection |
| AI agent tab | Nexus |
| Sources/links tab | Sources |
| One piece of content | Source |
| AI-seeded creation | Research a topic |
| Manual creation | Start with a link |
| Create button | New Collection |
| First-launch prompt | What are you curious about? |
| AI building state | Researching... |
| Sources found state | Found 8 sources |
| Add content | Add a source |
| Onboarding CTA | Create your first collection |

### AI Starter Prompts (Nexus tab defaults)

Shown before user types anything. Replaced by contextual prompts when collection has ≥3 sources.

```
• What are the key ideas across these sources?
• What should I read first?
• Summarize this collection in 3 bullet points
• What questions does this collection raise?
• Are there any contradictions between sources?
• What's missing from this collection?
```

AI framing paragraph format (shown at top of Nexus tab on first open):
> "This collection has [N] sources covering [topic summary]. I've read everything — ask me anything."

### Content Architecture

```
Collection {
  id, name, created_by (user | AI), created_at
  sources: Source[]
}

Source {
  url, type (article | video | podcast | pdf | image | thread)
  title, author, published_at, thumbnail
  full_text  // extracted via pipeline

  // AI layer (computed async on add)
  tldr            // 2-3 sentences
  key_insights    // 3-5 bullets
  tags            // semantic, auto-generated
}
```

---

## 6. Goals & Success Metrics

### North Star Metric
**Weekly Active Curators** — users who save, read, or interact with their Nexus library at least once per week.

### Year 1 Goals
| Goal | Metric | Target |
|---|---|---|
| Adoption | WAC (Weekly Active Curators) | 50,000 |
| Retention | 30-day retention | >60% |
| Revenue | ARR | $3M |
| Engagement | Items saved per user/week | >5 |
| Intelligence | AI interactions per session | >2 |
| Quality | NPS | >50 |

---

## 6. Core Features

### 6.1 Capture — "Save Anything, Instantly"
- iOS Share Extension: save from any app (Safari, Twitter/X, YouTube, Spotify, etc.)
- Supported content types: Articles, blog posts, YouTube videos (transcript ingestion), podcast episodes (transcript ingestion), Twitter/X threads, PDFs, newsletters
- URL auto-detection and metadata enrichment (title, image, author, publish date, estimated read time)
- Quick-save with no friction; AI processes in background
- Batch import from Pocket, Instapaper, Readwise

### 6.2 The Library — "Your Second Brain"
- Unified inbox of all saved items
- Auto-organized by topic clusters (not manual folders)
- Filter by: content type, topic, unread, starred, date
- Full-text search across all saved content + AI semantic search
- "Ask your library" — natural language query ("What did I save about AI regulation?")

### 6.3 AI Understanding Layer — "The Core Intelligence"
This is what differentiates Nexus. Every item gets:
- **TL;DR** — 2-3 sentence summary
- **Key Insights** — 3–5 bullet points, extracted concepts
- **Tags** — auto-generated, semantic (not keyword)
- **Connections** — proactively surfaced ("This relates to 3 things you saved") and queryable on-demand
- **Credibility signal** — source quality indicator (publication, author rep)
- **Reading mode recommendation** — "Full read", "Skim", "Skip — here's why"

### 6.4 The Briefing — "Your Daily AI Digest"
- Personalized daily digest delivered as a native, scrollable card experience
- AI curates from your unsaved queue + proactively surfaces from your topics of interest
- Format: headline, 1-sentence insight, action (read, skip, share)
- Configurable: frequency, length, time of day, topic filters
- Weekly "Synthesis" — AI-written narrative of themes from the week

### 6.5 Memory & Personalization — "It Learns You"
- Nexus builds a model of your interests, vocabulary, and mental models over time
- Explicit signals: stars, saves, reads, skips, highlights
- Implicit signals: read depth (did you finish?), speed, return visits
- Topic graph: knows you care about "AI x Healthcare" not just "AI" or "Healthcare"
- Memory is surfaced and editable ("Your interest profile" screen)

### 6.6 Conversation Mode — "Ask Nexus Anything"
- Chat interface to query your library and the AI
- "Summarize everything I've saved about climate tech this month"
- "What are the 3 biggest arguments for and against X from my saves?"
- "Write me a briefing to send to my team"
- Grounded responses (cites your actual saved items, not hallucinated)

### 6.7 Highlights & Annotations
- Highlight any passage in the reader view
- AI can explain, expand, or connect a highlight to your library
- Export highlights (Markdown, Notion, Obsidian, email)
- "Highlight Digest" — weekly email of your best captures

### 6.8 Discovery (Phase 2)
- Based on your library, Nexus suggests content you haven't seen
- Curated by AI from trusted sources in your interest graph
- Not an algorithmic feed — more like a smart librarian making suggestions

### 6.9 Sharing & Collaboration (Phase 2)
- Share a curated collection ("My AI reading list")
- Nexus Spaces: shared library for teams or study groups
- "Send to friend" with AI-generated context

---

## 7. Feature Prioritization

### Phase 1 — MVP (iPhone Launch)
**Must Have:**
- Save via Share Extension (articles, threads, videos)
- Library view with AI summaries + key insights
- Daily Briefing
- Semantic search / "Ask your library"
- Reader view (clean, beautiful)
- Basic memory / interest profile

**Should Have:**
- Highlights and annotations
- Content type filtering
- Offline reading

**Won't Have (Phase 1):**
- Discovery feed
- Team/collaboration features
- Android
- Web app
- Social/sharing

### Phase 2 — Growth (3–6 months post-launch)
- Discovery engine
- Conversation Mode (full chat)
- Sharing and collections
- Web clipper (browser extension)
- Weekly Synthesis report

### Phase 3 — Platform (6–12 months)
- Team Spaces
- Android
- API / integrations (Notion, Obsidian, Slack)
- Creator tools (newsletter, publish your Nexus)

---

## 8. Guardrails

### What Nexus Will NOT Be
- A social feed / algorithmic dopamine loop
- A news aggregator (it curates *your* saves, not the internet)
- A replacement for deep reading (it makes deep reading more intentional)
- A search engine

### AI Guardrails
- AI outputs are always traceable to source material — no hallucination without citation
- AI does not editorialize or inject opinions in summaries
- Users can always see the source and override AI categorization
- No content moderation or censorship of saved items (user autonomy)

### UX Guardrails
- No dark patterns, no engagement bait, no notification spam
- Every screen has a single primary action
- The app should feel calming, not urgent

---

## 9. Technical Architecture

### Philosophy: AI-Native, Not AI-Added
The architecture is built from the ground up as an AI system. The model is not a service call — it is the orchestration layer.

```
┌─────────────────────────────────────────────────────┐
│                  iPhone App (SwiftUI)                │
│  Reader · Library · Briefing · Chat · Profile        │
└────────────────────┬────────────────────────────────┘
                     │ HTTPS / WebSocket
┌────────────────────▼────────────────────────────────┐
│              Nexus API (Backend)                     │
│  FastAPI / Python · Auth · Content Pipeline          │
└────┬──────────────────────────────┬─────────────────┘
     │                              │
┌────▼─────────┐          ┌────────▼──────────────────┐
│  Content     │          │    AI Orchestration Layer  │
│  Pipeline    │          │  (Claude claude-sonnet-4-6 / claude-opus-4-8)   │
│  Ingestion   │          │                            │
│  Extraction  │          │  Tools:                    │
│  Storage     │          │  - summarize(item)         │
└────┬─────────┘          │  - extract_insights(item)  │
     │                    │  - cluster_topics(library) │
┌────▼─────────┐          │  - search_library(query)   │
│  Storage     │          │  - build_briefing(prefs)   │
│  PostgreSQL  │          │  - answer_query(q, context)│
│  + pgvector  │          │                            │
│  (embeddings)│          │  Memory:                   │
│  S3/R2       │          │  - User interest graph     │
│  (full text) │          │  - Read/skip history       │
└──────────────┘          │  - Topic weights           │
                          └────────────────────────────┘
```

### Core Stack
| Layer | Choice | Rationale |
|---|---|---|
| Mobile | SwiftUI (iOS 17+) | Native performance, best UX, Share Extension |
| Backend API | FastAPI (Python) | Async, fast, AI ecosystem native |
| AI Model | Claude claude-sonnet-4-6 / claude-opus-4-8 (Anthropic) | Best long-context, safest, best reasoning |
| Vector DB | pgvector (PostgreSQL) | Unified DB, semantic search |
| Full-text Storage | PostgreSQL + S3/R2 | Article body storage |
| Content Extraction | Mozilla Readability + Jina AI Reader | Clean article extraction |
| Auth | Supabase Auth | Fast, secure, social login |
| Hosting | Railway / Fly.io (API) + Supabase (DB) | Fast launch, scalable |
| Push Notifications | APNs via backend | Daily briefing delivery |
| CDN | Cloudflare R2 + Workers | Fast, cheap |

### AI Architecture Details

**Content Processing Pipeline (per item saved):**
1. URL received → content extracted (Readability/Jina)
2. Chunked and embedded → stored in pgvector
3. AI processing (async, background):
   - Generate TL;DR (Claude Haiku — fast/cheap)
   - Extract key insights (Claude Haiku)
   - Generate semantic tags (Claude Haiku)
   - Compute connections to existing library (vector similarity + Claude)
4. Results stored, user notified

**Daily Briefing Pipeline:**
1. Triggered at user's preferred time
2. Fetch unread items + interest profile
3. Claude constructs personalized briefing (ranked by relevance, deduped)
4. Delivered as push notification + in-app card stack

**Conversation Mode:**
1. User query + conversation history + relevant library chunks (RAG)
2. Claude responds with citations to actual saved items
3. Multi-turn supported, context window managed with sliding window

### AI Tool Definitions (Sample)
```python
tools = [
    {
        "name": "summarize_content",
        "description": "Generate TL;DR and key insights for a content item",
        "input_schema": {
            "type": "object",
            "properties": {
                "content": {"type": "string"},
                "content_type": {"type": "string", "enum": ["article", "video", "podcast", "thread"]},
                "max_length": {"type": "integer"}
            }
        }
    },
    {
        "name": "search_library",
        "description": "Search user's saved library using semantic similarity",
        "input_schema": {
            "type": "object",
            "properties": {
                "query": {"type": "string"},
                "user_id": {"type": "string"},
                "limit": {"type": "integer"},
                "filters": {"type": "object"}
            }
        }
    },
    {
        "name": "build_daily_briefing",
        "description": "Construct a personalized daily briefing from user library and preferences",
        "input_schema": {
            "type": "object",
            "properties": {
                "user_id": {"type": "string"},
                "unread_items": {"type": "array"},
                "interest_profile": {"type": "object"},
                "max_items": {"type": "integer"}
            }
        }
    }
]
```

---

## 10. Privacy & Data

### Principles
1. **Your data is yours** — users own their saves, insights, and memory profile
2. **AI processing is purposeful** — content is processed to serve the user, never to train models or target ads
3. **No selling of data** — business model is subscription, period
4. **Transparency** — users can see exactly what Nexus knows about them and delete it

### Data Handling
- Content extracted from URLs is stored encrypted at rest (AES-256)
- Embeddings are stored per-user, not shared
- AI calls to Anthropic API: content is sent for processing but not retained for training (zero data retention agreement)
- User memory/interest profile: viewable and deletable in-app
- Export: users can export their full library at any time (JSON, Markdown)
- GDPR + CCPA compliant from day 1
- No third-party analytics SDKs in v1 (use privacy-preserving PostHog self-hosted or equivalent)

### Auth & Security
- Sign in with Apple (primary)
- Email + magic link (secondary)
- No passwords stored
- JWT tokens, short-lived with refresh
- All API traffic TLS 1.3

---

## 11. Monetization

### Model: Freemium Subscription

| Tier | Price | Limits |
|---|---|---|
| Free | $0 | 50 saves/month, basic summaries, no Conversation Mode |
| Nexus Pro | $9.99/month or $79/year | Unlimited saves, full AI features, Briefing, Conversation Mode |
| Nexus Team (Phase 3) | $14.99/user/month | Spaces, shared libraries, admin |

### Revenue Philosophy
- No ads. Ever.
- No data selling.
- Subscription is the only business model.
- Free tier is generous enough to demonstrate value, not generous enough to replace Pro.

---

## 12. UX Design Direction

### Design DNA
Nexus should feel like Notion built the UI and NotebookLM built the brain. References:
- **Color**: Light/white background, near-black text (#191919 range). One signature accent used sparingly — not as chrome, only as signal. Dark mode: deep gray (not black), same minimal color discipline.
- **Typography**: Clean, legible, editorial. Inter or equivalent for UI. A slightly warmer serif or distinctive sans for display moments. Dense where needed, spacious where content lives.
- **Motion**: Purposeful, never gratuitous. Fluid transitions, spring physics for interactions.
- **Iconography**: Custom-drawn, coherent system. Thin-to-medium weight, minimal color, geometric. Not SF Symbols defaults.
- **Density**: Notion-level efficiency — content-rich without feeling cluttered.

### Visual Benchmark
| Dimension | Reference |
|---|---|
| Information density | Notion |
| Color restraint | Notion (white + one accent) |
| AI as core surface | NotebookLM |
| Source-grounded chat | NotebookLM |
| Clean reading experience | Notion pages |
| Sidebar navigation | Notion left sidebar |

### Signature UX Moments
1. **The Save** — saving should feel satisfying. A micro-animation confirms the capture, the item "lands" in the library.
2. **The Library** — Notion-like organized view. Items are entries, not cards. Filterable, sortable, beautiful.
3. **Ask Nexus** — NotebookLM-style AI chat, but grounded only in your saved content. Citations surface to the source.
4. **The Briefing** — AI-generated daily digest. Feels like a smart editor curated it, not an algorithm.
5. **Connections** — AI surfaces links between items proactively. Feels like discovery, not filing.

### Typography
- UI + body: Inter (or system equivalent) — same as Notion
- Display / brand moments: A distinctive serif or stylized wordmark
- Reader view: Highly legible body font (Georgia, or licensed equivalent)
- SF Pro on iOS for system chrome

### Logo Concept
- Wordmark + symbol
- Symbol: an abstract "N" — constellation or connected nodes, evoking synthesis and discovery
- Light and dark variants, single-color on both
- App icon: symbol only, bold, memorable

### Landing Page Direction
- Single-screen, one-box layout — not a multi-section scroll with features at the bottom
- White background, clean typography, one clear headline
- Single primary CTA ("Get early access" or equivalent) — above the fold
- No feature grid, no testimonials carousel, no pricing section on launch

---

## 13. Design System Architecture

### Philosophy: One Source of Truth
All design resources are platform-agnostic and centrally maintained. Native apps consume tokens; they don't define them.

```
/design-system/
  tokens/
    colors.json       ← primitive + semantic color tokens
    typography.json   ← font stack, sizes, weights, line heights
    spacing.json      ← scale (4px base)
    radii.json
    shadows.json
    motion.json       ← duration + easing curves
  assets/
    logo/             ← SVG wordmark + symbol, light + dark
    icons/            ← custom SVG icon set
    fonts/            ← licensed font files
  docs/               ← usage guidelines
```

### Token Consumption by Platform
| Platform | How tokens are consumed |
|---|---|
| Web prototype / Web app | CSS custom properties via style-dictionary |
| iOS (SwiftUI) | Swift generated from tokens (via style-dictionary or Zeplin/Tokens Studio) |
| Android | XML resources generated from tokens |
| Desktop/Mac | CSS (Electron/Tauri) or Swift (native macOS) |

### Web Prototype Stack
Built to establish + validate the design language before native iOS build.

| Concern | Choice |
|---|---|
| Framework | Next.js 14 (App Router) |
| Styling | Tailwind CSS + CSS variables from design tokens |
| Animation | Framer Motion |
| Icons | Custom SVG sprite system |
| Font loading | Next/font (self-hosted) |
| Component approach | Radix UI primitives + custom styled layer |

The prototype lives in `/prototype/` in the monorepo and is the design reference for all future platform builds.

---

## 14. Launch Strategy

### Pre-Launch
- Waitlist landing page (minimal, beautiful)
- Founder's Twitter/X thread — the thesis, the problem, screenshots
- TestFlight beta: 500 users, primarily from tech/product community

### Launch
- Product Hunt launch (coordinated)
- App Store featuring pitch (editorial content curation angle)
- Targeted outreach to newsletter writers, Substack authors, indie hackers

### Post-Launch Growth
- Referral program: share a collection, friend gets 1 month free
- Embed in creator workflows (newsletters with "curated with Nexus" badges)
- Content marketing: "The future of reading" essays

---

## 14. Open Questions

- [ ] What's the right monetization gate? (conversation mode? briefing? saves?) — **deferred**
- [x] AI persona: nameless. The product is Nexus. No named AI character.
- [x] Podcast v1: full transcript ingestion + summary
- [x] YouTube v1: transcript ingestion + summary
- [x] Connections: **proactive + on-demand** — AI surfaces connections automatically; user can also query on-demand
- [x] Team features: Phase 3
