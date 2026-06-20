"""
Search router — GET /v1/search

Implements hybrid full-text + semantic search across a user's saved items.

Strategy:
  1. Full-text search (FTS) using PostgreSQL tsvector/tsquery on title + summary.
     Fast, zero-latency, works even when Fireworks is unavailable.
  2. Semantic search using pgvector cosine similarity on the embeddings table.
     Requires FIREWORKS_API_KEY to generate a query embedding.
  3. Hybrid merge: normalize both scores to [0, 1] and combine with configurable
     weights (default: 30% FTS + 70% semantic). Items with no embedding get
     FTS-only score. Items with no FTS match get semantic-only score.

Result scoping: all searches are strictly scoped to the authenticated user.
No cross-user data is accessible regardless of query or item IDs.

Query params:
  q         — search query string (required, 1-200 chars)
  limit     — max results (default: settings.search_result_limit, max: 50)
  mode      — "hybrid" | "fts" | "semantic" (default: "hybrid")
              "fts" skips embedding generation; "semantic" skips FTS.

Response:
  {
    "query": "...",
    "mode": "hybrid" | "fts" | "semantic",
    "results": [
      {
        "item_id": "uuid",
        "title": "...",
        "url": "...",
        "summary": "...",
        "content_type": "article",
        "ingest_status": "completed",
        "tags": [...],
        "score": 0.87,
        "fts_rank": 0.6,      // null if mode=semantic
        "semantic_score": 0.9  // null if mode=fts
      },
      ...
    ],
    "total": 5,
    "embedding_available": true
  }

Latency target: < 300ms for FTS-only; < 800ms for hybrid (includes embedding call).
"""

from __future__ import annotations

import logging
from enum import Enum
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import select, text  # noqa: F401 — select used in _resolve_user
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.middleware.auth import get_current_user
from app.models.user import User

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/search", tags=["search"])


# ── Enums & Schemas ───────────────────────────────────────────────────────────


class SearchMode(str, Enum):
    hybrid = "hybrid"
    fts = "fts"
    semantic = "semantic"


class SearchResultItem(BaseModel):
    item_id: UUID
    title: str | None
    url: str
    summary: str | None
    content_type: str
    ingest_status: str
    tags: list[str]
    score: float
    fts_rank: float | None = None
    semantic_score: float | None = None

    model_config = {"from_attributes": True}


class SearchResponse(BaseModel):
    query: str
    mode: SearchMode
    results: list[SearchResultItem]
    total: int
    embedding_available: bool


# ── SQL Queries ───────────────────────────────────────────────────────────────

# FTS query: plainto_tsquery is safer than to_tsquery for user input (no
# special operator injection). Ranks by ts_rank_cd which weighs cover density.
# Includes ingest_status filter so we only return items with actual content.
_FTS_QUERY = text("""
    WITH fts AS (
        SELECT
            i.id            AS item_id,
            i.title         AS title,
            i.url           AS url,
            i.summary       AS summary,
            i.content_type  AS content_type,
            i.ingest_status AS ingest_status,
            ts_rank_cd(
                to_tsvector('english', COALESCE(i.title, '') || ' ' || COALESCE(i.summary, '')),
                plainto_tsquery('english', :query)
            )               AS fts_rank
        FROM items i
        WHERE i.user_id = :user_id
          AND i.ingest_status = 'completed'
          AND to_tsvector('english', COALESCE(i.title, '') || ' ' || COALESCE(i.summary, ''))
              @@ plainto_tsquery('english', :query)
        ORDER BY fts_rank DESC
        LIMIT :top_k
    )
    SELECT fts.*, ARRAY(
        SELECT t.name
        FROM tags t
        JOIN item_tags it ON it.tag_id = t.id
        WHERE it.item_id = fts.item_id
    ) AS tags
    FROM fts
    ORDER BY fts_rank DESC
""")

_SEMANTIC_QUERY = text("""
    WITH sem AS (
        SELECT
            i.id            AS item_id,
            i.title         AS title,
            i.url           AS url,
            i.summary       AS summary,
            i.content_type  AS content_type,
            i.ingest_status AS ingest_status,
            1 - (e.embedding <=> CAST(:query_vector AS vector)) AS semantic_score
        FROM embeddings e
        JOIN items i ON i.id = e.item_id
        WHERE i.user_id       = :user_id
          AND i.ingest_status = 'completed'
        ORDER BY e.embedding <=> CAST(:query_vector AS vector)
        LIMIT :top_k
    )
    SELECT sem.*, ARRAY(
        SELECT t.name
        FROM tags t
        JOIN item_tags it ON it.tag_id = t.id
        WHERE it.item_id = sem.item_id
    ) AS tags
    FROM sem
    ORDER BY semantic_score DESC
""")


# ── Helpers ───────────────────────────────────────────────────────────────────


def _normalize(scores: list[float]) -> list[float]:
    """Min-max normalize a list of scores to [0, 1]."""
    if not scores:
        return scores
    mn, mx = min(scores), max(scores)
    if mx == mn:
        return [1.0 for _ in scores]
    return [(s - mn) / (mx - mn) for s in scores]


async def _embed_query(query: str) -> list[float]:
    """Generate a query embedding via Fireworks nomic-embed-text-v1.5."""
    from ai.pipeline import compute_embedding  # type: ignore[import]

    result = await compute_embedding(query)
    return result.vector


