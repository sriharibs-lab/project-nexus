# Project Nexus — Product Specification
**Version:** 0.4  
**Date:** 2026-06-11  
**Status:** Active

**Platform Roadmap:** iOS (launch) → Android → Web → Desktop/Mac

> **Product intent:** Nexus is a serious, production consumer app targeting worldwide release. Not a prototype, not a side project. Every technical decision — architecture, security, observability, AI design — must be made at that standard.

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

## 7. Core Features

### 7.1 Capture — "Save Anything, Instantly"
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

### 6.8 In-App Feedback

Users can submit feedback without leaving the app.

**Entry point:** Settings → "Send Feedback" (intentional, not accidental). No shake gesture.

**Flow:**
1. User taps "Send Feedback"
2. App silently captures a screenshot of the current screen
3. Feedback form appears: text field + screenshot preview with toggle ("Include screenshot")
4. User writes feedback, optionally removes screenshot, taps Send
5. Confirmation: "Thanks — we read every submission"

**What's captured automatically (no user input):**
- App version + iOS version (for bug diagnosis)
- Feedback category (auto-detected or user-selected: Bug / Suggestion / Other)
- Anonymized user ID (so we can follow up without linking to PII in logs)
- Screenshot (if user keeps the toggle on)

**What's NOT captured:** content of the user's library, URLs saved, or any reading data.

**Screenshot storage:** Supabase Storage bucket (`feedback-screenshots/`), private, accessible only to Nexus team.

### 6.9 Discovery (Phase 2)
- Based on your library, Nexus suggests content you haven't seen
- Curated by AI from trusted sources in your interest graph
- Not an algorithmic feed — more like a smart librarian making suggestions

### 6.9 Sharing & Collaboration (Phase 2)
- Share a curated collection ("My AI reading list")
- Nexus Spaces: shared library for teams or study groups
- "Send to friend" with AI-generated context

---

## 8. Feature Prioritization

### Phase 1 — MVP (iPhone Launch)
**Must Have:**
- Save via Share Extension (articles, threads, videos)
- Library view with AI summaries + key insights
- Daily Briefing
- Semantic search / "Ask your library"
- Reader view (clean, beautiful)
- Basic memory / interest profile
- In-app feedback (text + optional screenshot)

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

## 9. Guardrails

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

## 10. Technical Architecture

### Philosophy: AI-Native, Not AI-Added
The architecture is built from the ground up as an AI system. The model is not a service call — it is the orchestration layer. Nexus is an **AI agentic harness** built on four formal pillars: **Model, Knowledge, Tools, Memory**. These are not features; they are the infrastructure the product runs on.

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
| Auth | Supabase Auth — Sign in with Apple + Magic link email (v1); Sign in with Google (Phase 2) | Passwordless from day one; Apple required by App Store; magic link covers web/cross-platform |
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

### §9a: AI Agentic Harness — Four Pillars

Nexus is not a chatbot wrapper. Every AI interaction is grounded in a formal four-pillar architecture:

#### Pillar 1 — Model
Model selection is a cost/quality/latency decision for every task — see §9c. Defaults:
- **Claude claude-haiku-4-5** — high-volume background tasks (summarization, tagging, briefing composition)
- **Claude claude-sonnet-4-6** — user-facing reasoning (grounded Q&A, collection research, conversation)
- **Claude claude-opus-4-8** — internal tooling only (NBL Architect agent); not on the user-facing hot path in Phase 1
- Non-Anthropic alternatives (Llama, open-weights embeddings) actively evaluated for cost reduction — see §9c
- All Anthropic models operate under a **zero data retention (ZDR) agreement** — content processed but never retained or used for model training

#### Pillar 2 — Knowledge
The AI's knowledge base has three layers, retrieved via RAG on every inference call:
1. **User library** — full text + embeddings of all saved sources, stored in pgvector per user. Hybrid search: semantic (embedding similarity) + keyword (full-text FTS). Retrieved at query time, injected as grounding context.
2. **User interest graph** — a lightweight semantic profile of the user's topics, sources, and engagement patterns. Built from explicit signals (stars, highlights) and implicit signals (read depth, return visits, skip rate). Drives briefing personalization and connection surfacing.
3. **Collection framing** — per-collection AI-generated context summary. Pre-computed on creation; updated when sources change.

