"""
Nexus AI Processing Pipeline
Summarization + semantic tagging via Claude Haiku 4.5.
Embeddings via Fireworks nomic-embed-text-v1.5 (768-dim, pgvector-ready).
Collection research streaming via Claude Sonnet (SPEC §9c).
"""

import asyncio
import json
import os
from collections.abc import AsyncGenerator
from dataclasses import dataclass, field
from decimal import Decimal
from typing import Literal

import anthropic
from openai import AsyncOpenAI

from app.core.config import settings

_client = anthropic.AsyncAnthropic(
    api_key=os.environ.get("ANTHROPIC_API_KEY") or settings.anthropic_api_key
)
_fireworks = AsyncOpenAI(
    # Placeholder keeps the client constructible when the key is absent;
    # embedding calls fail with a clear 401 instead of crashing startup.
    api_key=os.environ.get("FIREWORKS_API_KEY") or settings.fireworks_api_key or "missing-key",
    base_url="https://api.fireworks.ai/inference/v1",
)

ContentType = Literal["article", "youtube", "podcast"]

# Pricing constants (per token)
_HAIKU_INPUT_COST = Decimal("0.0000008")   # $0.80 / 1M
_HAIKU_OUTPUT_COST = Decimal("0.000004")   # $4.00 / 1M
_SONNET_INPUT_COST = Decimal("0.000003")   # $3.00 / 1M
_SONNET_OUTPUT_COST = Decimal("0.000015")  # $15.00 / 1M

SYSTEM_PROMPT = """\
You are an expert content analyst for Nexus, an AI-native content curation app. \
Your job is to extract high signal from content so users never miss what matters.

Rules:
- TL;DR: 1-2 punchy sentences. Lead with the core insight, not the topic.
- Key insights: exactly 3-5 bullet points. Each must be specific and actionable—no fluff.
- Tags: 3-8 lowercase semantic tags. Prefer precise concepts over broad categories \
(e.g. "retrieval-augmented-generation" over "ai"). Include domain, format, and topic tags.

Respond with valid JSON only. No markdown fences."""

USER_TEMPLATE = """\
Content type: {content_type}
---
{content}
---

Return JSON with this exact structure:
{{
  "tldr": "string",
  "insights": ["string", ...],
  "tags": ["string", ...]
}}"""

# Research prompt — Sonnet only (SPEC §9c: collection research requires judgment and web knowledge)
_RESEARCH_SYSTEM = """\
You are Nexus, an AI-native content curation assistant. Your job is to find the best \
real, current sources on a topic so the user can build a collection that becomes their \
trusted knowledge base on it.

HOW TO WORK — you have a web_search tool. USE IT. Do NOT rely on memory or recall URLs:
- Run SEVERAL searches (3-6) from DIFFERENT angles to build a rich, diverse set. \
  Cover, as relevant: the latest news/coverage; official & primary sources (government \
  agencies, organizations, official statements/reports); academic or technical work \
  (papers, field surveys, journals); explainers/background; and local or regional \
  perspectives. Vary your queries — don't search the same phrase repeatedly.
- Recommend ONLY sources you actually found in the results, using the EXACT URLs the \
  search returned. Never invent, guess, or recall a URL.

Output rules:
- RELEVANCE IS NON-NEGOTIABLE: every source must be directly and specifically about \
  THIS exact topic. Drop anything tangential, off-topic, or a loose keyword match.
- DIVERSITY MATTERS: return a rich MIX of source types and perspectives — news, \
  primary/official, academic/technical, analysis/explainer, and (where relevant) \
  local/regional. Do not return 8 of the same kind or 8 from a single site. This \
  breadth is what makes a collection feel complete.
- Return up to 8 sources (fewer is fine). Relevance, diversity, and freshness over count.
- The user's reader fetches each URL's full text, so prefer OPENLY readable sources. \
  Avoid hard-paywalled/bot-blocked sites (nytimes, wsj, ft, bloomberg, economist, \
  newyorker) and store/product pages. Favor news wires (Reuters, AP), .gov/.edu, arXiv \
  and journals, Wikipedia, official blogs/docs, and reputable open outlets.
- One-sentence rationale per source: why it's worth reading.

After searching, respond with ONLY a JSON array (no prose, no markdown fences) of objects:
[
  {
    "title": "string",
    "url": "https://...   (the exact URL from the search result)",
    "domain": "string (site name, e.g. 'Reuters', 'USGS')",
    "rationale": "string (1 sentence)",
    "content_type": "article | video | podcast | thread | paper"
  }
]"""

_RESEARCH_SYSTEM_CACHE_CONTROL = [
    {
        "type": "text",
        "text": _RESEARCH_SYSTEM,
        "cache_control": {"type": "ephemeral"},
    }
]


@dataclass
class ProcessedItem:
    tldr: str
    insights: list[str]
    tags: list[str]
    input_tokens: int = 0
    output_tokens: int = 0
    cache_read_tokens: int = 0
    model: str = "claude-haiku-4-5"
    cost_usd: Decimal = field(default_factory=lambda: Decimal("0"))


@dataclass
class SourceRow:
    """One AI-suggested source returned by research_topic."""
    title: str
    url: str
    domain: str
    rationale: str
    content_type: str


@dataclass
class ResearchResult:
    """Return value of research_topic_with_usage — sources + actual token usage."""
    sources: list[SourceRow]
    input_tokens: int
    output_tokens: int
    cache_read_tokens: int
    model: str = "claude-sonnet-4-6"


@dataclass
class FramingResult:
    """Return value of build_collection_framing — sentence, 3 contextual starter
    questions, and actual token usage."""
    sentence: str
    input_tokens: int
    output_tokens: int
    questions: list[str] = field(default_factory=list)


@dataclass
class EmbeddingResult:
    """pgvector-ready: 768-dim float32 vector stored as list[float] (Fireworks nomic-embed-text-v1.5)."""
    vector: list[float]
    dimensions: int
    model: str
    cost_usd: Decimal = field(default_factory=lambda: Decimal("0"))


