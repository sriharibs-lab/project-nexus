"""
Tests for app/routers/collections.py — ChatRequest schema, _build_system_with_cache,
and _build_messages helpers.

Covers hints 7–11 from the task test_hints.
"""
import logging
import pytest

from app.routers.collections import (
    ChatRequest,
    _build_messages,
    _build_system_with_cache,
)


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


# ── _build_system_with_cache ──────────────────────────────────────────────────


def test_build_system_returns_list():
    """_build_system_with_cache must return a list."""
    result = _build_system_with_cache("Test Collection", "some context")
    assert isinstance(result, list)


def test_build_system_cache_control_ephemeral():
    """First element has cache_control set to ephemeral."""
    result = _build_system_with_cache("Test Collection", "some context")
    assert result[0]["cache_control"] == {"type": "ephemeral"}


def test_build_system_contains_collection_name():
    """The system text interpolates the collection name."""
    result = _build_system_with_cache("My Collection", "ctx")
    assert "My Collection" in result[0]["text"]


def test_build_system_empty_context_fallback():
    """When context is empty, a fallback message is inserted."""
    result = _build_system_with_cache("Test", "")
    assert "No completed sources" in result[0]["text"]


def test_build_system_type_is_text():
    """Block type is 'text'."""
    result = _build_system_with_cache("T", "ctx")
    assert result[0]["type"] == "text"


# ── _build_messages ───────────────────────────────────────────────────────────


def test_build_messages_no_history():
    """No history returns a single user turn."""
    msgs = _build_messages(None, "hello")
    assert msgs == [{"role": "user", "content": "hello"}]


def test_build_messages_empty_list():
    """Empty list is treated same as None — returns single user turn."""
    msgs = _build_messages([], "hello")
    assert msgs == [{"role": "user", "content": "hello"}]


def test_build_messages_appends_new_turn():
    """Valid history gets the new user message appended."""
    history = [
        {"role": "user", "content": "a"},
        {"role": "assistant", "content": "b"},
    ]
    msgs = _build_messages(history, "new")
    assert msgs[-1] == {"role": "user", "content": "new"}
    assert msgs[0] == {"role": "user", "content": "a"}
    assert len(msgs) == 3


def test_build_messages_malformed_last_role_user(caplog):
    """Malformed history (last role is user) falls back to single-turn and logs warning."""
    history = [
        {"role": "user", "content": "a"},
        {"role": "assistant", "content": "b"},
        {"role": "user", "content": "stray"},  # malformed: ends with user
    ]
    with caplog.at_level(logging.WARNING):
        msgs = _build_messages(history, "hello")

    assert msgs == [{"role": "user", "content": "hello"}]
    assert any("malformed" in r.message.lower() or "fallback" in r.message.lower()
               for r in caplog.records)


def test_build_messages_clamps_to_max_history():
    """History is clamped to at most _MAX_HISTORY_TURNS messages."""
    from app.routers.collections import _MAX_HISTORY_TURNS

    # Build a long alternating history ending in assistant
    history = []
    for i in range(20):
        history.append({"role": "user", "content": f"u{i}"})
        history.append({"role": "assistant", "content": f"a{i}"})

    msgs = _build_messages(history, "new")
    # The clamped slice + new user turn
    assert len(msgs) <= _MAX_HISTORY_TURNS + 1
    assert msgs[-1] == {"role": "user", "content": "new"}
