"""
Daily Briefing endpoints.

POST /v1/briefing/generate  — generate a new briefing from the user's recent items.
GET  /v1/briefing/latest    — return the user's most recently generated briefing.
"""

import logging
import os
import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import desc, select

from ai.pipeline import generate_daily_briefing
from app.core.database import get_db
from app.core.rag import fetch_recent_items_for_briefing
from app.middleware.auth import get_current_user
from app.models.daily_briefing import DailyBriefing
from app.models.user import User
from app.models.user_interest_profile import UserInterestProfile

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/briefing", tags=["briefing"])


# ---------------------------------------------------------------------------
# Response schemas
# ---------------------------------------------------------------------------


class BriefingSectionOut(BaseModel):
    title: str
    bullets: list[str]


class BriefingOut(BaseModel):
    id: str
    headline: str
    sections: list[BriefingSectionOut]
    input_tokens: int
    output_tokens: int
    items_used: int
    created_at: datetime

    model_config = {"from_attributes": True}


class GenerateBriefingResponse(BaseModel):
    briefing: BriefingOut
    message: str


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def _resolve_user(supabase_id: str, db) -> User:
    """Resolve supabase_id to the internal User row. 404 if not found."""
    result = await db.execute(select(User).where(User.supabase_id == supabase_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user


def _briefing_to_out(briefing: DailyBriefing) -> BriefingOut:
    sections = [
        BriefingSectionOut(title=s["title"], bullets=s["bullets"])
        for s in briefing.sections
    ]
    return BriefingOut(
        id=str(briefing.id),
        headline=briefing.headline,
        sections=sections,
        input_tokens=briefing.input_tokens,
        output_tokens=briefing.output_tokens,
        items_used=briefing.items_used,
        created_at=briefing.created_at,
    )


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.post(
    "/generate",
    response_model=GenerateBriefingResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Generate a new daily briefing",
)
async def generate_briefing(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
) -> GenerateBriefingResponse:
    """
    Generate a new Daily Briefing from the user's most recent completed items
    and their interest profile. Persists the result as a DailyBriefing row.

    Returns:
        201 + BriefingOut on success.
        503 if ANTHROPIC_API_KEY is missing (AI unavailable).
        422 if the user has no completed items to brief on.
    """
    # Gate on API key before touching the DB
    if not os.environ.get("ANTHROPIC_API_KEY"):
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="AI service unavailable — ANTHROPIC_API_KEY not configured",
        )

    user = await _resolve_user(current_user["supabase_id"], db)

    # Fetch recent items (2 queries via selectinload, no N+1)
    items = await fetch_recent_items_for_briefing(db, user.id, limit=20)
    if not items:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="No completed items found — ingest some content before generating a briefing",
        )

    # Fetch interest weights (may not exist yet → empty dict is fine)
    # Main branch model uses `topics` column (not `weights`)
    profile_result = await db.execute(
        select(UserInterestProfile).where(UserInterestProfile.user_id == user.id)
    )
    profile = profile_result.scalar_one_or_none()
    interest_weights: dict[str, float] = dict(profile.topics) if profile else {}

    try:
        result = await generate_daily_briefing(items=items, interest_weights=interest_weights)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    except Exception as exc:
        logger.exception("generate_daily_briefing failed for user=%s", user.id)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Briefing generation failed — see server logs",
        ) from exc

    briefing = DailyBriefing(
        user_id=user.id,
        headline=result.headline,
        sections=[
            {"title": s.title, "bullets": s.bullets}
            for s in result.sections
        ],
        input_tokens=result.input_tokens,
        output_tokens=result.output_tokens,
        items_used=result.items_used,
    )
    db.add(briefing)
    await db.commit()
    await db.refresh(briefing)

    logger.info(
        "Generated briefing %s for user=%s items=%d tokens_in=%d tokens_out=%d",
        briefing.id,
        user.id,
        result.items_used,
        result.input_tokens,
        result.output_tokens,
    )

    return GenerateBriefingResponse(
        briefing=_briefing_to_out(briefing),
        message="Daily briefing generated successfully",
    )


@router.get(
    "/latest",
    response_model=BriefingOut,
    summary="Get the most recent daily briefing",
)
async def get_latest_briefing(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
) -> BriefingOut:
    """
    Return the most recently generated briefing for the authenticated user.

    Returns:
        200 + BriefingOut if one exists.
        404 if no briefing has been generated yet.
    """
    user = await _resolve_user(current_user["supabase_id"], db)

    result = await db.execute(
        select(DailyBriefing)
        .where(DailyBriefing.user_id == user.id)
        .order_by(desc(DailyBriefing.created_at))
        .limit(1)
    )
    briefing = result.scalar_one_or_none()

    if briefing is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No briefing found — generate one first via POST /v1/briefing/generate",
        )

    return _briefing_to_out(briefing)