async def summarize_item(content: str, content_type: str) -> ProcessedItem:
    """
    Summarize content and extract semantic tags via Claude Haiku.
    Returns TL;DR, 3-5 key insights, and semantic tags.
    """
    response = await _client.messages.create(
        model="claude-haiku-4-5",
        max_tokens=512,
        system=[
            {
                "type": "text",
                "text": SYSTEM_PROMPT,
                "cache_control": {"type": "ephemeral"},
            }
        ],
        messages=[
            {
                "role": "user",
                "content": USER_TEMPLATE.format(
                    content_type=content_type,
                    content=content[:8000],  # guard against huge inputs
                ),
            }
        ],
    )

    raw = next(b.text for b in response.content if b.type == "text")

    # strip accidental markdown fences if the model adds them
    if raw.startswith("```"):
        raw = raw.split("```")[1]
        if raw.startswith("json"):
            raw = raw[4:]

    data = json.loads(raw.strip())

    input_tokens = response.usage.input_tokens
    output_tokens = response.usage.output_tokens
    cache_tokens = getattr(response.usage, "cache_read_input_tokens", 0) or 0
    cost = (
        Decimal(input_tokens) * _HAIKU_INPUT_COST
        + Decimal(output_tokens) * _HAIKU_OUTPUT_COST
    )

    return ProcessedItem(
        tldr=data["tldr"],
        insights=data["insights"],
        tags=data["tags"],
        input_tokens=input_tokens,
        output_tokens=output_tokens,
        cache_read_tokens=cache_tokens,
        model="claude-haiku-4-5",
        cost_usd=cost,
    )


async def research_topic(
    topic: str,
) -> AsyncGenerator[SourceRow, None]:
    """
    Stream AI-suggested sources for a topic using Claude Sonnet (SPEC §9c).

    Yields SourceRow objects one at a time as the model completes each JSON
    object in its streamed array. The iOS FRE screen receives one SSE event
    per source so the user sees sources appear progressively.

    Parsing strategy: buffer the full streamed text, then parse the JSON array
    once complete. Claude reliably completes valid JSON with streaming=True and
    structured output instruction. We do not attempt streaming JSON parsing
    (fragile) — instead we yield all rows at once after the stream closes.
    Latency is acceptable at 10-15s total (SPEC §9c).

    Note on 'total' count: because we buffer the full response before yielding,
    the caller can count rows from the done event. The SSE source events do not
    include a 'total' field — the iOS client uses the source_count from the
    final 'done' event to display the count retroactively.
    """
    result = await research_topic_with_usage(topic)
    for row in result.sources:
        yield row


async def research_topic_with_usage(topic: str) -> ResearchResult:
    """
    Collect AI-suggested sources + actual token usage from the Anthropic response.

    Returns ResearchResult with sources list and real token counts read from
    stream.get_final_message().usage — not estimated. Used by the research router
    to write accurate AiTelemetry records (SPEC §9b cost telemetry).
    """
    model = settings.research_model
    async with _client.messages.stream(
        model=model,
        max_tokens=4096,
        system=_RESEARCH_SYSTEM_CACHE_CONTROL,
        # Ground discovery in a REAL web search (server-side tool) instead of the
        # model recalling URLs from memory — the fix for stale/generic/hallucinated
        # sources and the NotebookLM-richness gap (2026-08-14). The search does the
        # grounding, so a cheaper model curates well; max_uses caps search spend.
        tools=[{"type": "web_search_20250305", "name": "web_search",
                "max_uses": settings.research_web_search_max_uses}],
        messages=[
            {
                "role": "user",
                "content": f"Find the best real, current, diverse sources to understand this topic deeply: {topic}",
            }
        ],
    ) as stream:
        full_text = ""
        async for text in stream.text_stream:
            full_text += text
        final_message = await stream.get_final_message()

    usage = final_message.usage
    input_tokens = usage.input_tokens
    output_tokens = usage.output_tokens
    cache_tokens = getattr(usage, "cache_read_input_tokens", 0) or 0

    raw = full_text.strip()
    # Extract the JSON array even if the model narrated around it — web_search
    # turns often prompt some prose despite the "JSON only" instruction.
    start, end = raw.find("["), raw.rfind("]")
    if start != -1 and end > start:
        raw = raw[start:end + 1]

    try:
        rows = json.loads(raw)
    except json.JSONDecodeError:
        return ResearchResult(sources=[], input_tokens=input_tokens, output_tokens=output_tokens, cache_read_tokens=cache_tokens, model=model)

    sources = [
        SourceRow(
            title=row.get("title", ""),
            url=row.get("url", ""),
            domain=row.get("domain", ""),
            rationale=row.get("rationale", ""),
            content_type=row.get("content_type", "article"),
        )
        for row in rows
    ]
    return ResearchResult(sources=sources, input_tokens=input_tokens, output_tokens=output_tokens, cache_read_tokens=cache_tokens, model=model)


async def build_collection_framing(collection_name: str, first_summary: str) -> FramingResult:
    """
    Generate the Nexus-tab hero sentence shown after the first source ingests.
    Called once per collection; result stored in Collection.framing_paragraph.

    Returns FramingResult with the sentence and actual token usage so callers
    can write accurate AiTelemetry records (operation="collection_framing").
    """
    response = await _client.messages.create(
        model="claude-haiku-4-5",
        max_tokens=320,
        messages=[{
            "role": "user",
            "content": (
                f'A user just created the Nexus collection "{collection_name}". '
                f"Its first source summary:\n{first_summary}\n\n"
                "Return ONLY JSON (no markdown fences): "
                '{"framing": "<sentence>", "questions": ["<q1>", "<q2>", "<q3>"]}\n'
                "- framing: one warm, direct sentence acknowledging what was saved and "
                'inviting the user to ask anything. Don\'t start with "I". No quotes.\n'
                "- questions: exactly 3 SPECIFIC, curiosity-driving questions this user "
                "would want to ask about THIS collection, concrete to its subject — not "
                "generic ('summarize this', 'key ideas'). 4-9 words each, no trailing period."
            ),
        }],
    )
    text = response.content[0].text.strip()
    if text.startswith("```"):                       # strip accidental fences
        text = text.strip("`")
        text = text[4:].strip() if text.startswith("json") else text.strip()
    sentence, questions = text, []
    try:
        data = json.loads(text)
        sentence = str(data.get("framing", "")).strip() or text
        questions = [str(q).strip() for q in data.get("questions", []) if str(q).strip()][:3]
    except Exception:
        pass
    return FramingResult(
        sentence=sentence,
        questions=questions,
        input_tokens=response.usage.input_tokens,
        output_tokens=response.usage.output_tokens,
    )


