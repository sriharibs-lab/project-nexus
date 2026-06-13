"""
Nexus AI Processing Pipeline
Summarization + semantic tagging via Claude Haiku 4.5.
Embeddings via OpenAI text-embedding-3-small.
"""

import asyncio
import json
import os
from dataclasses import dataclass, field
from decimal import Decimal
from typing import Literal
from pathlib import Path

from dotenv import load_dotenv
import anthropic
from openai import AsyncOpenAI

load_dotenv(Path(__file__).parent.parent / ".env")

_anthropic = anthropic.AsyncAnthropic(api_key=os.environ.get("ANTHROPIC_API_KEY", ""))
_openai = AsyncOpenAI(api_key=os.environ.get("OPENAI_API_KEY", ""))

ContentType = Literal["article", "youtube", "podcast", "video", "thread", "blog", "announcement", "other"]

# Claude Haiku 4.5 pricing (per token)
_HAIKU_INPUT_COST = Decimal("0.0000008")   # $0.80 / 1M
_HAIKU_OUTPUT_COST = Decimal("0.000004")   # $4.00 / 1M
_EMBED_COST = Decimal("0.00000002")        # $0.020 / 1M (text-embedding-3-small)

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
class EmbeddingResult:
    """pgvector-ready: 1536-dim float32 vector."""
    vector: list[float]
    dimensions: int
    model: str
    input_tokens: int = 0
    cost_usd: Decimal = field(default_factory=lambda: Decimal("0"))


async def summarize_item(content: str, content_type: ContentType) -> ProcessedItem:
    response = await _anthropic.messages.create(
        model="claude-haiku-4-5",
        max_tokens=512,
        system=SYSTEM_PROMPT,
        messages=[
            {
                "role": "user",
                "content": USER_TEMPLATE.format(
                    content_type=content_type,
                    content=content[:8000],
                ),
            }
        ],
    )

    raw = next(b.text for b in response.content if b.type == "text")

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


async def compute_embedding(content: str) -> EmbeddingResult:
    response = await _openai.embeddings.create(
        input=content[:8000],
        model="text-embedding-3-small",
    )
    vector = response.data[0].embedding
    tokens = response.usage.total_tokens
    cost = Decimal(tokens) * _EMBED_COST
    return EmbeddingResult(
        vector=vector,
        dimensions=len(vector),
        model="text-embedding-3-small",
        input_tokens=tokens,
        cost_usd=cost,
    )


# ---------------------------------------------------------------------------
# CLI runner
# ---------------------------------------------------------------------------

ARTICLE = """\
Sam Altman published a blog post outlining OpenAI's roadmap toward AGI. He describes \
a five-step framework: Chatbots → Reasoners → Agents → Innovators → Organizations. \
OpenAI claims GPT-4 is at level 1 and o1 is approaching level 2. Altman argues that \
level 3 (agents doing the work of a skilled employee autonomously) will arrive within \
years, not decades."""


async def _run_examples() -> None:
    examples = [("article", ARTICLE)]
    for content_type, content in examples:
        print(f"\n{'='*60}\n  {content_type.upper()}\n{'='*60}")
        result = await summarize_item(content, content_type)
        emb = await compute_embedding(content)
        print(f"\nTL;DR:\n  {result.tldr}")
        print("\nKey Insights:")
        for insight in result.insights:
            print(f"  • {insight}")
        print(f"\nTags: {', '.join(result.tags)}")
        print(f"Tokens: {result.input_tokens}in / {result.output_tokens}out  Cost: ${result.cost_usd:.6f}")
        print(f"\nEmbedding: {emb.dimensions}-dim {emb.model}  Cost: ${emb.cost_usd:.6f}")


if __name__ == "__main__":
    asyncio.run(_run_examples())
