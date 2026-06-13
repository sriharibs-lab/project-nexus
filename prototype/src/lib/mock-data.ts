/**
 * Mock data for the prototype.
 * Structured to match the API contract (SPEC §5a + Collection model).
 * source_count is denormalized — maintained by app layer, not derived via COUNT.
 */

export type ContentType =
  | "article"
  | "video"
  | "podcast"
  | "thread"
  | "blog"
  | "announcement"
  | "other";

export interface Source {
  id: string;
  url: string;
  title: string;
  content_type: ContentType;
  publisher: string;
  meta: string; // "Article · 8 min" etc.
  tldr?: string;
  key_insights?: string[];
  tags?: string[];
  ingest_status: "pending" | "processing" | "completed" | "failed";
}

export interface Collection {
  id: string;
  name: string;
  description?: string;
  source_count: number; // denormalized — no COUNT(*) at query time
  created_at: string;
  sources: Source[];
  ai_framing?: string; // AI-generated on collection creation
}

export const MOCK_COLLECTIONS: Collection[] = [
  {
    id: "col-1",
    name: "AI platform shifts",
    description: "How the AI stack is consolidating and where value accrues",
    source_count: 6,
    created_at: "2026-06-12T09:00:00Z",
    ai_framing:
      "This collection has 6 sources covering the strategic restructuring of the AI industry — from chip supply chains to model commoditization. I've read everything — ask me anything.",
    sources: [
      {
        id: "src-1-1",
        url: "https://stratechery.com/2026/ai-platform-end-of-beginning",
        title: "The end of the beginning for AI platforms",
        content_type: "article",
        publisher: "Stratechery",
        meta: "Article · 8 min",
        tldr:
          "Ben Thompson argues the AI platform war is entering its second act: base models are commoditizing and the battle shifts to distribution and application layers.",
        key_insights: [
          "Foundation model margins are collapsing as open-source catches proprietary frontier models",
          "Application layer (Copilot, Claude for Work) is where durable value accrues",
          "Distribution moats — existing user bases — matter more than model quality past a threshold",
        ],
        tags: ["ai-strategy", "platform-economics", "llm", "open-source"],
        ingest_status: "completed",
      },
      {
        id: "src-1-2",
        url: "https://www.theverge.com/2026/ai-models-platform",
        title: "Every model is a platform now",
        content_type: "article",
        publisher: "The Verge",
        meta: "Article · 7 min",
        tldr:
          "The Verge examines how AI companies are racing to become operating layers, not just model providers.",
        key_insights: [
          "OpenAI, Anthropic, and Google are all building SDKs, stores, and agent frameworks",
          "Tool use and memory are the new battleground — not raw benchmark scores",
          "Enterprise distribution channels (Salesforce, SAP) may determine winner",
        ],
        tags: ["openai", "anthropic", "google", "agent-frameworks", "enterprise"],
        ingest_status: "completed",
      },
      {
        id: "src-1-3",
        url: "https://arxiv.org/abs/2026.scaling-agentic",
        title: "Scaling agentic systems: a survey",
        content_type: "other",
        publisher: "arXiv",
        meta: "PDF · 38 pages",
        tldr: "Academic survey of multi-agent architectures, orchestration patterns, and scaling laws for agentic task completion.",
        key_insights: [
          "Tool-augmented agents outperform pure LLM chains on structured tasks by 40–60%",
          "Memory retrieval latency is the bottleneck in production agentic systems",
          "Hierarchical agent architectures (orchestrator + specialists) dominate flat designs",
        ],
        tags: ["multi-agent", "agentic-ai", "survey", "research"],
        ingest_status: "completed",
      },
      {
        id: "src-1-4",
        url: "https://youtube.com/watch?v=a16z-ai-stack",
        title: "Where value accrues in the AI stack",
        content_type: "video",
        publisher: "a16z · YouTube",
        meta: "Video · 31 min",
        ingest_status: "completed",
        tags: ["venture-capital", "ai-stack", "investment-thesis"],
      },
      {
        id: "src-1-5",
        url: "https://wired.com/2026/ai-operating-layer",
        title: "The quiet war for the AI operating layer",
        content_type: "article",
        publisher: "WIRED",
        meta: "Article · 11 min",
        ingest_status: "completed",
      },
      {
        id: "src-1-6",
        url: "https://ft.com/capex-supercycle",
        title: "Big tech's capex supercycle, charted",
        content_type: "article",
        publisher: "Financial Times",
        meta: "Article · 9 min",
        ingest_status: "processing",
      },
    ],
  },
  {
    id: "col-2",
    name: "Ozempic & longevity",
    description: "GLP-1 agonists, healthspan science, and the longevity drug debate",
    source_count: 5,
    created_at: "2026-06-10T14:30:00Z",
    ai_framing:
      "This collection has 5 sources covering GLP-1 agonists from clinical trial data to the cultural moment around longevity medicine. I've read everything — ask me anything.",
    sources: [
      {
        id: "src-2-1",
        url: "https://nature.com/articles/glp1-beyond-weight-loss",
        title: "GLP-1 agonists beyond weight loss",
        content_type: "article",
        publisher: "Nature",
        meta: "Article · 9 min",
        tldr:
          "Nature reviews emerging evidence that semaglutide and tirzepatide may reduce cardiovascular events, neurodegeneration risk, and all-cause mortality independent of weight loss.",
        key_insights: [
          "SELECT trial: 20% cardiovascular event reduction in non-diabetic obese patients",
          "Neuroinflammation pathway may explain cognitive benefits observed in observational studies",
          "Muscle mass loss (3–5% in trial arms) remains the key safety concern for longevity use cases",
        ],
        tags: ["glp-1", "semaglutide", "longevity", "cardiovascular", "clinical-trial"],
        ingest_status: "completed",
      },
      {
        id: "src-2-2",
        url: "https://statnews.com/2026/glp1-aging",
        title: "What we actually know about GLP-1s and aging",
        content_type: "article",
        publisher: "STAT News",
        meta: "Article · 12 min",
        ingest_status: "completed",
        tags: ["glp-1", "aging", "healthspan"],
      },
      {
        id: "src-2-3",
        url: "https://theatlantic.com/longevity-drug",
        title: "The longevity drug hiding in plain sight",
        content_type: "article",
        publisher: "The Atlantic",
        meta: "Article · 14 min",
        ingest_status: "completed",
      },
      {
        id: "src-2-4",
        url: "https://youtube.com/watch?v=ted-metabolism",
        title: "Metabolism, medicine and healthspan",
        content_type: "video",
        publisher: "TED · YouTube",
        meta: "Video · 18 min",
        ingest_status: "completed",
      },
      {
        id: "src-2-5",
        url: "https://economist.com/longevity-trillion",
        title: "The trillion-dollar question of living longer",
        content_type: "article",
        publisher: "The Economist",
        meta: "Article · 10 min",
        ingest_status: "pending",
      },
    ],
  },
  {
    id: "col-3",
    name: "US–Iran conflict",
    description: "Diplomacy, sanctions, and regional dynamics",
    source_count: 6,
    created_at: "2026-06-09T08:00:00Z",
    ai_framing:
      "This collection has 6 sources covering the current state of US–Iran tensions, from back-channel diplomacy to the nuclear question. I've read everything — ask me anything.",
    sources: [
      {
        id: "src-3-1",
        url: "https://reuters.com/us-iran-oman-talks",
        title: "US and Iran resume back-channel talks in Oman",
        content_type: "article",
        publisher: "Reuters",
        meta: "Article · 6 min",
        ingest_status: "completed",
        tags: ["diplomacy", "iran", "sanctions", "oman"],
      },
      {
        id: "src-3-2",
        url: "https://bbc.com/hormuz",
        title: "What's at stake in the Strait of Hormuz",
        content_type: "article",
        publisher: "BBC News",
        meta: "Article · 8 min",
        ingest_status: "completed",
      },
      {
        id: "src-3-3",
        url: "https://aljazeera.com/iran-us-timeline",
        title: "Timeline: US–Iran tensions since 2020",
        content_type: "article",
        publisher: "Al Jazeera",
        meta: "Article · 10 min",
        ingest_status: "completed",
      },
      {
        id: "src-3-4",
        url: "https://understandingwar.org/iran-june-2026",
        title: "Iran update — June 2026 assessment",
        content_type: "other",
        publisher: "ISW",
        meta: "PDF · 24 pages",
        ingest_status: "completed",
      },
      {
        id: "src-3-5",
        url: "https://youtube.com/cfr-us-iran",
        title: "Why the US and Iran keep colliding",
        content_type: "video",
        publisher: "CFR · YouTube",
        meta: "Video · 14 min",
        ingest_status: "completed",
      },
      {
        id: "src-3-6",
        url: "https://foreignaffairs.com/iran-deal-2026",
        title: "The narrow deal that could end the standoff",
        content_type: "article",
        publisher: "Foreign Affairs",
        meta: "Article · 12 min",
        ingest_status: "processing",
      },
    ],
  },
  {
    id: "col-4",
    name: "Vision Pro 2",
    description: "Hardware refresh, developer ecosystem, and spatial computing's second act",
    source_count: 4,
    created_at: "2026-06-08T16:00:00Z",
    sources: [
      {
        id: "src-4-1",
        url: "https://bloomberg.com/vision-pro-2",
        title: "Inside the lighter, cheaper Vision Pro 2",
        content_type: "article",
        publisher: "Bloomberg",
        meta: "Article · 7 min",
        ingest_status: "completed",
        tags: ["apple", "vision-pro", "spatial-computing", "hardware"],
      },
      {
        id: "src-4-2",
        url: "https://theverge.com/vision-pro-2-review",
        title: "Hands-on: what changed, what didn't",
        content_type: "article",
        publisher: "The Verge",
        meta: "Article · 9 min",
        ingest_status: "completed",
      },
      {
        id: "src-4-3",
        url: "https://youtube.com/vision-pro-2-review",
        title: "Vision Pro 2 — full review",
        content_type: "video",
        publisher: "YouTube",
        meta: "Video · 22 min",
        ingest_status: "completed",
      },
      {
        id: "src-4-4",
        url: "https://ft.com/spatial-computing-platform",
        title: "Can headsets become the next platform?",
        content_type: "article",
        publisher: "Financial Times",
        meta: "Article · 11 min",
        ingest_status: "completed",
      },
    ],
  },
];

export const STARTER_PROMPTS = [
  "What are the key ideas across these sources?",
  "What should I read first?",
  "Summarize this collection in 3 bullet points",
  "What questions does this collection raise?",
  "Are there any contradictions between sources?",
  "What's missing from this collection?",
];

export function getCollection(id: string): Collection | undefined {
  return MOCK_COLLECTIONS.find((c) => c.id === id);
}

export function contentTypeIcon(type: ContentType): string {
  switch (type) {
    case "video":
      return "video";
    case "podcast":
      return "mic";
    case "thread":
      return "thread";
    case "other":
      return "file";
    default:
      return "globe";
  }
}

export function relativeTime(iso: string): string {
  const d = new Date(iso);
  const now = new Date("2026-06-13T12:00:00Z");
  const diff = now.getTime() - d.getTime();
  const days = Math.floor(diff / 86400000);
  if (days === 0) return "Today";
  if (days === 1) return "Yesterday";
  if (days < 7) return `${days}d ago`;
  return d.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}