_TRENDING_SYSTEM = """You turn raw "what's popular right now" signals into sharp, \
research-worthy topics for a curious person to start a collection on.

You'll receive today's most-read Wikipedia articles and top Hacker News stories. \
Pick and REFRAME the best into exactly 6 collection topics.

Rules:
- DROP noise: obituaries ("Deaths in 2026"), disambiguation/list pages, adult \
content, raw sports scores, and low-substance celebrity gossip.
- REFRAME into a clean, compelling 2-5 word topic. Examples: "The Odyssey (2026 \
film)" -> "Nolan's Odyssey adaptation"; "ChatGPT" -> "The state of AI assistants".
- Favor SUBSTANCE and VARIETY: mix current events, science/tech, ideas, and \
culture — never 6 of the same kind.
- Each must be something you could genuinely research and build a collection about.

Return ONLY a JSON array of exactly 6 short strings. No prose, no markdown."""


async def curate_trending_topics(signals: list[str]) -> list[str]:
    """Reframe raw trending signals (Wikipedia most-read + HN top) into 6 clean,
    research-worthy collection topics via Haiku. Returns [] on any failure so the
    caller falls back to a static list. Cheap: one small Haiku call, cached upstream."""
    if not settings.anthropic_api_key or not signals:
        return []
    try:
        response = await _client.messages.create(
            model="claude-haiku-4-5",
            max_tokens=256,
            system=_TRENDING_SYSTEM,
            messages=[{
                "role": "user",
                "content": "Today's signals:\n" + "\n".join(f"- {s}" for s in signals[:40]),
            }],
        )
        text = response.content[0].text.strip()
        if text.startswith("```"):                 # strip accidental code fences
            text = text.strip("`")
            text = text[4:].strip() if text.startswith("json") else text.strip()
        topics = json.loads(text)
        return [str(t).strip() for t in topics if str(t).strip()][:6]
    except Exception:
        return []


async def compute_embedding(content: str) -> EmbeddingResult:
    """Embed content via Fireworks nomic-embed-text-v1.5 (768-dim, pgvector-ready)."""
    _EMBED_COST = Decimal("0.000000008")  # $0.008 / 1M tokens (Fireworks pricing)
    response = await _fireworks.embeddings.create(
        input=content[:8000],
        model="nomic-ai/nomic-embed-text-v1.5",
    )
    vector = response.data[0].embedding
    tokens = response.usage.total_tokens
    return EmbeddingResult(
        vector=vector,
        dimensions=len(vector),
        model="nomic-ai/nomic-embed-text-v1.5",
        cost_usd=Decimal(tokens) * _EMBED_COST,
    )


# ---------------------------------------------------------------------------
# Daily Briefing
# ---------------------------------------------------------------------------

BRIEFING_SYSTEM = """You are the Nexus Daily Briefing engine. Your job is to synthesize a user's recent saved content into a concise, high-signal morning briefing.

Rules:
- Headline: one punchy sentence capturing the most important theme or trend across all items.
- Sections: 2-5 thematic sections. Each section has a title (\u22646 words) and 2-4 bullet points.
  Each bullet must cite the source item by its id using the format [item:<id>].
- Do not fabricate insights not present in the source items.
- Tone: direct, intelligent, non-corporate. Like a smart colleague's Slack summary.

Respond with valid JSON only. No markdown fences."""

BRIEFING_USER_TEMPLATE = """\
User interest weights (higher = more relevant to user):
{interest_profile}

Recent saved items (newest first):
{items_block}

Return JSON with this exact structure:
{{
  "headline": "string",
  "sections": [
    {{
      "title": "string",
      "bullets": ["string", ...]
    }}
  ]
}}"""


@dataclass
class BriefingSection:
    title: str
    bullets: list[str]


@dataclass
class BriefingResult:
    headline: str
    sections: list[BriefingSection]
    input_tokens: int
    output_tokens: int
    items_used: int


@dataclass
class BriefingItem:
    """Minimal item descriptor passed to generate_daily_briefing()."""
    id: str
    title: str | None
    summary: str | None
    tags: list[str] = field(default_factory=list)


async def generate_daily_briefing(
    items: list[BriefingItem],
    interest_weights: dict[str, float],
) -> BriefingResult:
    """
    Generate a structured daily briefing from recent completed items and the
    user's interest profile (tag \u2192 weight mapping).

    Args:
        items: Recent completed items, ordered newest-first. Pass at most 20;
               caller is responsible for fetching via fetch_recent_items_for_briefing().
        interest_weights: Tag-to-weight map from UserInterestProfile.topics.
                          Empty dict is accepted (briefing still generated, unweighted).

    Returns:
        BriefingResult with headline, thematic sections, and token telemetry.

    Raises:
        RuntimeError: if ANTHROPIC_API_KEY is not set.
        ValueError: if items list is empty (nothing to brief on).
        json.JSONDecodeError: if the model returns malformed JSON.
    """
    if not os.environ.get("ANTHROPIC_API_KEY"):
        raise RuntimeError("ANTHROPIC_API_KEY is not set")
    if not items:
        raise ValueError("items must not be empty \u2014 no completed items to brief on")

    # Build interest profile block (top-15 by weight, descending)
    sorted_weights = sorted(interest_weights.items(), key=lambda kv: kv[1], reverse=True)[:15]
    if sorted_weights:
        interest_block = "\n".join(f"  {tag}: {weight:.2f}" for tag, weight in sorted_weights)
    else:
        interest_block = "  (no profile yet \u2014 treat all topics equally)"

    # Build items block \u2014 one entry per item, concise
    item_lines: list[str] = []
    for item in items[:20]:  # hard cap at 20 to control context size
        tag_str = ", ".join(item.tags[:5]) if item.tags else "no tags"
        summary_text = item.summary or "(no summary)"
        title_text = item.title or "(untitled)"
        item_lines.append(
            f"[item:{item.id}] {title_text}\n"
            f"  tags: {tag_str}\n"
            f"  summary: {summary_text}"
        )
    items_block = "\n\n".join(item_lines)

    response = await _client.messages.create(
        model="claude-haiku-4-5",
        max_tokens=1024,
        system=BRIEFING_SYSTEM,
        messages=[
            {
                "role": "user",
                "content": BRIEFING_USER_TEMPLATE.format(
                    interest_profile=interest_block,
                    items_block=items_block,
                ),
            }
        ],
    )

    raw = next(b.text for b in response.content if b.type == "text")

    # Strip accidental markdown fences
    if raw.startswith("```"):
        raw = raw.split("```")[1]
        if raw.startswith("json"):
            raw = raw[4:]

    data = json.loads(raw.strip())

    sections = [
        BriefingSection(title=s["title"], bullets=s["bullets"])
        for s in data["sections"]
    ]

    return BriefingResult(
        headline=data["headline"],
        sections=sections,
        input_tokens=response.usage.input_tokens,
        output_tokens=response.usage.output_tokens,
        items_used=len(items),
    )


