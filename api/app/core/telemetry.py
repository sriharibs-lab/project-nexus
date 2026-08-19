"""Production error telemetry — capture failures into error_events.

record_error() is deliberately best-effort: it opens its OWN short-lived DB
session and swallows every exception. It must be safe to call from anywhere,
including inside an SSE generator that has already started streaming (where a
raise would corrupt the response) and inside an exception handler (where a
second failure must not mask the first).
"""

import logging
import uuid
from typing import Any

from app.core.database import AsyncSessionLocal
from app.models.error_event import ErrorEvent

logger = logging.getLogger(__name__)

# Guard against unbounded rows from a hot failure loop (e.g. billing outage
# hammering research): the message column is Text but we cap what we store.
_MAX_MESSAGE_CHARS = 2000


async def record_error(
    *,
    source: str,
    message: str,
    level: str = "error",
    status_code: int | None = None,
    error_type: str | None = None,
    path: str | None = None,
    method: str | None = None,
    correlation_id: str | None = None,
    user_id: uuid.UUID | None = None,
    context: dict[str, Any] | None = None,
) -> None:
    """Persist one error_events row. Never raises."""
    try:
        async with AsyncSessionLocal() as db:
            db.add(
                ErrorEvent(
                    id=uuid.uuid4(),
                    level=level,
                    source=source[:100],
                    status_code=status_code,
                    error_type=(error_type or None) and error_type[:120],
                    message=(message or "")[:_MAX_MESSAGE_CHARS],
                    path=(path or None) and path[:300],
                    method=(method or None) and method[:10],
                    correlation_id=(correlation_id or None) and correlation_id[:64],
                    user_id=user_id,
                    context=context or None,
                )
            )
            await db.commit()
    except Exception:  # noqa: BLE001 — telemetry must never break the request path
        logger.exception("record_error failed to persist (source=%s)", source)
