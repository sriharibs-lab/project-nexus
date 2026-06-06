"""
Nexus AI Processing Pipeline
Summarization + semantic tagging via Claude Haiku 4.5, embedding stub (pgvector-ready).
"""

import json
import os
import struct
import hashlib
from dataclasses import dataclass
from typing import Literal

import anthropic

client = anthropic.Anthropic(api_key=os.environ.get("ANTHROPIC_API_KEY"))

ContentType = Literal["article", "youtube", "podcast"]

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


@dataclass
class EmbeddingResult:
    """pgvector-ready: 1536-dim float32 vector stored as list[float]."""
    vector: list[float]
    dimensions: int
    model: str


def summarize_item(content: str, content_type: ContentType) -> ProcessedItem:
    """
    Summarize content and extract semantic tags.
    Returns TL;DR, 3-5 key insights, and semantic tags.
    """
    response = client.messages.create(
        model="claude-haiku-4-5",
        max_tokens=512,
        system=SYSTEM_PROMPT,
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
    return ProcessedItem(
        tldr=data["tldr"],
        insights=data["insights"],
        tags=data["tags"],
    )


def compute_embedding(content: str) -> EmbeddingResult:
    """
    Stub embedding — deterministic 1536-dim float32 vector.
    Replace body with a real embedding call (e.g. text-embedding-3-small)
    when the Anthropic embedding endpoint ships. Output is pgvector-compatible.
    """
    DIMS = 1536

    # deterministic hash-based stub so tests are reproducible
    seed = hashlib.sha256(content.encode()).digest()
    raw_bytes = (seed * (DIMS // 8 + 1))[:DIMS * 4]
    raw_floats = list(struct.unpack(f"{DIMS}f", raw_bytes))

    # normalize to unit sphere (pgvector cosine distance expects this)
    magnitude = sum(v * v for v in raw_floats) ** 0.5
    vector = [v / magnitude for v in raw_floats]

    return EmbeddingResult(
        vector=vector,
        dimensions=DIMS,
        model="stub-sha256-1536",
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


def run_examples():
    examples = [
        ("article", ARTICLE),
        ("youtube", YOUTUBE),
        ("podcast", PODCAST),
    ]

    for content_type, content in examples:
        print(f"\n{'='*60}")
        print(f"  {content_type.upper()}")
        print("=" * 60)

        result = summarize_item(content, content_type)
        embedding = compute_embedding(content)

        print(f"\nTL;DR:\n  {result.tldr}")
        print("\nKey Insights:")
        for insight in result.insights:
            print(f"  • {insight}")
        print(f"\nTags: {', '.join(result.tags)}")
        print(f"\nEmbedding: {embedding.dimensions}-dim {embedding.model}")
        print(f"  Vector[:5]: {[round(v, 6) for v in embedding.vector[:5]]}")


if __name__ == "__main__":
    run_examples()