# ---------------------------------------------------------------------------
# Example outputs
# ---------------------------------------------------------------------------

ARTICLE = """\
Sam Altman published a blog post outlining OpenAI's roadmap toward AGI. He describes \
a five-step framework: Chatbots → Reasoners → Agents → Innovators → Organizations. \
OpenAI claims GPT-4 is at level 1 and o1 is approaching level 2. Altman argues that \
level 3 (agents doing the work of a skilled employee autonomously) will arrive within \
years, not decades. He addresses safety by saying OpenAI is committed to a \
"preparedness framework" that governs each capability jump. Critics argue the framework \
lacks independent enforcement and that the commercial incentives to race ahead are too \
strong. The post also hints at forthcoming multimodal reasoning models that can operate \
computers directly."""

YOUTUBE = """\
[YouTube transcript - Andrej Karpathy: The Unreasonable Effectiveness of RNNs (revisited)]

OK so I posted this blog post like ten years ago and people still reference it, and \
I think it's time for a retrospective. Back then sequence models felt like magic—you \
trained an LSTM on Shakespeare and it produced Shakespeare-like text. People were amazed.

What's changed? Transformers replaced RNNs almost entirely for language. The attention \
mechanism turned out to be strictly better: parallelizable during training, better at \
long-range dependencies, and empirically just more capable per parameter. RNNs still \
live in edge-device time-series workloads where you need online inference with tiny \
memory.

The deeper point holds though—the power of just predicting the next token. That \
self-supervised objective is insanely general. We now know it leads to emergent \
capabilities that nobody explicitly programmed. Arithmetic, reasoning, translation—all \
fall out of next-token prediction at scale.

My current view: we're probably going to scale transformers until we hit a wall \
(compute, data, or architectural). Then something new will emerge. Maybe SSMs like \
Mamba close the gap on RNNs' efficiency edge while matching transformer quality. \
The field is moving fast."""

PODCAST = """\
[Podcast transcript - Acquired: Jensen Huang and the NVIDIA Story]

Ben: So Jensen, the question everyone has is—was this planned? Did you know in 2006 \
when you launched CUDA that you were building the substrate for a future AI revolution?

Jensen: Honestly? No. CUDA was built for scientific computing. We wanted physicists \
to use GPUs for simulations. The first real signal was when Alex Krizhevsky won \
ImageNet in 2012 running on two GeForce GTX 580s. That was the moment I called the \
team together and said this is going to be much bigger than we thought.

David: You went all-in on deep learning before it had a clear commercial path.

Jensen: We bet the company multiple times. Going from gaming GPUs to data center \
required completely different supply chains, different customers, different sales \
motions. There were years where the data center revenue was rounding error. CUDA \
ecosystem is ultimately why we have the moat—if you've trained your team on CUDA, \
you don't switch. That took fifteen years to build.

Ben: The H100 backlog was reportedly over a year at peak demand. How did you manage \
that capacity constraint while also keeping your biggest customers happy?

Jensen: Allocation is the hardest thing. You're making decisions that affect \
companies worth trillions of dollars. We tried to be transparent and first-in \
first-out where possible. But yes, there were painful conversations."""


# ══════════════════════════════════════════════════════════════════════════
# Create-tab artifacts — generated by an OPEN-SOURCE Fireworks model
# (settings.fireworks_text_model, default gpt-oss-120b). Deliberately NOT
# Anthropic: the Create studio runs on OSS weights end-to-end.
# ══════════════════════════════════════════════════════════════════════════


@dataclass
class ArtifactResult:
    kind: str
    title: str
    content: dict
    model: str
    input_tokens: int = 0
    output_tokens: int = 0


_QUIZ_SYSTEM = """\
You write short, fair multiple-choice quizzes that test real comprehension of a \
set of sources. Rules:
- Base EVERY question strictly on the provided sources. Never invent facts.
- Each question has exactly 4 options, exactly one correct.
- Options must be plausible — no giveaways, no "all of the above".
- "why" explains the correct answer in one sentence, grounded in the sources.
Return ONLY a JSON object of this exact shape (no prose, no markdown fence):
{"questions": [{"q": "string", "options": ["a","b","c","d"], "answer": 0, "why": "string"}]}
"answer" is the 0-based index of the correct option."""

_PAPER_SYSTEM = """\
You are a sharp research writer. Using ONLY the provided sources, write a concise, \
well-structured briefing on the topic. Rules:
- Ground every claim in the sources; do not fabricate facts or citations.
- Start with a single "# Title" line, then flowing prose under "## " section \
headings. Cover: what's going on, where sources agree/disagree, and what it \
means / what's next.
- Follow the requested length and style. Clean GitHub-flavored markdown. No \
preamble like "Here is"."""


def _fw_usage(resp) -> tuple[int, int]:
    u = getattr(resp, "usage", None)
    return (getattr(u, "prompt_tokens", 0) or 0, getattr(u, "completion_tokens", 0) or 0)


_QUIZ_DIFFICULTY = {
    "easy": "Easy: test recall of key facts and definitions stated plainly in the sources.",
    "medium": "Medium: test comprehension and application — connect ideas across the sources.",
    "hard": "Hard: test synthesis and nuance — subtle distinctions, implications, and edge cases.",
}


