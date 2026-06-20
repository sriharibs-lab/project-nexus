"""
pgvector RAG helpers — shared by 1C-008 (chat) and 1C-006 (semantic search).

The read path: given a query embedding vector, return the top-K most similar
Item rows from within a specific Collection.

Uses cosine distance (<=>): smaller distance = more similar content.
The embeddings table has an HNSW index on the embedding column, so this query
is fast even at thousands of items per collection.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)

# SQL returns these fields for each matched chunk
_SIMILARITY_QUERY = text("""
    SELECT
        i.id            AS item_id,
        i.title         AS title,
        i.url           AS url,
        i.summary       AS summary,
        i.raw_content   AS raw_content,
        1 - (e.embedding <=> CAST(:query_vector AS vector)) AS similarity
    FROM embeddings e
    JOIN items i ON i.id = e.item_id
    JOIN collection_items ci ON ci.item_id = i.id
    WHERE ci.collection_id = :collection_id
      AND i.user_id        = :user_id
      AND i.ingest_status  = 'completed'
    ORDER BY e.embedding <=> CAST(:query_vector AS vector)
    LIMIT :top_k
""")


@dataclass
class RagChunk:
    item_id: UUID
    title: str | None
    url: str
    summary: str | None
    raw_content: str | None
    similarity: float


async def retrieve_similar_chunks(
    db: AsyncSession,
    *,
    collection_id: UUID,
    user_id: UUID,
    query_vector: list[float],
    top_k: int = 8,
) -> list[RagChunk]:
    """
    Return up to top_k items from the collection whose embeddings are closest
    to query_vector by cosine similarity.

    Filters to items owned by user_id to prevent cross-user data leakage even
    if collection_id is guessed.
    """
    # Format vector as Postgres literal: [f1,f2,...,fn]
    vector_literal = "[" + ",".join(str(v) for v in query_vector) + "]"

    result = await db.execute(
        _SIMILARITY_QUERY,
        {
            "query_vector": vector_literal,
            "collection_id": str(collection_id),
            "user_id": str(user_id),
            "top_k": top_k,
        },
    )
    rows = result.mappings().all()

    chunks = [
        RagChunk(
            item_id=row["item_id"],
            title=row["title"],
            url=row["url"],
            summary=row["summary"],
            raw_content=row["raw_content"],
            similarity=float(row["similarity"]),
        )
        for row in rows
    ]

    logger.debug(
        "RAG retrieved %d chunks for collection=%s query_vector_dim=%d",
        len(chunks),
        collection_id,
        len(query_vector),
    )
    return chunks


def build_context_block(chunks: list[RagChunk], max_chars: int = 16_000) -> str:
    """
    Render retrieved chunks into a single context string for the system prompt.

    Truncates to max_chars to keep within the model's context window budget.
    Prefers summary over raw_content. Raw_content is capped at 2000 chars
    to bound context window bloat (completed items must have a summary;
    raw_content fallback is a safety net only).
    Each chunk leads with its title + URL so the model can attribute sources.
    """
    parts: list[str] = []
    total = 0

    for i, chunk in enumerate(chunks, 1):
        header = f"[Source {i}] {chunk.title or 'Untitled'}\n{chunk.url}\n"
        if chunk.summary:
            body = chunk.summary
        elif chunk.raw_content:
            body = chunk.raw_content[:2000] + ("…" if len(chunk.raw_content) > 2000 else "")
        else:
            body = ""
        entry = f"{header}{body}\n\n"

        if total + len(entry) > max_chars:
            remaining = max_chars - total
            if remaining > len(header) + 100:
                parts.append(header + body[: remaining - len(header)] + "…\n\n")
            break

        parts.append(entry)
        total += len(entry)

    return "".join(parts)


# ---------------------------------------------------------------------------
# Daily Briefing fetch helper
# ---------------------------------------------------------------------------


async def fetch_recent_items_for_briefing(
    db,
    user_id,
    limit: int = 20,
) -> list:
    """
    Return the most recent `limit` completed items for `user_id` as
    BriefingItem objects ready for generate_daily_briefing().

    Uses selectinload to avoid N+1 queries on tags.
    Total = 2 queries regardless of item count.
    """
    from uuid import UUID
    from sqlalchemy import desc, select
    from sqlalchemy.orm import selectinload
    from ai.pipeline import BriefingItem
    from app.models.item import IngestStatus, Item

    stmt = (
        select(Item)
        .where(Item.user_id == user_id)
        .where(Item.ingest_status == IngestStatus.completed)
        .order_by(desc(Item.created_at))
        .limit(limit)
        .options(selectinload(Item.tags))
    )
    result = await db.execute(stmt)
    rows = result.scalars().all()

    return [
        BriefingItem(
            id=str(row.id),
            title=row.title,
            summary=row.summary,
            tags=[tag.slug for tag in row.tags],
        )
        for row in rows
    ]
