"""
Unit tests for POST /v1/collections/{id}/chat SSE endpoint.

Tests run without a real database or Anthropic key — all external calls are mocked.

Run with:
    cd api && pytest tests/test_chat_sse.py -v
"""

from __future__ import annotations

import json
import uuid
from collections.abc import AsyncGenerator
from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient
from httpx import AsyncClient, ASGITransport

# ---------------------------------------------------------------------------
# Fixtures & helpers
# ---------------------------------------------------------------------------

FAKE_USER_SUPABASE_ID = "user-supabase-abc123"
FAKE_USER_UUID = uuid.uuid4()
FAKE_COLLECTION_UUID = uuid.uuid4()


def _make_fake_jwt_payload() -> dict:
    return {"sub": FAKE_USER_SUPABASE_ID, "email": "test@example.com"}


def _make_fake_collection(user_uuid: uuid.UUID, collection_uuid: uuid.UUID) -> MagicMock:
    col = MagicMock()
    col.id = collection_uuid
    col.user_id = user_uuid
    col.name = "AI Research"
    return col


def _make_fake_user(user_uuid: uuid.UUID) -> MagicMock:
    user = MagicMock()
    user.id = user_uuid
    user.supabase_id = FAKE_USER_SUPABASE_ID
    return user


# ---------------------------------------------------------------------------
# SSE stream parsing helper
# ---------------------------------------------------------------------------


def parse_sse_events(raw: str) -> list[dict]:
    """Parse raw SSE text into list of event dicts."""
    events = []
    for block in raw.split("\n\n"):
        block = block.strip()
        if block.startswith("data:"):
            payload = block[len("data:"):].strip()
            try:
                events.append(json.loads(payload))
            except json.JSONDecodeError:
                pass
    return events


# ---------------------------------------------------------------------------
# RAG helper tests (no DB required)
# ---------------------------------------------------------------------------


def test_build_context_block_empty():
    from app.core.rag import build_context_block
    assert build_context_block([]) == ""


def test_build_context_block_with_chunks():
    from app.core.rag import RagChunk, build_context_block

    chunks = [
        RagChunk(
            item_id=uuid.uuid4(),
            title="Article One",
            url="https://example.com/1",
            summary="Short summary of article one.",
            raw_content=None,
            similarity=0.92,
        ),
        RagChunk(
            item_id=uuid.uuid4(),
            title=None,
            url="https://example.com/2",
            summary=None,
            raw_content="Raw body text here.",
            similarity=0.85,
        ),
    ]
    ctx = build_context_block(chunks)

    assert "[Source 1]" in ctx
    assert "Article One" in ctx
    assert "https://example.com/1" in ctx
    assert "Short summary of article one." in ctx
    assert "[Source 2]" in ctx
    assert "Untitled" in ctx
    assert "Raw body text here." in ctx


def test_build_context_block_truncates_at_max_chars():
    from app.core.rag import RagChunk, build_context_block

    big_chunk = RagChunk(
        item_id=uuid.uuid4(),
        title="Big Article",
        url="https://example.com/big",
        summary="x" * 20_000,
        raw_content=None,
        similarity=0.9,
    )
    ctx = build_context_block([big_chunk], max_chars=500)
    assert len(ctx) <= 600  # allow small overhead for header


# ---------------------------------------------------------------------------
# Config tests
# ---------------------------------------------------------------------------


def test_anthropic_configured_false_when_key_empty():
    from app.core.config import Settings

    s = Settings(
        database_url="postgresql+asyncpg://x:x@localhost/x",
        supabase_url="https://x.supabase.co",
        supabase_jwt_secret="secret",
        supabase_anon_key="anon",
        anthropic_api_key="",
    )
    assert s.anthropic_configured is False


def test_anthropic_configured_true_when_key_set():
    from app.core.config import Settings

    s = Settings(
        database_url="postgresql+asyncpg://x:x@localhost/x",
        supabase_url="https://x.supabase.co",
        supabase_jwt_secret="secret",
        supabase_anon_key="anon",
        anthropic_api_key="sk-ant-testkey",
    )
    assert s.anthropic_configured is True


# ---------------------------------------------------------------------------
# SSE stream generator tests (mock Anthropic)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_stream_emits_sources_event_then_error_when_key_missing():
    """When ANTHROPIC_API_KEY is absent, stream emits sources + error, no exception raised."""
    from app.core.rag import RagChunk
    from app.routers.collections import _stream_chat

    fake_collection = _make_fake_collection(FAKE_USER_UUID, FAKE_COLLECTION_UUID)
    chunks = [
        RagChunk(
            item_id=uuid.uuid4(),
            title="Test Source",
            url="https://test.com",
            summary="A test summary.",
            raw_content=None,
            similarity=0.88,
        )
    ]

    with patch("app.routers.collections.settings") as mock_settings:
        mock_settings.anthropic_configured = False
        mock_settings.chat_model = "claude-sonnet-4-5"
        mock_settings.chat_max_tokens = 1024

        events = []
        async for raw_event in _stream_chat(
            collection=fake_collection,
            message="What is this about?",
            chunks=chunks,
        ):
            events.extend(parse_sse_events(raw_event))

    types = [e["type"] for e in events]
    assert "sources" in types
    assert "error" in types
    assert "done" not in types