async def generate_quiz(
    collection_name: str,
    context: str,
    num_questions: int = 5,
    difficulty: str = "medium",
) -> ArtifactResult:
    """Generate a grounded multiple-choice quiz from a collection's sources."""
    model = settings.fireworks_text_model
    difficulty = difficulty if difficulty in _QUIZ_DIFFICULTY else "medium"
    num_questions = min(max(num_questions, 1), 15)
    user = (
        f"Collection: {collection_name}\n\nSOURCES:\n{context}\n\n"
        f"Difficulty — {_QUIZ_DIFFICULTY[difficulty]}\n"
        f"Write {num_questions} multiple-choice questions that test understanding of these sources."
    )
    # NOTE: gpt-oss-120b garbles output under response_format=json_object
    # (returns a JSON-schema-shaped object, often truncated). In plain mode it
    # emits clean {"questions":[...]} — so we prompt for JSON and extract it,
    # mirroring the research path's find("{")/rfind("}") approach.
    resp = await _fireworks.chat.completions.create(
        model=model,
        messages=[{"role": "system", "content": _QUIZ_SYSTEM}, {"role": "user", "content": user}],
        max_tokens=1600,
        temperature=0.4,
    )
    inp, out = _fw_usage(resp)
    raw = (resp.choices[0].message.content or "").strip()
    # Isolate the JSON object even if the model narrates around it.
    start, end = raw.find("{"), raw.rfind("}")
    if start != -1 and end > start:
        raw = raw[start:end + 1]

    questions: list[dict] = []
    try:
        data = json.loads(raw)
        candidates = data.get("questions") if isinstance(data, dict) else data
        for row in candidates or []:
            opts = row.get("options") or []
            ans = row.get("answer")
            # Keep only well-formed items: 4 options, a valid answer index.
            if isinstance(opts, list) and len(opts) == 4 and isinstance(ans, int) and 0 <= ans <= 3 and row.get("q"):
                questions.append({
                    "q": str(row["q"]).strip(),
                    "options": [str(o).strip() for o in opts],
                    "answer": ans,
                    "why": str(row.get("why", "")).strip(),
                })
    except json.JSONDecodeError:
        pass

    if not questions:
        raise ValueError("quiz generation returned no valid questions")

    return ArtifactResult(
        kind="quiz",
        title=f"Quiz — {collection_name}",
        content={"questions": questions},
        model=model,
        input_tokens=inp,
        output_tokens=out,
    )


_PAPER_LENGTH = {
    "brief": ("~250-350 words, 2-3 sections", 900),
    "standard": ("~500-800 words, 3-5 sections", 2200),
    "indepth": ("~1000-1400 words, 5-7 sections with more detail", 3600),
}
_PAPER_STYLE = {
    "explainer": "Plain, accessible explainer tone — clear language a curious non-expert can follow.",
    "academic": "Formal, analytical academic tone — precise, measured, argument-driven.",
    "executive": "Crisp executive tone — lead with a one-line bottom line, then tight sections and bulleted takeaways.",
}


async def generate_paper(
    collection_name: str,
    context: str,
    length: str = "standard",
    style: str = "explainer",
) -> ArtifactResult:
    """Generate a grounded report (markdown) from a collection's sources."""
    model = settings.fireworks_text_model
    length = length if length in _PAPER_LENGTH else "standard"
    style = style if style in _PAPER_STYLE else "explainer"
    length_hint, max_toks = _PAPER_LENGTH[length]
    user = (
        f"Topic / collection: {collection_name}\n\nSOURCES:\n{context}\n\n"
        f"Length — {length_hint}.\nStyle — {_PAPER_STYLE[style]}\n\nWrite the report now."
    )
    resp = await _fireworks.chat.completions.create(
        model=model,
        messages=[{"role": "system", "content": _PAPER_SYSTEM}, {"role": "user", "content": user}],
        max_tokens=max_toks,
        temperature=0.6,
    )
    inp, out = _fw_usage(resp)
    md = (resp.choices[0].message.content or "").strip()
    if not md:
        raise ValueError("paper generation returned empty content")

    # Derive the title from the first H1; fall back to the collection name.
    title = f"{collection_name}: what the sources say"
    for line in md.splitlines():
        if line.startswith("# "):
            title = line[2:].strip()
            break
    # Section headings → outline (for a scannable table of contents in-app).
    outline = [ln[3:].strip() for ln in md.splitlines() if ln.startswith("## ")]

    return ArtifactResult(
        kind="paper",
        title=title[:300],
        content={"markdown": md, "outline": outline},
        model=model,
        input_tokens=inp,
        output_tokens=out,
    )


_INFO_ICONS = frozenset({
    "sparkles", "bolt.fill", "brain.head.profile", "chart.line.uptrend.xyaxis", "chart.bar.fill",
    "clock.fill", "calendar", "globe", "person.2.fill", "person.3.fill", "building.2.fill",
    "banknote.fill", "dollarsign.circle.fill", "cpu.fill", "leaf.fill", "heart.fill", "flame.fill",
    "drop.fill", "book.fill", "graduationcap.fill", "lightbulb.fill", "star.fill", "trophy.fill",
    "flag.fill", "map.fill", "airplane", "car.fill", "music.note", "film.fill", "paintpalette.fill",
    "camera.fill", "gamecontroller.fill", "cross.case.fill", "pills.fill", "fork.knife", "cart.fill",
    "shippingbox.fill", "antenna.radiowaves.left.and.right", "network", "lock.fill",
    "exclamationmark.triangle.fill", "checkmark.seal.fill", "arrow.up.right", "arrow.down.right",
    "scalemass.fill", "hourglass", "atom", "sun.max.fill", "moon.fill",
})
_INFO_THEMES = frozenset({"plum", "ember", "ocean", "forest", "amber"})
_INFO_LAYOUTS = {"numbers", "timeline", "comparison"}

_INFOGRAPHIC_SYSTEM = """\
You distill a set of sources into a tight, factual infographic spec that is \
rendered natively on a phone. Return ONLY a JSON object (no prose, no markdown \
fence) of this exact shape:
{
  "title": "short punchy title (<= 48 chars)",
  "subtitle": "one-line framing (<= 90 chars)",
  "layout": "numbers" | "timeline" | "comparison",
  "theme": "plum" | "ember" | "ocean" | "forest" | "amber",
  "icon": "<one SF Symbol name from the allowed list>",
  "hero": {"value": "<= 12 chars", "label": "<= 40 chars"} | null,
  "numbers":    [{"value": "<= 12 chars", "label": "<= 40 chars", "icon": "<allowed>", "pct": 0-100 | null}],
  "timeline":   [{"when": "<= 12 chars", "what": "<= 64 chars", "icon": "<allowed>"}],
  "comparison": {"a": "<= 22 chars", "b": "<= 22 chars", "rows": [{"aspect": "<= 24", "a": "<= 36", "b": "<= 36", "edge": "a" | "b" | null}]},
  "takeaway": "<= 110 chars — the so-what in one sentence"
}
Rules:
- Include ONLY the array/object matching "layout"; omit the others.
- Base every value STRICTLY on the sources — never invent figures, dates or \
claims. Prefer concrete numbers/dates. If a number isn't in the sources, don't \
fabricate one.
- theme: pick the one that fits the subject's mood (plum = ideas/tech/culture, \
ember = energy/sport/conflict, ocean = science/finance/calm, forest = nature/\
health/growth, amber = history/food/warmth).
- icon: one symbol for the whole piece; item icons may differ. Use ONLY names \
from the allowed list: """ + ", ".join(sorted(_INFO_ICONS)) + """.
- hero: the single most striking figure from the sources, or null if none.
- numbers: 3-6 items. "pct" = relative magnitude 0-100 for a bar ONLY when the \
values are directly comparable (same unit); otherwise null.
- timeline: 4-6 chronological items. "when" is a year or "Mar 2024" — never a \
range longer than 12 chars.
- comparison: 2 sides, 3-5 rows. "edge" = which side is stronger on that aspect \
if the sources say so, else null.
- Choose the layout that best fits the content unless one is requested."""


