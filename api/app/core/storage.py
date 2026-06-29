"""
R2/S3-compatible object storage client (1A-008).

Wraps Cloudflare R2 via the S3-compatible API using aioboto3.
All public functions degrade gracefully: if R2 is not configured (missing
credentials) they return None / skip silently so the caller falls back to
Postgres TEXT.

Key scheme:
  raw/{user_id}/{item_id}.txt

This keeps objects owner-scoped without an extra DB lookup, and the .txt
extension hints at the MIME type for any future CDN rules.
"""

from __future__ import annotations

import logging
from typing import Optional

logger = logging.getLogger(__name__)

# Lazy import — aioboto3 is optional (tests can mock at module level)
try:
    import aioboto3  # type: ignore[import]
    _AIOBOTO3_AVAILABLE = True
except ImportError:
    _AIOBOTO3_AVAILABLE = False
    logger.warning("aioboto3 not installed — R2 storage unavailable, falling back to Postgres TEXT")


def _make_endpoint(account_id: str) -> str:
    return f"https://{account_id}.r2.cloudflarestorage.com"


def _r2_key(user_id: str, item_id: str) -> str:
    return f"raw/{user_id}/{item_id}.txt"


async def upload_raw_content(
    user_id: str,
    item_id: str,
    content: str,
) -> Optional[str]:
    """
    Upload raw content string to R2.

    Returns the R2 object key on success, None if R2 is unavailable or upload fails.
    Never raises — caller falls back to Postgres TEXT on None.
    """
    from app.core.config import settings

    if not _AIOBOTO3_AVAILABLE or not settings.r2_configured:
        return None

    key = _r2_key(user_id, item_id)
    try:
        session = aioboto3.Session()
        async with session.client(
            "s3",
            endpoint_url=_make_endpoint(settings.r2_account_id),
            aws_access_key_id=settings.r2_access_key_id,
            aws_secret_access_key=settings.r2_secret_access_key,
            region_name="auto",
        ) as s3:
            await s3.put_object(
                Bucket=settings.r2_bucket_name,
                Key=key,
                Body=content.encode("utf-8"),
                ContentType="text/plain; charset=utf-8",
            )
        logger.info("R2 upload ok key=%s bytes=%d", key, len(content.encode("utf-8")))
        return key
    except Exception as exc:
        logger.warning("R2 upload failed key=%s exc=%s — falling back to Postgres TEXT", key, exc)
        return None


async def download_raw_content(key: str) -> Optional[str]:
    """
    Download raw content string from R2 by object key.

    Returns the content string on success, None if R2 is unavailable or key not found.
    Never raises.
    """
    from app.core.config import settings

    if not _AIOBOTO3_AVAILABLE or not settings.r2_configured:
        return None

    try:
        session = aioboto3.Session()
        async with session.client(
            "s3",
            endpoint_url=_make_endpoint(settings.r2_account_id),
            aws_access_key_id=settings.r2_access_key_id,
            aws_secret_access_key=settings.r2_secret_access_key,
            region_name="auto",
        ) as s3:
            response = await s3.get_object(Bucket=settings.r2_bucket_name, Key=key)
            body = await response["Body"].read()
        content = body.decode("utf-8")
        logger.info("R2 download ok key=%s bytes=%d", key, len(body))
        return content
    except Exception as exc:
        logger.warning("R2 download failed key=%s exc=%s", key, exc)
        return None


async def delete_raw_content(key: str) -> None:
    """
    Delete an R2 object by key. Silently no-ops if R2 is unavailable.
    """
    from app.core.config import settings

    if not _AIOBOTO3_AVAILABLE or not settings.r2_configured:
        return

    try:
        session = aioboto3.Session()
        async with session.client(
            "s3",
            endpoint_url=_make_endpoint(settings.r2_account_id),
            aws_access_key_id=settings.r2_access_key_id,
            aws_secret_access_key=settings.r2_secret_access_key,
            region_name="auto",
        ) as s3:
            await s3.delete_object(Bucket=settings.r2_bucket_name, Key=key)
        logger.info("R2 delete ok key=%s", key)
    except Exception as exc:
        logger.warning("R2 delete failed key=%s exc=%s", key, exc)
