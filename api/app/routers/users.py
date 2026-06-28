"""
User profile endpoints.

GET /v1/users/me/interest-topics — return the current user's top interest
topics from their UserInterestProfile, sorted by weight descending.

Used by the iOS FRE rotating-word UI to replace hardcoded topic strings
with personalised suggestions drawn from real usage history (SPEC §9a
Pillar 4 — Semantic Memory).

Response contract (iOS expects exactly this shape):
  {
    "topics": ["machine learning", "second-brain tools", "longevity"],
    "has_profile": true
  }

- topics is ordered by interest weight descending, capped at `limit` (default 5).
- If the user has no profile yet (no saved content), has_profile=false and
  topics contains the hard-coded FRE defaults so the UI always has words to rotate.
- All topic keys stored in the DB are snake_case / hyphenated (e.g. "machine-learning").
  This endpoint returns them title-cased with hyphens replaced by spaces for display.
"""

import logging

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.middleware.auth import get_current_user
from app.models.user import User
from app.models.user_interest_profile import UserInterestProfile

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/users", tags=["users"])

# Fallback topics shown on first launch (no saved content yet).
# Must match the original freTopics in ResearchFlowView.swift so the
# initial experience is unchanged for brand-new users.
_FRE_DEFAULT_TOPICS: list[str] = [
    "the US–Iran conflict",
    "second-brain tools",
    "how memory works",
    "the AI platform shift",
    "anything you're curious about",
]

_DEFAULT_LIMIT = 5
_MAX_LIMIT = 20


def _format_topic(raw: str) -> str:
    """
    Convert a stored topic key into a display string.

    Stored keys arrive from the tagger as lower-case hyphenated strings
    (e.g. "machine-learning", "second-brain-tools").  Replace hyphens
    with spaces so they read naturally in the FRE headline.
    """
    return raw.replace("-", " ").replace("_", " ")


class InterestTopicsResponse(BaseModel):
    topics: list[str]
    has_profile: bool


async def _resolve_interest_topics(
    supabase_id: str,
    limit: int,
    db: AsyncSession,
) -> InterestTopicsResponse:
    """
    Core logic for GET /me/interest-topics — extracted for unit testability.

    1. Resolve the supabase_id to an internal User row.
    2. Load that user's UserInterestProfile.
    3. Return personalised topics (sorted by weight desc) or defaults.
    """
    # Resolve internal user id from Supabase JWT claim
    result = await db.execute(
        select(User).where(User.supabase_id == supabase_id)
    )
    user = result.scalar_one_or_none()

    if user is None:
        # User exists in Supabase but not yet provisioned — return defaults
        logger.warning(
            "interest-topics: user supabase_id=%s not found in DB; returning defaults",
            supabase_id,
        )
        return InterestTopicsResponse(topics=_FRE_DEFAULT_TOPICS[:limit], has_profile=False)

    # Fetch interest profile
    profile_result = await db.execute(
        select(UserInterestProfile).where(UserInterestProfile.user_id == user.id)
    )
    profile = profile_result.scalar_one_or_none()

    if profile is None or not profile.topics:
        return InterestTopicsResponse(topics=_FRE_DEFAULT_TOPICS[:limit], has_profile=False)

    # Sort topics by weight descending, take top `limit`, format for display
    sorted_topics = sorted(profile.topics.items(), key=lambda kv: kv[1], reverse=True)
    display_topics = [_format_topic(key) for key, _ in sorted_topics[:limit]]

    # Guard: if all topics were empty strings after formatting, fall back
    display_topics = [t for t in display_topics if t.strip()]
    if not display_topics:
        return InterestTopicsResponse(topics=_FRE_DEFAULT_TOPICS[:limit], has_profile=False)

    return InterestTopicsResponse(topics=display_topics, has_profile=True)


@router.get(
    "/me/interest-topics",
    response_model=InterestTopicsResponse,
    summary="Top interest topics for the FRE rotating word",
    description=(
        "Returns the authenticated user's top interest topics sorted by "
        "weight descending.  Falls back to curated defaults when the user "
        "has no saved content yet so the FRE always has words to rotate."
    ),
)
async def get_interest_topics(
    limit: int = Query(default=_DEFAULT_LIMIT, ge=1, le=_MAX_LIMIT),
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> InterestTopicsResponse:
    """GET /v1/users/me/interest-topics?limit=5"""
    return await _resolve_interest_topics(
        supabase_id=current_user["supabase_id"],
        limit=limit,
        db=db,
    )