def _isolate_json(raw: str) -> str:
    """Trim narration around a JSON object (gpt-oss sometimes talks around it)."""
    raw = (raw or "").strip()
    start, end = raw.find("{"), raw.rfind("}")
    if start != -1 and end > start:
        return raw[start:end + 1]
    return raw


def _s(value, limit: int) -> str:
    """Stringify + trim + truncate a model-provided scalar."""
    if value is None:
        return ""
    return str(value).strip()[:limit]


def _icon(value, default: str = "sparkles") -> str:
    v = str(value or "").strip()
    return v if v in _INFO_ICONS else default


def _pct(value) -> int | None:
    if isinstance(value, bool) or value is None:
        return None
    try:
        n = int(round(float(value)))
    except (TypeError, ValueError):
        return None
    return min(max(n, 0), 100)


def validate_infographic(data: dict, collection_name: str) -> dict:
    """Strictly validate/truncate a model-produced infographic v2 spec.

    Pure (no I/O) so it can be unit-tested with fixture JSON. Raises ValueError
    when the layout is missing or the matching section has no usable rows.
    """
    if not isinstance(data, dict):
        raise ValueError("infographic generation returned a non-object")
    layout = data.get("layout")
    if layout not in _INFO_LAYOUTS:
        raise ValueError("infographic generation returned no valid layout")

    theme = str(data.get("theme") or "").strip()
    content: dict = {
        "title": _s(data.get("title"), 48) or collection_name[:48],
        "subtitle": _s(data.get("subtitle"), 90),
        "layout": layout,
        "theme": theme if theme in _INFO_THEMES else "plum",
        "icon": _icon(data.get("icon")),
        "hero": None,
        "takeaway": _s(data.get("takeaway"), 110),
    }
    hero = data.get("hero")
    if isinstance(hero, dict) and _s(hero.get("value"), 12):
        content["hero"] = {"value": _s(hero.get("value"), 12), "label": _s(hero.get("label"), 40)}

    if layout == "numbers":
        rows = [
            {
                "value": _s(r.get("value"), 12),
                "label": _s(r.get("label"), 40),
                "icon": _icon(r.get("icon"), content["icon"]),
                "pct": _pct(r.get("pct")),
            }
            for r in (data.get("numbers") or []) if isinstance(r, dict) and _s(r.get("value"), 12)
        ]
        if not rows:
            raise ValueError("infographic numbers layout returned no items")
        content["numbers"] = rows[:6]
    elif layout == "timeline":
        rows = [
            {
                "when": _s(r.get("when"), 12),
                "what": _s(r.get("what"), 64),
                "icon": _icon(r.get("icon"), content["icon"]),
            }
            for r in (data.get("timeline") or []) if isinstance(r, dict) and _s(r.get("what"), 64)
        ]
        if not rows:
            raise ValueError("infographic timeline layout returned no items")
        content["timeline"] = rows[:6]
    else:  # comparison
        comp = data.get("comparison") or {}
        if not isinstance(comp, dict):
            comp = {}
        rows = []
        for r in comp.get("rows") or []:
            if not isinstance(r, dict) or not _s(r.get("aspect"), 24):
                continue
            edge = r.get("edge")
            rows.append({
                "aspect": _s(r.get("aspect"), 24),
                "a": _s(r.get("a"), 36),
                "b": _s(r.get("b"), 36),
                "edge": edge if edge in ("a", "b") else None,
            })
        if not rows:
            raise ValueError("infographic comparison layout returned no rows")
        content["comparison"] = {
            "a": _s(comp.get("a"), 22) or "A",
            "b": _s(comp.get("b"), 22) or "B",
            "rows": rows[:5],
        }
    return content


async def generate_infographic(
    collection_name: str,
    context: str,
    kind: str = "auto",
    instructions: str | None = None,
) -> ArtifactResult:
    """Extract a grounded, structured infographic (v2) spec from a collection's sources.

    Rendered natively on-device (crisp text/numbers) rather than as an AI image.
    `kind` ∈ {auto, numbers, timeline, comparison}; `instructions` is optional
    user free text (≤ 300 chars) appended to the request.
    """
    model = settings.fireworks_text_model
    layout_hint = (
        f"Use the \"{kind}\" layout."
        if kind in _INFO_LAYOUTS
        else "Pick the layout that best fits the content."
    )
    user = f"Collection: {collection_name}\n\nSOURCES:\n{context}\n\n{layout_hint}\n"
    instructions = (instructions or "").strip()[:300]
    if instructions:
        user += f"User instructions: {instructions}\n"
    user += "Produce the infographic JSON."
    resp = await _fireworks.chat.completions.create(
        model=model,
        messages=[{"role": "system", "content": _INFOGRAPHIC_SYSTEM}, {"role": "user", "content": user}],
        max_tokens=1600,
        temperature=0.3,
    )
    inp, out = _fw_usage(resp)
    raw = _isolate_json(resp.choices[0].message.content or "")
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        raise ValueError("infographic generation returned invalid JSON")

    content = validate_infographic(data, collection_name)
    return ArtifactResult(
        kind="info",
        title=content["title"][:300],
        content=content,
        model=model,
        input_tokens=inp,
        output_tokens=out,
    )


# ── Audio overview (solo narrator) ─────────────────────────────────────────

_AUDIO_VOICES = {"thalia", "orion", "asteria", "arcas"}
_AUDIO_LENGTH_WORDS = {"short": 250, "standard": 450, "long": 700}
_DEEPGRAM_CHUNK_CHARS = 1800  # Deepgram Speak caps text at 2000 chars/request

_AUDIO_SYSTEM = """\
You write the script for a short spoken audio overview of a collection of saved \
sources, read by a single warm, conversational narrator. Rules:
- Ground EVERYTHING in the provided sources only. Never invent facts.
- Plain spoken prose: no markdown, no headers, no bullet symbols, no stage \
directions, no "[Source N]" tokens, no URLs. Write numbers so they read aloud \
well (say "about two thirds" or "nineteen ninety-eight", not "2/3" or "1998").
- Open with one line naming the collection. Walk through the three to five most \
important ideas across the sources. Note where the sources disagree. End with \
a one-sentence takeaway.
- Short sentences; contractions are fine. Sound like a smart friend, not a \
newsreader.
Return ONLY a JSON object (no prose, no markdown fence) of this shape:
{"title": "<= 60 chars", "script": "the full narration as one string"}"""