@pytest.mark.asyncio
async def test_stream_emits_chunks_and_done_with_mocked_anthropic():
    """Happy path: Anthropic mocked to yield two text chunks, stream ends with done."""
    from app.core.rag import RagChunk
    from app.routers.collections import _stream_chat

    fake_collection = _make_fake_collection(FAKE_USER_UUID, FAKE_COLLECTION_UUID)
    chunks: list[RagChunk] = []

    async def _fake_text_stream():
        yield "Hello"
        yield " world"

    mock_stream_cm = AsyncMock()
    mock_stream_cm.__aenter__ = AsyncMock(return_value=mock_stream_cm)
    mock_stream_cm.__aexit__ = AsyncMock(return_value=False)
    mock_stream_cm.text_stream = _fake_text_stream()

    mock_client = MagicMock()
    mock_client.messages.stream.return_value = mock_stream_cm

    with patch("app.routers.collections.settings") as mock_settings, \
         patch("app.routers.collections.anthropic") as mock_anthropic:
        mock_settings.anthropic_configured = True
        mock_settings.anthropic_api_key = "sk-ant-fake"
        mock_settings.chat_model = "claude-sonnet-4-5"
        mock_settings.chat_max_tokens = 1024
        mock_anthropic.AsyncAnthropic.return_value = mock_client

        events = []
        async for raw_event in _stream_chat(
            collection=fake_collection,
            message="Summarize this",
            chunks=chunks,
        ):
            events.extend(parse_sse_events(raw_event))

    types = [e["type"] for e in events]
    assert "sources" in types
    assert "chunk" in types
    assert "done" in types
    assert "error" not in types

    chunk_texts = [e["text"] for e in events if e["type"] == "chunk"]
    assert chunk_texts == ["Hello", " world"]


@pytest.mark.asyncio
async def test_stream_emits_error_on_anthropic_auth_failure():
    """AuthenticationError from Anthropic yields an error SSE event, not an exception."""
    import anthropic as anthropic_module
    from app.core.rag import RagChunk
    from app.routers.collections import _stream_chat

    fake_collection = _make_fake_collection(FAKE_USER_UUID, FAKE_COLLECTION_UUID)

    mock_stream_cm = AsyncMock()
    mock_stream_cm.__aenter__ = AsyncMock(
        side_effect=anthropic_module.AuthenticationError(
            message="Invalid API key",
            response=MagicMock(status_code=401, headers={}),
            body={},
        )
    )
    mock_stream_cm.__aexit__ = AsyncMock(return_value=False)

    mock_client = MagicMock()
    mock_client.messages.stream.return_value = mock_stream_cm

    with patch("app.routers.collections.settings") as mock_settings, \
         patch("app.routers.collections.anthropic") as mock_anthropic:
        mock_settings.anthropic_configured = True
        mock_settings.anthropic_api_key = "sk-ant-bad"
        mock_settings.chat_model = "claude-sonnet-4-5"
        mock_settings.chat_max_tokens = 1024
        mock_anthropic.AsyncAnthropic.return_value = mock_client
        mock_anthropic.AuthenticationError = anthropic_module.AuthenticationError
        mock_anthropic.RateLimitError = anthropic_module.RateLimitError

        events = []
        async for raw_event in _stream_chat(
            collection=fake_collection,
            message="Test",
            chunks=[],
        ):
            events.extend(parse_sse_events(raw_event))

    types = [e["type"] for e in events]
    assert "error" in types
    assert "done" not in types
    error_event = next(e for e in events if e["type"] == "error")
    assert "authentication" in error_event["message"].lower()


# ---------------------------------------------------------------------------
# HTTP endpoint tests (mock DB + auth)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_chat_endpoint_returns_404_for_unknown_collection():
    """Returns 404 JSON when collection not found (not SSE — error before stream opens)."""
    from app.main import app
    from app.middleware.auth import get_current_user
    from app.core.database import get_db

    async def _fake_get_current_user():
        return {"supabase_id": FAKE_USER_SUPABASE_ID}

    mock_session = AsyncMock()
    mock_result_user = MagicMock()
    mock_result_user.scalar_one_or_none.return_value = _make_fake_user(FAKE_USER_UUID)

    mock_result_col = MagicMock()
    mock_result_col.scalar_one_or_none.return_value = None  # collection not found

    mock_session.execute = AsyncMock(side_effect=[mock_result_user, mock_result_col])

    async def _fake_get_db():
        yield mock_session  # get_db is an async generator dependency

    app.dependency_overrides = {
        get_current_user: _fake_get_current_user,
        get_db: _fake_get_db,
    }

    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            resp = await client.post(
                f"/v1/collections/{FAKE_COLLECTION_UUID}/chat",
                json={"message": "hello"},
                headers={"Authorization": "Bearer fake-token"},
            )

        assert resp.status_code == 404
    finally:
        app.dependency_overrides = {}