Knowledge access is **strictly read-only for the AI**. The AI agent cannot write to user data without an explicit user action triggering a write path.

#### Pillar 3 — Tools
Formal tool definitions — the AI calls these rather than free-form generation:

```python
tools = [
    # Content pipeline tools
    "extract_content(url) → ExtractionResult",
    "summarize_item(text, content_type) → { tldr, key_insights, tags }",
    "embed_text(text) → vector[1536]",
    "find_connections(item_id, user_id, limit) → [RelatedItem]",

    # Library tools
    "search_library(query, user_id, filters, limit) → [SearchResult]",
    "get_collection_context(collection_id) → CollectionContext",
    "get_interest_profile(user_id) → InterestProfile",

    # Agentic output tools
    "build_daily_briefing(user_id, preferences) → Briefing",
    "build_collection_framing(collection_id) → FacingParagraph",
    "build_weekly_synthesis(user_id, date_range) → Synthesis",
    "answer_with_citations(query, context_chunks) → CitedResponse",
]
```

Every tool call is **logged with a correlation ID** linking it to the originating user action. Tool outputs are validated against schemas before storage. The AI cannot call destructive operations (delete, overwrite) directly.

#### Pillar 4 — Memory
Three tiers of memory with different lifespans:

| Tier | Scope | Lifespan | Implementation |
|---|---|---|---|
| **Working memory** | Current session / conversation | Request lifetime | Sliding context window (Claude's context) |
| **Episodic memory** | Interaction history | User account lifetime | PostgreSQL: per-user conversation log, pruned to last 50 turns |
| **Semantic memory** | Interest graph, topic weights, reading patterns | User account lifetime | PostgreSQL: `user_profiles` table, updated on signal events |

Memory is **user-owned and auditable**: users can view, correct, and delete their semantic memory from the Settings screen. Deletion is hard-delete — not soft-delete.

---

### §9c: Model Economics — Cost vs Quality vs Latency

AI inference is Nexus's largest variable cost. At scale (100K users, 5 saves/week each), every unnecessary Opus call or un-cached Sonnet call compounds directly into margin erosion. Good business decisions require a deliberate cost architecture — not just "use the best model."

#### The Three-Axis Decision
Every AI task is evaluated on three axes before choosing a model or approach:

| Axis | Question | Business stake |
|---|---|---|
| **Quality** | Will a cheaper model produce output the user finds noticeably worse? | Retention, NPS |
| **Latency** | Does the user wait for this? Or is it background async? | UX, JTBD completion |
| **Cost** | What's the cost per call × calls per user per day × user base? | Margin, unit economics |

The rule: **use the cheapest model that clears the quality bar for the task.** Never use a larger model because it's "safer" without measuring the quality delta against the cost delta.

#### Task-to-Model Routing

| Task | Model / Approach | Rationale |
|---|---|---|
| Background summarization (TL;DR, key insights, tags) | **Claude Haiku** | High volume, structured output, quality bar is "accurate + concise" — Haiku clears it |
| Embedding generation | **`text-embedding-3-small` (OpenAI)** — or self-hosted alternative | Embeddings are commodity; OpenAI's small model costs ~10× less than large with <5% retrieval quality loss |
| Collection framing paragraph | **Claude Haiku** with prompt caching | Pre-computed; user doesn't wait. Cache the system prompt. |
| Collection research (find sources for a topic) | **Claude Sonnet** | Requires judgment and web knowledge. Quality is user-visible, latency is acceptable (10–15s async) |
| Grounded Q&A (Nexus tab chat) | **Claude Sonnet** | User is waiting; quality is the primary product differentiator. Sonnet is the floor. |
| Daily briefing composition | **Claude Haiku** with structured output | High-volume background job. Briefing is structured (not a creative long-form essay). Haiku + good prompting is sufficient. |
| Weekly synthesis report | **Claude Sonnet** | Once per week per user, long-form, quality-visible. Sonnet justified. |
| Opus | **Reserved for internal tooling (NBL Architect agent) only** | Never on the user-facing hot path in Phase 1. Revisit for Phase 2 "deep research" mode if differentiated enough to charge more. |

#### Cheaper Alternatives to Explore (Non-Anthropic)

Not all tasks require a frontier model. These should be actively evaluated before committing to a paid model call:

| Category | Alternatives | When to use |
|---|---|---|
| **Embeddings** | `text-embedding-3-small` (OpenAI), `mxbai-embed-large` (self-hosted via Ollama), `bge-m3` (open weights) | All embedding generation. Self-hosted removes per-call cost entirely at the cost of infra. Benchmark retrieval quality before switching. |
| **Classification / tagging** | Regex rules, keyword classifiers, `distilbert` fine-tuned on content types | Content-type detection (article vs video vs thread) can be rule-based + ML, not LLM |
| **Extraction / summarization** | `Llama 3.1 8B` or `Mistral 7B` via Groq/Together (low latency, low cost) | Background summaries for simple content. Run a quality A/B before replacing Haiku. |
| **Structured output parsing** | Deterministic parsing (regex, BeautifulSoup, structured extractors) | Metadata extraction (title, author, publish date, read time) should never be an LLM call |
| **Prompt caching** | Anthropic prompt caching (cache_control on system prompts) | Any call where the system prompt + few-shot examples is >1024 tokens. Can cut costs 80–90% on repeated calls. |
| **Batch API** | Anthropic Batch API (50% discount, async) | Daily briefing generation, weekly synthesis, background re-summarization jobs. None of these are real-time. |

#### Cost Control Principles

1. **Measure before assuming.** Before using Sonnet where Haiku might work, run 100 samples of real content through both and score quality. Decisions are data-driven.
2. **Prompt caching is free money.** Every high-volume call with a stable system prompt uses `cache_control`. This is non-negotiable.
3. **Batch API for all async work.** Background jobs (briefings, summaries, re-tagging) use the Batch API. 50% discount for non-real-time work.
4. **Token budgets per task.** Each tool call has a defined `max_tokens` output limit. Unbounded generation is a cost leak.
5. **RAG context window discipline.** Only inject the top-K most relevant chunks, not the full library. K is tuned per task type. Larger context = higher cost with diminishing quality returns past a threshold.
6. **Cost telemetry is first-class.** Every AI call emits `input_tokens`, `output_tokens`, `cache_read_tokens`, `model`, and `cost_usd` (computed). Monthly per-user AI cost is a tracked metric. If it exceeds the Pro subscription COGS threshold, that triggers a model routing review.

#### Unit Economics Target (Phase 1)
| Metric | Target |
|---|---|
| AI cost per active free user / month | < $0.05 |
| AI cost per Pro user / month | < $0.80 |
| AI cost as % of Pro revenue | < 10% |

These are directional targets, not launch gates. Track from day 1 so the data exists to make routing decisions in Phase 2.

---

### §9b: Production Engineering Standards

Nexus is a worldwide consumer app. These are non-negotiable engineering requirements, not optional polish.

#### Observability — Telemetry
Every meaningful event in the system emits a structured telemetry event. Format: structured JSON with a correlation ID that chains from the originating user action through every downstream service call.

**Instrumented events (mandatory):**
- `user.save` — URL saved (type, latency, outcome)
- `pipeline.extraction` — extraction step (extractor used, duration, chars extracted, error)
- `pipeline.ai_summarize` — AI call (model, input_tokens, output_tokens, latency_ms, cache_hit)
- `pipeline.embed` — embedding call (duration_ms, vector_dims)
- `ai.tool_call` — every tool invocation (tool_name, duration_ms, success, correlation_id)
- `ai.conversation_turn` — chat message (collection_id, turn_index, model, latency_ms, grounded_sources_count)
- `search.query` — library search (query_type: semantic|keyword|hybrid, result_count, latency_ms)
- `briefing.generated` — daily briefing (items_considered, items_selected, model, duration_ms)
- `error.*` — all errors with stack trace, correlation ID, affected user ID (anonymized)

**Stack:** OpenTelemetry (traces + metrics) → collector → backend (Grafana Cloud / Datadog). Sentry for error reporting.

#### Observability — Monitoring & Alerting
Key service health monitors with defined SLOs:

| Signal | SLO | Alert threshold |
|---|---|---|
| API p95 response time | < 500ms | > 800ms |
| Save-to-summary latency | < 10 seconds | > 15 seconds |
| AI pipeline error rate | < 1% | > 2% |
| Embedding pipeline error rate | < 0.5% | > 1% |
| Background queue depth | < 100 items | > 500 items |
| Auth error rate | < 0.1% | > 0.5% |
| iOS crash-free sessions | > 99.5% | < 99% |

Alerts route to on-call (PagerDuty or equivalent). Severity: P1 (auth down, data loss risk), P2 (AI pipeline degraded, >10s latency), P3 (elevated error rate).

#### Performance Markers (iOS)
Instruments-compatible timing markers in the iOS app for every user-perceived performance moment:

| Marker | Target | Measure |
|---|---|---|
| App cold start to collections visible | < 1.5s | Time to interactive |
| Share Extension save → confirmation | < 800ms | Time to save confirmation |
| Collection open → Nexus tab rendered | < 400ms | Perceived navigation speed |
| Chat message sent → first token | < 2s | Time to first token (streaming) |
| Search results rendered | < 300ms | From keypress to results |
| Library scroll | 60fps stable | Frame rate |

Use `os_signpost` on iOS for instrumentation. These markers feed into TestFlight + production Xcode Organizer metrics.

#### Structured Logging
All services log structured JSON. Every log line includes:

```json
{
  "ts": "ISO-8601",
  "level": "info|warn|error",
  "service": "api|pipeline|ai|auth",
  "trace_id": "uuid",
  "span_id": "uuid",
  "user_id": "sha256-anonymized",
  "event": "event.name",
  "duration_ms": 0,
  "error": null
}
```

- User IDs are **anonymized (SHA-256 hash)** in logs — never raw UUIDs
- Log retention: 30 days hot, 90 days cold storage
- No PII in logs: no email addresses, no content text, no URLs in production logs
- Error logs are shipped to Sentry with full context but scrubbed of content

---

## 11. Security Architecture

### Threat Model
Nexus handles personal content — articles, notes, private URLs, reading history. A breach exposes what users read, think about, and research. The threat surface includes:
- **Account takeover** — unauthorized access to a user's library
- **Data exfiltration** — bulk download of user content
- **Content injection** — malicious URLs exploiting the extraction pipeline
- **AI prompt injection** — adversarial content in saved sources manipulating AI responses
- **Supply chain** — compromised dependencies in the API or iOS app
- **Insider threat** — unauthorized internal access to user data

### Encryption

**At rest:**
- All user content (article text, transcripts, highlights, notes): AES-256-GCM, per-user encryption keys
- Embeddings: encrypted at the database level (Supabase + pgvector column-level encryption)
- Backups: encrypted with a separate backup key, stored in a geographically separate region
- User interest profiles: encrypted at rest, same key rotation schedule as content
- Encryption keys: managed via a dedicated KMS (AWS KMS or equivalent), never stored in application code or environment variables

**In transit:**
- All API traffic: TLS 1.3 minimum, TLS 1.2 forbidden
- **Certificate pinning** on iOS: pinned to Nexus API certificate chain. Prevents MITM even on compromised network infrastructure
- WebSocket connections (streaming AI responses): WSS only, same TLS requirements
- Internal service-to-service traffic (API ↔ DB, API ↔ queue): mTLS

**Key management:**
- Per-user content encryption keys, derived from a master key in KMS
- Key rotation schedule: annual for master keys, quarterly for derived keys
- Key rotation does not require user action — handled transparently with old-key → new-key migration in background
- Deleted user: encryption keys destroyed within 72 hours of account deletion, making content irrecoverable

### Authentication & Authorization

**Authentication:**
- Primary: Sign in with Apple (iOS 17+, privacy-preserving)
- Secondary: Email + magic link (no passwords stored anywhere)
- MFA: supported in Phase 2 via TOTP
- Session tokens: short-lived JWTs (15-minute access token), long-lived refresh tokens (30 days), stored in iOS Keychain (not UserDefaults)
- Refresh token rotation: each use issues a new refresh token; old one is invalidated (prevents replay)
- Concurrent session limit: 5 devices maximum; oldest session evicted on limit

**Authorization:**
- All data access enforced at the database layer via **Row-Level Security (RLS)** in Supabase/PostgreSQL
- No cross-user data access possible at the query layer — not just application-level checks
- API endpoints: every route validates JWT and extracts `user_id` from the verified token; no user_id accepted from the request body
- AI agent authorization: AI tools are scoped to the authenticated user's data only; no tool can access another user's data even with a crafted prompt
- Admin access: separate admin role with audit logging, never co-mingled with user data paths

### API Security
- **Rate limiting**: per-user (saves: 100/hour, AI queries: 50/hour, auth: 10/minute)
- **Input validation**: all incoming URLs validated and sanitized before extraction; content length limits enforced
- **SSRF protection**: extraction pipeline runs in a sandboxed network zone with an allowlist of outbound destinations; internal IP ranges blocked
- **Content Security Policy**: API responses include strict CSP headers
- **Dependency scanning**: automated via Dependabot + Snyk in CI. Critical vulnerabilities block deployment
- **SAST**: static analysis (Bandit for Python, SwiftLint security rules) runs on every PR

### AI-Specific Security
- **Prompt injection defense**: content from saved URLs is injected into AI context as data, not as instructions. System prompt is immutable and cannot be overridden by user content.
- **Output validation**: AI-generated content (summaries, answers) is validated for length, format, and absence of injection patterns before storage or display
- **Zero data retention**: Anthropic ZDR agreement ensures content sent for AI processing is never used for model training and is deleted after the API call completes
- **Tool call authorization**: AI tools are validated against an allowlist; no tool execution without an authenticated session scope

### Audit Logging
Every data access event produces an immutable audit log entry:

```json
{
  "ts": "ISO-8601",
  "event_type": "content.read|content.write|content.delete|auth.login|auth.logout|admin.access",
  "actor_id": "sha256-anonymized",
  "resource_type": "collection|source|profile|session",
  "resource_id": "uuid",
  "outcome": "success|denied",
  "ip_hash": "sha256",
  "client": "ios|api|admin"
}
```

- Audit logs are **append-only**, written to a separate, restricted store
- Retention: 2 years
- Audit log access is itself audited

### Compliance
- **GDPR**: data deletion within 30 days of request; data portability export; DPA with all sub-processors
- **CCPA**: opt-out of sale (no data is sold; still required disclosure); deletion rights
- **App Store**: compliant with Apple's data collection disclosures (nutrition labels)
- **SOC 2 Type II**: targeted for Phase 3 (enterprise tier). Controls designed from day 1 to support this.
- **OWASP Mobile Top 10**: full audit before App Store submission
- **OWASP API Security Top 10**: addressed in API design (auth, injection, SSRF, rate limiting)

### Trust Model
- The AI agent is **not trusted with write access**. It can read user data (scoped to the authenticated user) and propose output; writes only happen through validated, user-initiated paths.
- Users are **always in control**: every AI action is reversible or correctable. AI cannot delete sources, modify collection names, or alter user settings without explicit user confirmation.
- **No silent AI behavior**: every background AI action (summarization, tagging, connection surfacing) is surfaced in a transparent activity model. Users can see what the AI did and when.

---

## 12. Privacy & Data

> Full security architecture (encryption, auth, audit logging, compliance) is in **§10 Security Architecture** above.

### Principles
1. **Your data is yours** — users own their saves, insights, and memory profile
2. **AI processing is purposeful** — content is processed to serve the user, never to train models or target ads
3. **No selling of data** — business model is subscription, period
4. **Transparency** — users can see exactly what Nexus knows about them and delete it

### Data Handling
- Content extracted from URLs is stored encrypted at rest (AES-256, per-user keys)
- Embeddings are stored per-user, never shared or pooled across users
- AI calls to Anthropic API: zero data retention (ZDR) agreement — content processed but never retained or used for training
- User memory/interest profile: viewable and deletable in-app at any time
- Export: users can export their full library at any time (JSON, Markdown, CSV)
- GDPR + CCPA compliant from day 1
- No third-party advertising or tracking SDKs — ever
- First-party analytics: privacy-preserving, aggregated only (no individual-level behavioral data sold or shared)

---

## 13. Monetization

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

## 14. UX Design Direction

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

## 15. Design System Architecture

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

## 16. Launch Strategy

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

## 17. Open Questions

- [ ] What's the right monetization gate? (conversation mode? briefing? saves?) — **deferred**
- [x] AI persona: nameless. The product is Nexus. No named AI character.
- [x] Podcast v1: full transcript ingestion + summary
- [x] YouTube v1: transcript ingestion + summary
- [x] Connections: **proactive + on-demand** — AI surfaces connections automatically; user can also query on-demand
- [x] Team features: Phase 3