def split_for_tts(text: str, limit: int = _DEEPGRAM_CHUNK_CHARS) -> list[str]:
    """Split narration into ≤ `limit`-char chunks on sentence boundaries."""
    import re

    sentences = [s.strip() for s in re.split(r"(?<=[.!?])\s+", text.strip()) if s.strip()]
    chunks: list[str] = []
    cur = ""
    for sent in sentences:
        # A single pathological sentence longer than the limit is hard-wrapped.
        while len(sent) > limit:
            if cur:
                chunks.append(cur)
                cur = ""
            cut = sent.rfind(" ", 0, limit)
            cut = cut if cut > 0 else limit
            chunks.append(sent[:cut].strip())
            sent = sent[cut:].strip()
        if not cur:
            cur = sent
        elif len(cur) + 1 + len(sent) <= limit:
            cur = f"{cur} {sent}"
        else:
            chunks.append(cur)
            cur = sent
    if cur:
        chunks.append(cur)
    return chunks


def _parse_audio_output(raw_text: str, collection_name: str) -> tuple[str, str]:
    """{"title","script"} → (title, script). Lenient: scripts are multi-paragraph and
    gpt-oss emits literal newlines inside the JSON string (strict JSON forbids them);
    if the JSON still won't parse, the plain text is the script."""
    import re

    raw = _isolate_json(raw_text)
    data = None
    try:
        data = json.loads(raw, strict=False)
    except json.JSONDecodeError:
        pass
    if isinstance(data, dict):
        script = str(data.get("script") or "").strip()
        title = _s(data.get("title"), 60)
    else:
        text = raw_text.strip()
        if text.startswith("{"):
            # Looks like JSON but didn't parse: pull the script string out by hand.
            m = re.search(r'"script"\s*:\s*"(.*)"\s*}?\s*$', text, re.S)
            script = (m.group(1) if m else "").replace('\\"', '"').replace("\\n", "\n").strip()
            t = re.search(r'"title"\s*:\s*"([^"]{1,60})"', text)
            title = t.group(1).strip() if t else ""
        else:
            script, title = text, ""
    # Spoken prose only — strip any markdown/citation residue the model left in.
    script = re.sub(r"\[Source \d+\]", "", script)
    script = re.sub(r"^[#*\-\s]+", "", script, flags=re.M)
    script = re.sub(r"\*\*", "", script)
    script = re.sub(r"[ \t]+", " ", script).strip()
    if len(script.split()) < 20:
        raise ValueError("audio script generation returned no usable script")
    return (title or f"Audio overview — {collection_name}"[:60], script)


def _deepgram_tts_sync(text: str, model: str) -> bytes:
    from deepgram import DeepgramClient

    api_key = os.environ.get("DEEPGRAM_API_KEY", "")
    if not api_key:
        raise RuntimeError("audio generation not configured (DEEPGRAM_API_KEY)")
    client = DeepgramClient(api_key=api_key)
    try:
        return b"".join(client.speak.v1.audio.generate(text=text, model=model, encoding="mp3"))
    except Exception as exc:  # surface auth problems explicitly
        msg = str(exc)
        status_code = getattr(exc, "status_code", None)
        if status_code == 401 or "INVALID_AUTH" in msg or "401" in msg:
            raise RuntimeError(f"deepgram auth failed (401 INVALID_AUTH): {msg[:200]}") from exc
        raise


async def synthesize_speech(script: str, voice: str) -> tuple[bytes, str]:
    """TTS the whole script via Deepgram Aura-2, chunked; returns (mp3_bytes, model)."""
    model = f"aura-2-{voice}-en"
    chunks = split_for_tts(script)
    if not chunks:
        raise ValueError("audio script is empty")
    parts: list[bytes] = []
    for chunk in chunks:  # sequential keeps order + stays under rate limits
        parts.append(await asyncio.to_thread(_deepgram_tts_sync, chunk, model))
    audio = b"".join(parts)
    if not audio:
        raise ValueError("deepgram returned no audio")
    return audio, model


async def generate_audio(
    collection_name: str,
    context: str,
    artifact_id: str,
    voice: str = "thalia",
    length: str = "standard",
) -> ArtifactResult:
    """Script (Fireworks) → TTS (Deepgram Aura-2) → upload to Supabase `media`."""
    from app.core.storage import upload_public

    text_model = settings.fireworks_text_model
    voice = voice if voice in _AUDIO_VOICES else "thalia"
    target_words = _AUDIO_LENGTH_WORDS.get(length, _AUDIO_LENGTH_WORDS["standard"])
    user = (
        f"Collection: {collection_name}\n\nSOURCES:\n{context}\n\n"
        f"Target length — about {target_words} words.\nWrite the narration JSON now."
    )
    resp = await _fireworks.chat.completions.create(
        model=text_model,
        messages=[{"role": "system", "content": _AUDIO_SYSTEM}, {"role": "user", "content": user}],
        max_tokens=int(target_words * 2.2) + 1200,  # headroom for gpt-oss reasoning
        temperature=0.6,
    )
    inp, out = _fw_usage(resp)
    title, script = _parse_audio_output(resp.choices[0].message.content or "", collection_name)

    audio, tts_model = await synthesize_speech(script, voice)
    url = await upload_public(f"audio/{artifact_id}.mp3", audio, "audio/mpeg")

    words = len(script.split())
    return ArtifactResult(
        kind="audio",
        title=title,
        content={
            "audio_url": url,
            "duration_s": int(round(words / 2.6)),
            "script": script,
            "voice": voice,
            "words": words,
        },
        model=f"{text_model}+{tts_model}",
        input_tokens=inp,
        output_tokens=out,
    )


# ── Poster (AI image + native text overlay) ────────────────────────────────

