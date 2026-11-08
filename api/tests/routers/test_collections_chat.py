"""
Tests for app/routers/collections.py — ChatRequest schema.

The `_build_system_with_cache` / `_build_messages` helpers this file once
covered were inlined into `_stream_chat` (streaming rewrite); those tests were
retired 2026-11-08 rather than re-asserted against a private generator.
"""
from app.routers.collections import ChatRequest


# ── ChatRequest schema ────────────────────────────────────────────────────────


def test_chat_request_basic():
    """ChatRequest accepts a plain message."""
    r = ChatRequest(message="hello")
    assert r.message == "hello"
    assert r.messages is None


def test_chat_request_with_history():
    """ChatRequest accepts a messages list (conversation history)."""
    history = [
        {"role": "user", "content": "hi"},
        {"role": "assistant", "content": "hey"},
    ]
    r = ChatRequest(message="hello", messages=history)
    assert r.messages is not None
    assert len(r.messages) == 2
    assert r.messages[0]["role"] == "user"


def test_chat_request_optional_embedding():
    """query_embedding field is accepted when provided."""
    r = ChatRequest(message="hello", query_embedding=[0.1, 0.2, 0.3])
    assert r.query_embedding == [0.1, 0.2, 0.3]