async def _resolve_user(supabase_id: str, db: AsyncSession) -> User:
    result = await db.execute(select(User).where(User.supabase_id == supabase_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user


# ── Route ─────────────────────────────────────────────────────────────────────


@router.get("", response_model=SearchResponse)
async def search_items(
    q: Annotated[str, Query(min_length=1, max_length=200, description="Search query")],
    mode: SearchMode = SearchMode.hybrid,
    limit: Annotated[int, Query(ge=1, le=50)] = settings.search_result_limit,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SearchResponse:
    """
    GET /v1/search?q=<query>&mode=hybrid&limit=20

    Hybrid full-text + semantic search across the user's saved items.
    Scoped strictly to authenticated user — no cross-user data accessible.
    """
    user = await _resolve_user(current_user["supabase_id"], db)
    user_id = str(user.id)
    top_k = settings.search_top_k

    # ── FTS leg ───────────────────────────────────────────────────────────────
    fts_rows: list[dict] = []
    if mode in (SearchMode.hybrid, SearchMode.fts):
        result = await db.execute(
            _FTS_QUERY,
            {"query": q, "user_id": user_id, "top_k": top_k},
        )
        fts_rows = [dict(r) for r in result.mappings().all()]
        logger.debug("FTS returned %d rows for query=%r user=%s", len(fts_rows), q, user_id)

    # ── Semantic leg ──────────────────────────────────────────────────────────
    semantic_rows: list[dict] = []
    embedding_available = False
    query_vector: list[float] | None = None

    if mode in (SearchMode.hybrid, SearchMode.semantic):
        if settings.embedding_configured:
            try:
                query_vector = await _embed_query(q)
                embedding_available = True
                vector_literal = "[" + ",".join(str(v) for v in query_vector) + "]"
                result = await db.execute(
                    _SEMANTIC_QUERY,
                    {"query_vector": vector_literal, "user_id": user_id, "top_k": top_k},
                )
                semantic_rows = [dict(r) for r in result.mappings().all()]
                logger.debug(
                    "Semantic returned %d rows for query=%r user=%s",
                    len(semantic_rows), q, user_id,
                )
            except Exception:
                logger.warning(
                    "Embedding call failed for query=%r — falling back to FTS-only", q
                )
                # Graceful degradation: if embedding fails, continue with FTS results
        else:
            logger.debug("Embedding not configured — skipping semantic leg")

    # ── Merge & rank ──────────────────────────────────────────────────────────

    # Build lookup maps keyed by item_id (string)
    fts_map: dict[str, dict] = {str(r["item_id"]): r for r in fts_rows}
    sem_map: dict[str, dict] = {str(r["item_id"]): r for r in semantic_rows}

    # Gather all unique item_ids
    all_ids = list(dict.fromkeys(list(fts_map) + list(sem_map)))

    # Normalize FTS ranks if present
    fts_rank_values = [float(fts_map[i]["fts_rank"]) for i in all_ids if i in fts_map]
    fts_norm = _normalize(fts_rank_values)
    fts_norm_map: dict[str, float] = {}
    fts_idx = 0
    for i in all_ids:
        if i in fts_map:
            fts_norm_map[i] = fts_norm[fts_idx]
            fts_idx += 1

    # Normalize semantic scores if present
    sem_score_values = [float(sem_map[i]["semantic_score"]) for i in all_ids if i in sem_map]
    sem_norm = _normalize(sem_score_values)
    sem_norm_map: dict[str, float] = {}
    sem_idx = 0
    for i in all_ids:
        if i in sem_map:
            sem_norm_map[i] = sem_norm[sem_idx]
            sem_idx += 1

    # Compute hybrid score
    merged: list[SearchResultItem] = []
    for item_id in all_ids:
        row = fts_map.get(item_id) or sem_map.get(item_id)
        if row is None:
            continue

        fts_score = fts_norm_map.get(item_id, 0.0)
        sem_score = sem_norm_map.get(item_id, 0.0)

        if mode == SearchMode.fts:
            combined = fts_score
        elif mode == SearchMode.semantic:
            combined = sem_score
        else:
            # Hybrid: weighted blend
            # If only one leg has this item, use that score at full weight
            if item_id in fts_map and item_id in sem_map:
                combined = (
                    settings.search_fts_weight * fts_score
                    + settings.search_semantic_weight * sem_score
                )
            elif item_id in fts_map:
                combined = fts_score
            else:
                combined = sem_score

        tags_raw = row.get("tags") or []
        # PostgreSQL ARRAY() returns a list; ensure it's a Python list of strings
        tags: list[str] = list(tags_raw) if tags_raw else []

        merged.append(
            SearchResultItem(
                item_id=row["item_id"],
                title=row.get("title"),
                url=row["url"],
                summary=row.get("summary"),
                content_type=row["content_type"],
                ingest_status=row["ingest_status"],
                tags=tags,
                score=round(combined, 4),
                fts_rank=round(float(fts_map[item_id]["fts_rank"]), 6) if item_id in fts_map else None,
                semantic_score=round(float(sem_map[item_id]["semantic_score"]), 6) if item_id in sem_map else None,
            )
        )

    # Sort by score descending and apply limit
    merged.sort(key=lambda r: r.score, reverse=True)
    merged = merged[:limit]

    return SearchResponse(
        query=q,
        mode=mode,
        results=merged,
        total=len(merged),
        embedding_available=embedding_available,
    )