_POSTER_STYLES = {
    "editorial": "flat geometric editorial illustration, muted sophisticated palette, clean vector shapes",
    "abstract": "abstract composition of soft shapes and smooth gradients, no recognizable objects",
    "photo": "cinematic photographic still, shallow depth of field, natural light, film grain",
    "illustration": "hand-drawn textured illustration, visible brush and pencil texture, warm paper grain",
}
_POSTER_SYSTEM = """\
You art-direct a poster for a collection of saved sources. Return ONLY a JSON \
object (no prose, no markdown fence) of this exact shape:
{"headline": "<= 42 chars", "subline": "<= 90 chars", "image_prompt": "..."}
Rules:
- headline: punchy, specific, grounded in what the sources actually say — never \
generic. subline: one grounded line of context.
- image_prompt: describe a striking, minimal, premium poster illustration that \
embodies the collection's subject. ONE dominant subject. Generous empty negative \
space in the lower third of the frame (text is overlaid there). Restrained \
palette of two or three colours. Explicitly include: "no text, no letters, no \
words, no watermark, no logos". Describe lighting, composition and mood \
concretely. 40-90 words.
- Never fabricate facts for the headline or subline."""
FAL_FLUX_SCHNELL_URL = "https://fal.run/fal-ai/flux/schnell"
FAL_IMAGE_MODEL = "fal-ai/flux/schnell"


def build_fal_request(prompt: str) -> tuple[str, dict, dict]:
    """(url, headers, json_body) for a fal.ai flux/schnell call — pure, for tests."""
    fal_key = os.environ.get("FAL_KEY") or settings.fal_key
    if not fal_key:
        raise RuntimeError("poster generation not configured (FAL_KEY)")
    return (
        FAL_FLUX_SCHNELL_URL,
        {"Authorization": f"Key {fal_key}", "Content-Type": "application/json"},
        {
            "prompt": prompt,
            "image_size": "portrait_4_3",
            "num_inference_steps": 4,
            "num_images": 1,
            "enable_safety_checker": True,
            "output_format": "jpeg",
        },
    )


async def generate_poster_brief(
    collection_name: str,
    context: str,
    style: str = "editorial",
    instructions: str | None = None,
) -> tuple[dict, int, int]:
    """Fireworks half of poster generation: {headline, subline, image_prompt, style}."""
    text_model = settings.fireworks_text_model
    style = style if style in _POSTER_STYLES else "editorial"
    user = (
        f"Collection: {collection_name}\n\nSOURCES:\n{context}\n\n"
        f"Visual style — {_POSTER_STYLES[style]}.\n"
    )
    instructions = (instructions or "").strip()[:300]
    if instructions:
        user += f"User instructions (apply to the image prompt verbatim): {instructions}\n"
    user += "Return the poster JSON now."
    resp = await _fireworks.chat.completions.create(
        model=text_model,
        messages=[{"role": "system", "content": _POSTER_SYSTEM}, {"role": "user", "content": user}],
        # gpt-oss-120b reasons before answering; a small budget returns empty content.
        max_tokens=2000,
        temperature=0.7,
    )
    inp, out = _fw_usage(resp)
    raw = _isolate_json(resp.choices[0].message.content or "")
    if not raw:
        raise ValueError("poster brief generation returned empty content")
    try:
        data = json.loads(raw, strict=False)
    except json.JSONDecodeError:
        raise ValueError("poster brief generation returned invalid JSON")
    if not isinstance(data, dict):
        raise ValueError("poster brief generation returned a non-object")
    headline = _s(data.get("headline"), 42)
    image_prompt = str(data.get("image_prompt") or "").strip()
    if not headline or not image_prompt:
        raise ValueError("poster brief generation returned no headline/prompt")
    # Belt and braces: the style + no-text guard must be in the final prompt.
    prompt = f"{image_prompt} {_POSTER_STYLES[style]}. No text, no letters, no words, no watermark, no logos."
    if instructions:
        prompt += f" {instructions}"
    return (
        {"headline": headline, "subline": _s(data.get("subline"), 90), "prompt": prompt, "style": style},
        inp,
        out,
    )


async def generate_poster(
    collection_name: str,
    context: str,
    artifact_id: str,
    style: str = "editorial",
    instructions: str | None = None,
) -> ArtifactResult:
    """Brief (Fireworks) → image (fal.ai flux/schnell) → re-upload to Supabase `media`."""
    import httpx

    from app.core.storage import upload_public

    # Fail fast before spending Fireworks tokens if the image provider is unset.
    if not (os.environ.get("FAL_KEY") or settings.fal_key):
        raise RuntimeError("poster generation not configured (FAL_KEY)")

    brief, inp, out = await generate_poster_brief(collection_name, context, style, instructions)
    url, headers, body = build_fal_request(brief["prompt"])
    async with httpx.AsyncClient(timeout=120) as client:
        resp = await client.post(url, headers=headers, json=body)
        if resp.status_code < 200 or resp.status_code >= 300:
            raise RuntimeError(f"fal image generation failed {resp.status_code}: {resp.text[:300]}")
        images = (resp.json() or {}).get("images") or []
        if not images or not images[0].get("url"):
            raise ValueError("fal image generation returned no image")
        img = images[0]
        img_resp = await client.get(img["url"])
        if img_resp.status_code != 200 or not img_resp.content:
            raise RuntimeError(f"fal image download failed {img_resp.status_code}")
        image_bytes = img_resp.content

    public_url = await upload_public(f"posters/{artifact_id}.jpg", image_bytes, "image/jpeg")
    return ArtifactResult(
        kind="poster",
        title=brief["headline"],
        content={
            "image_url": public_url,
            "headline": brief["headline"],
            "subline": brief["subline"],
            "prompt": brief["prompt"],
            "style": brief["style"],
            "width": int(img.get("width") or 0),
            "height": int(img.get("height") or 0),
        },
        model=f"{settings.fireworks_text_model}+{FAL_IMAGE_MODEL}",
        input_tokens=inp,
        output_tokens=out,
    )


async def _run_examples_async() -> None:
    examples = [
        ("article", ARTICLE),
        ("youtube", YOUTUBE),
        ("podcast", PODCAST),
    ]

    for content_type, content in examples:
        print(f"\n{'='*60}")
        print(f"  {content_type.upper()}")
        print("=" * 60)

        result = await summarize_item(content, content_type)
        embedding = await compute_embedding(content)

        print(f"\nTL;DR:\n  {result.tldr}")
        print("\nKey Insights:")
        for insight in result.insights:
            print(f"  • {insight}")
        print(f"\nTags: {', '.join(result.tags)}")
        print(f"\nEmbedding: {embedding.dimensions}-dim {embedding.model}")
        print(f"  Vector[:5]: {[round(v, 6) for v in embedding.vector[:5]]}")


def run_examples() -> None:
    """Entry point for CLI smoke-test. Runs all async pipeline functions correctly."""
    asyncio.run(_run_examples_async())


if __name__ == "__main__":
    run_examples()
