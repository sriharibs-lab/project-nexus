from __future__ import annotations

import uuid
from typing import Literal, Optional

from fastapi import APIRouter, Depends, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.users import get_or_create_user
from app.middleware.auth import get_current_user
from app.models.feedback import Feedback, FeedbackCategory

router = APIRouter(prefix="/feedback", tags=["feedback"])


class FeedbackRequest(BaseModel):
    text: str
    category: Literal["bug", "suggestion", "other"] = "other"
    screenshot_url: Optional[str] = None
    app_version: Optional[str] = None
    ios_version: Optional[str] = None
    device_model: Optional[str] = None


class FeedbackResponse(BaseModel):
    id: str
    status: str


@router.post("", status_code=status.HTTP_201_CREATED, response_model=FeedbackResponse)
async def submit_feedback(
    payload: FeedbackRequest,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user),
) -> FeedbackResponse:
    user = await get_or_create_user(
        db,
        supabase_id=current_user["supabase_id"],
        email=current_user.get("email"),
    )

    feedback = Feedback(
        id=uuid.uuid4(),
        user_id=user.id,
        text=payload.text,
        category=FeedbackCategory(payload.category),
        screenshot_url=payload.screenshot_url,
        app_version=payload.app_version,
        ios_version=payload.ios_version,
        device_model=payload.device_model,
    )
    db.add(feedback)
    await db.commit()

    return FeedbackResponse(id=str(feedback.id), status="received")
