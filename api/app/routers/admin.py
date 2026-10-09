"""
Admin error monitor — /v1/admin/errors/*

Guarded by a shared secret (X-Admin-Token header == settings.admin_token). Not
tied to user auth: the GitHub Action alert cron and ad-hoc curl checks hit this
without a JWT. If ADMIN_TOKEN is unset, every endpoint returns 503 (closed by
default — never open).

The alert cron polls /summary and fails its job (→ GitHub emails Srihari) when
the recent error count crosses a threshold.
"""

import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.models.error_event import ErrorEvent

router = APIRouter(prefix="/admin", tags=["admin"])


async def _require_admin(x_admin_token: str | None = Header(default=None)) -> None:
    if not settings.admin_token:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Admin monitor not configured (ADMIN_TOKEN unset).",
        )
    if x_admin_token != settings.admin_token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Bad admin token")


@router.get("/errors/summary", dependencies=[Depends(_require_admin)])
async def errors_summary(
    hours: int = Query(default=24, ge=1, le=168),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Error counts over the last `hours`, grouped by level and by source."""
    since = datetime.now(timezone.utc) - timedelta(hours=hours)

    total = (
        await db.execute(select(func.count()).select_from(ErrorEvent).where(ErrorEvent.created_at >= since))
    ).scalar_one()

    by_level = (
        await db.execute(
            select(ErrorEvent.level, func.count())
            .where(ErrorEvent.created_at >= since)
            .group_by(ErrorEvent.level)
        )
    ).all()

    by_source = (
        await db.execute(
            select(ErrorEvent.source, func.count())
            .where(ErrorEvent.created_at >= since)
            .group_by(ErrorEvent.source)
            .order_by(func.count().desc())
        )
    ).all()

    # Ingestion queue health — a wedged worker never raises, so error counts
    # alone can't see it (it hid for 7 weeks, 2026-08-22 → 10-09). Expose the
    # backlog + the age of the oldest queued job; the alert cron fails on
    # staleness.
    queue = (
        await db.execute(text(
            """
            SELECT count(*) AS queued,
                   COALESCE(EXTRACT(EPOCH FROM (now() - min(created))), 0)::int AS oldest_age_s
            FROM pgqueuer WHERE status = 'queued'
            """
        ))
    ).one()
    picked_recent = (
        await db.execute(text(
            "SELECT count(*) FROM pgqueuer_log WHERE status = 'successful' AND created > now() - interval '24 hours'"
        ))
    ).scalar_one()

    return {
        "window_hours": hours,
        "since": since.isoformat(),
        "total": total,
        "errors": sum(c for lvl, c in by_level if lvl == "error"),
        "warnings": sum(c for lvl, c in by_level if lvl == "warning"),
        "by_level": {lvl: c for lvl, c in by_level},
        "by_source": [{"source": s, "count": c} for s, c in by_source],
        "queue": {
            "queued": int(queue.queued),
            "oldest_queued_age_s": int(queue.oldest_age_s),
            "processed_24h": int(picked_recent),
        },
    }


@router.get("/errors", dependencies=[Depends(_require_admin)])
async def list_errors(
    hours: int = Query(default=24, ge=1, le=168),
    limit: int = Query(default=50, ge=1, le=500),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """Most recent error rows (newest first) within the window."""
    since = datetime.now(timezone.utc) - timedelta(hours=hours)
    rows = (
        await db.execute(
            select(ErrorEvent)
            .where(ErrorEvent.created_at >= since)
            .order_by(ErrorEvent.created_at.desc())
            .limit(limit)
        )
    ).scalars().all()
    return [
        {
            "id": str(e.id),
            "created_at": e.created_at.isoformat() if e.created_at else None,
            "level": e.level,
            "source": e.source,
            "status_code": e.status_code,
            "error_type": e.error_type,
            "message": e.message,
            "path": e.path,
            "method": e.method,
            "correlation_id": e.correlation_id,
            "user_id": str(e.user_id) if e.user_id else None,
        }
        for e in rows
    ]
