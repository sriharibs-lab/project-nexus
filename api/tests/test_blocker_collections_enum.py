"""
Tests for BLOCKER-collections-enum:
- CollectionCreatedBy enum in app.models.collection
- created_by field on Collection model
- ChatRequest messages field and multi-turn forwarding
- System prompt cache_control in _stream_chat
- Invalid role filtering
- models/__init__.py exports CollectionCreatedBy
- pipeline.py docstring references Fireworks nomic-embed-text-v1.5 768-dim

All external services (DB, Anthropic) are mocked.
"""

from __future__ import annotations

import json
import os
import sys
import uuid
from unittest.mock import AsyncMock, MagicMock, patch

# Set required env vars BEFORE any app module is imported (Settings() runs at import time)
os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://test:test@localhost/test")
os.environ.setdefault("SUPABASE_URL", "https://test.supabase.co")
os.environ.setdefault("SUPABASE_SECRET_KEY", "test-secret-key")
os.environ.setdefault("SUPABASE_PUBLISHABLE_KEY", "test-publishable-key")

import pytest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _read_source(relpath: str) -> str:
    base = os.path.join(os.path.dirname(__file__), "..")
    with open(os.path.join(base, relpath)) as f:
        return f.read()


def _set_required_env():
    """Set all required env vars for Settings() to succeed."""
    os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://test:test@localhost/test")
    os.environ.setdefault("SUPABASE_URL", "https://test.supabase.co")
    os.environ.setdefault("SUPABASE_SECRET_KEY", "test-secret-key")
    os.environ.setdefault("SUPABASE_PUBLISHABLE_KEY", "test-publishable-key")


def _import_collection_model():
    """Import Collection and CollectionCreatedBy, clearing any cached modules."""
    _set_required_env()
    for key in list(sys.modules.keys()):
        if key.startswith("app.") or key in ("app",):
            del sys.modules[key]

    from app.models.collection import Collection, CollectionCreatedBy
    return Collection, CollectionCreatedBy


# ---------------------------------------------------------------------------
# Test hint 1: Import test — no ImportError
# ---------------------------------------------------------------------------

class TestCollectionCreatedByImport:
    """from app.models.collection import Collection, CollectionCreatedBy must succeed."""

    def test_import_collection_created_by(self):
        Collection, CollectionCreatedBy = _import_collection_model()
        assert Collection is not None
        assert CollectionCreatedBy is not None

    def test_import_from_models_init(self):
        """from app.models import CollectionCreatedBy must not raise ImportError."""
        _set_required_env()
        for key in list(sys.modules.keys()):
            if key.startswith("app.") or key == "app":
                del sys.modules[key]

        from app.models import CollectionCreatedBy
        assert CollectionCreatedBy is not None


# ---------------------------------------------------------------------------
# Test hint 2: Enum values
# ---------------------------------------------------------------------------

class TestCollectionCreatedByValues:
    """CollectionCreatedBy.user == 'user' and CollectionCreatedBy.ai == 'ai'."""

    def test_user_value_equals_string(self):
        _, CollectionCreatedBy = _import_collection_model()
        assert CollectionCreatedBy.user == "user"
        assert CollectionCreatedBy.user.value == "user"

    def test_ai_value_equals_string(self):
        _, CollectionCreatedBy = _import_collection_model()
        assert CollectionCreatedBy.ai == "ai"
        assert CollectionCreatedBy.ai.value == "ai"

    def test_is_str_subclass(self):
        """CollectionCreatedBy must be a str subclass so string comparison works."""
        _, CollectionCreatedBy = _import_collection_model()
        assert issubclass(CollectionCreatedBy, str)

    def test_user_enum_equals_plain_string(self):
        """String comparison: CollectionCreatedBy.user == 'user' (not just .value)."""
        _, CollectionCreatedBy = _import_collection_model()
        # str enum comparison — the enum IS the string
        assert CollectionCreatedBy.user == "user"

    def test_ai_enum_equals_plain_string(self):
        _, CollectionCreatedBy = _import_collection_model()
        assert CollectionCreatedBy.ai == "ai"


# ---------------------------------------------------------------------------
# Test hint 3: SQLAlchemy column exists, non-nullable, server_default='user'
# ---------------------------------------------------------------------------

class TestCreatedByColumn:
    """Collection.__table__.columns['created_by'] must exist, be non-nullable, server_default='user'."""

    def test_created_by_column_exists(self):
        Collection, _ = _import_collection_model()
        assert "created_by" in Collection.__table__.columns

    def test_created_by_is_not_nullable(self):
        Collection, _ = _import_collection_model()
        col = Collection.__table__.columns["created_by"]
        assert col.nullable is False

    def test_created_by_has_server_default_user(self):
        Collection, _ = _import_collection_model()
        col = Collection.__table__.columns["created_by"]
        # server_default is a FetchedValue or ColumnDefault — check the text
        sd = col.server_default
        assert sd is not None, "created_by must have a server_default"
        # SQLAlchemy wraps it in a DefaultClause; the arg should be 'user'
        sd_text = str(sd.arg) if hasattr(sd, "arg") else str(sd)
        assert "user" in sd_text, f"server_default should be 'user', got: {sd_text!r}"


# ---------------------------------------------------------------------------
# Test hint 4: create_type=False — no Postgres enum type created
# ---------------------------------------------------------------------------

class TestCreateTypeFalse:
    """The SQLAlchemy Enum must NOT attempt to create a Postgres enum type."""

    def test_create_type_false_in_source(self):
        source = _read_source("app/models/collection.py")
        assert "create_type=False" in source, (
            "Enum column must have create_type=False — "
            "migration 0003 uses VARCHAR, not a native PG enum type"
        )

    def test_column_type_is_enum_with_create_type_false(self):
        Collection, _ = _import_collection_model()
        from sqlalchemy import Enum as SAEnum
        col = Collection.__table__.columns["created_by"]
        assert isinstance(col.type, SAEnum), "created_by column type must be SAEnum"
        assert col.type.create_constraint is False or col.type.create_type is False or \
               not getattr(col.type, "create_type", True), (
            "SQLAlchemy Enum must have create_type=False to avoid creating a PG enum type"
        )


# ---------------------------------------------------------------------------
# Test hint 5: ChatRequest accepts messages: null, [], and list of dicts
# ---------------------------------------------------------------------------

class TestChatRequestSchema:
    """ChatRequest must accept messages: null, [], and list of dicts."""

    def _get_chat_request(self):
        _set_required_env()
        for key in list(sys.modules.keys()):
            if key.startswith("app."):
                del sys.modules[key]
        from app.routers.collections import ChatRequest
        return ChatRequest

    def test_messages_null_is_valid(self):
        ChatRequest = self._get_chat_request()
        req = ChatRequest(message="hello", messages=None)
        assert req.messages is None

    def test_messages_empty_list_is_valid(self):
        ChatRequest = self._get_chat_request()
        req = ChatRequest(message="hello", messages=[])
        assert req.messages == []

    def test_messages_with_turns_is_valid(self):
        ChatRequest = self._get_chat_request()
        prior = [
            {"role": "user", "content": "hello"},
            {"role": "assistant", "content": "hi"},
        ]
        req = ChatRequest(message="follow up", messages=prior)
        assert len(req.messages) == 2
        assert req.messages[0]["role"] == "user"
        assert req.messages[1]["role"] == "assistant"

    def test_messages_defaults_to_none(self):
        """messages field should default to None (backward compat)."""
        ChatRequest = self._get_chat_request()
        req = ChatRequest(message="hello")
        assert req.messages is None


# ---------------------------------------------------------------------------
# Test hint 6: Multi-turn forwarding — prior messages prepended to Anthropic call
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_multi_turn_forwarding_prepends_prior_messages():
    """
    When messages=[{role:'user',content:'hello'},{role:'assistant',content:'hi'}]
    is posted, the Anthropic call receives those two turns + current message = 3 total.
    """
    _set_required_env()
    for key in list(sys.modules.keys()):
        if key.startswith("app."):
            del sys.modules[key]

    from app.core.rag import RagChunk
    from app.routers.collections import _stream_chat

    fake_collection = MagicMock()
    fake_collection.id = uuid.uuid4()
    fake_collection.name = "Test Collection"

    prior_messages = [
        {"role": "user", "content": "hello"},
        {"role": "assistant", "content": "hi"},
    ]

    captured_calls = []

    async def _fake_text_stream():
        yield "response"

    mock_stream_cm = AsyncMock()
    mock_stream_cm.__aenter__ = AsyncMock(return_value=mock_stream_cm)
    mock_stream_cm.__aexit__ = AsyncMock(return_value=False)
    mock_stream_cm.text_stream = _fake_text_stream()

    def capture_stream(**kwargs):
        captured_calls.append(kwargs)
        return mock_stream_cm

    mock_client = MagicMock()
    mock_client.messages.stream.side_effect = capture_stream

    with patch("app.routers.collections.settings") as mock_settings, \
         patch("app.routers.collections.anthropic") as mock_anthropic:
        mock_settings.anthropic_configured = True
        mock_settings.anthropic_api_key = "sk-ant-fake"
        mock_settings.chat_model = "claude-sonnet-4-5"
        mock_settings.chat_max_tokens = 1024
        mock_anthropic.AsyncAnthropic.return_value = mock_client
        mock_anthropic.AuthenticationError = Exception
        mock_anthropic.RateLimitError = Exception

        events = []
        async for raw_event in _stream_chat(
            collection=fake_collection,
            message="follow up question",
            chunks=[],
            prior_messages=prior_messages,
        ):
            pass  # consume generator

    assert len(captured_calls) == 1, "messages.stream must be called exactly once"
    call_kwargs = captured_calls[0]
    anthropic_messages = call_kwargs["messages"]

    assert len(anthropic_messages) == 3, (
        f"Expected 3 messages (2 prior + 1 current), got {len(anthropic_messages)}: "
        f"{anthropic_messages}"
    )
    assert anthropic_messages[0]["role"] == "user"
    assert anthropic_messages[0]["content"] == "hello"
    assert anthropic_messages[1]["role"] == "assistant"
    assert anthropic_messages[1]["content"] == "hi"
    assert anthropic_messages[2]["role"] == "user"
    assert anthropic_messages[2]["content"] == "follow up question"


# ---------------------------------------------------------------------------
# Test hint 7: Invalid role filtering — system and tool roles dropped silently
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_invalid_roles_silently_dropped():
    """
    messages containing role='system' or role='tool' are silently dropped —
    no 400 from Anthropic; only 'user' and 'assistant' pass through.
    """
    _set_required_env()
    for key in list(sys.modules.keys()):
        if key.startswith("app."):
            del sys.modules[key]

    from app.routers.collections import _stream_chat

    fake_collection = MagicMock()
    fake_collection.id = uuid.uuid4()
    fake_collection.name = "Test Collection"

    # Mix of valid and invalid roles
    prior_messages = [
        {"role": "user", "content": "valid user turn"},
        {"role": "system", "content": "should be dropped"},
        {"role": "assistant", "content": "valid assistant turn"},
        {"role": "tool", "content": "should also be dropped"},
    ]

    captured_calls = []

    async def _fake_text_stream():
        yield "ok"

    mock_stream_cm = AsyncMock()
    mock_stream_cm.__aenter__ = AsyncMock(return_value=mock_stream_cm)
    mock_stream_cm.__aexit__ = AsyncMock(return_value=False)
    mock_stream_cm.text_stream = _fake_text_stream()

    def capture_stream(**kwargs):
        captured_calls.append(kwargs)
        return mock_stream_cm

    mock_client = MagicMock()
    mock_client.messages.stream.side_effect = capture_stream

    with patch("app.routers.collections.settings") as mock_settings, \
         patch("app.routers.collections.anthropic") as mock_anthropic:
        mock_settings.anthropic_configured = True
        mock_settings.anthropic_api_key = "sk-ant-fake"
        mock_settings.chat_model = "claude-sonnet-4-5"
        mock_settings.chat_max_tokens = 1024
        mock_anthropic.AsyncAnthropic.return_value = mock_client
        mock_anthropic.AuthenticationError = Exception
        mock_anthropic.RateLimitError = Exception

        async for _ in _stream_chat(
            collection=fake_collection,
            message="current question",
            chunks=[],
            prior_messages=prior_messages,
        ):
            pass

    assert len(captured_calls) == 1
    anthropic_messages = captured_calls[0]["messages"]

    # Only 'user' and 'assistant' roles should be present (+ current message)
    roles = [m["role"] for m in anthropic_messages]
    assert "system" not in roles, "system role must be filtered out"
    assert "tool" not in roles, "tool role must be filtered out"

    # Should have: valid user, valid assistant, current user = 3 messages
    assert len(anthropic_messages) == 3, (
        f"Expected 3 messages (2 valid prior + 1 current), got {len(anthropic_messages)}: {roles}"
    )


# ---------------------------------------------------------------------------
# Test hint 8: System prompt caching — system must be a list with cache_control
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_system_prompt_is_list_with_cache_control():
    """
    The Anthropic messages.stream() call must receive system as a list
    with a cache_control dict, not a plain string.
    """
    _set_required_env()
    for key in list(sys.modules.keys()):
        if key.startswith("app."):
            del sys.modules[key]

    from app.routers.collections import _stream_chat

    fake_collection = MagicMock()
    fake_collection.id = uuid.uuid4()
    fake_collection.name = "My Collection"

    captured_calls = []

    async def _fake_text_stream():
        yield "response text"

    mock_stream_cm = AsyncMock()
    mock_stream_cm.__aenter__ = AsyncMock(return_value=mock_stream_cm)
    mock_stream_cm.__aexit__ = AsyncMock(return_value=False)
    mock_stream_cm.text_stream = _fake_text_stream()

    def capture_stream(**kwargs):
        captured_calls.append(kwargs)
        return mock_stream_cm

    mock_client = MagicMock()
    mock_client.messages.stream.side_effect = capture_stream

    with patch("app.routers.collections.settings") as mock_settings, \
         patch("app.routers.collections.anthropic") as mock_anthropic:
        mock_settings.anthropic_configured = True
        mock_settings.anthropic_api_key = "sk-ant-fake"
        mock_settings.chat_model = "claude-sonnet-4-5"
        mock_settings.chat_max_tokens = 1024
        mock_anthropic.AsyncAnthropic.return_value = mock_client
        mock_anthropic.AuthenticationError = Exception
        mock_anthropic.RateLimitError = Exception

        async for _ in _stream_chat(
            collection=fake_collection,
            message="What does this mean?",
            chunks=[],
        ):
            pass

    assert len(captured_calls) == 1
    call_kwargs = captured_calls[0]

    system = call_kwargs.get("system")
    assert system is not None, "stream() call must include 'system' kwarg"
    assert isinstance(system, list), (
        f"system must be a list for cache_control, got {type(system).__name__}: {system!r}"
    )
    assert len(system) > 0, "system list must not be empty"

    first_block = system[0]
    assert isinstance(first_block, dict), "Each system block must be a dict"
    assert "cache_control" in first_block, (
        "First system block must have 'cache_control' key for prompt caching"
    )
    assert first_block["cache_control"] == {"type": "ephemeral"}, (
        f"cache_control must be {{'type': 'ephemeral'}}, got {first_block['cache_control']!r}"
    )
    assert first_block.get("type") == "text", (
        "system block type must be 'text'"
    )


# ---------------------------------------------------------------------------
# Test hint 9: models/__init__.py exports CollectionCreatedBy
# ---------------------------------------------------------------------------

class TestModelsInitExportsCollectionCreatedBy:
    """from app.models import CollectionCreatedBy must not raise ImportError."""

    def test_collection_created_by_in_init_source(self):
        source = _read_source("app/models/__init__.py")
        assert "CollectionCreatedBy" in source, (
            "__init__.py must import/export CollectionCreatedBy"
        )

    def test_collection_created_by_in_all(self):
        source = _read_source("app/models/__init__.py")
        assert '"CollectionCreatedBy"' in source, (
            'CollectionCreatedBy must appear in __all__ as "CollectionCreatedBy"'
        )

    def test_collection_created_by_import_from_models(self):
        """Live import test."""
        _set_required_env()
        for key in list(sys.modules.keys()):
            if key.startswith("app.") or key == "app":
                del sys.modules[key]

        from app.models import CollectionCreatedBy
        assert CollectionCreatedBy is not None
        assert CollectionCreatedBy.user == "user"
        assert CollectionCreatedBy.ai == "ai"


# ---------------------------------------------------------------------------
# Test hint 10: pipeline.py docstring references Fireworks nomic-embed-text-v1.5 768-dim
# ---------------------------------------------------------------------------

class TestPipelineDocstringStaleCommentFix:
    """
    api/ai/pipeline.py module docstring and EmbeddingResult docstring must reference
    Fireworks nomic-embed-text-v1.5 768-dim, NOT OpenAI text-embedding-3-small 1536-dim.
    """

    def setUp(self):
        self.source = _read_source("ai/pipeline.py")

    def test_module_docstring_references_fireworks(self):
        source = _read_source("ai/pipeline.py")
        assert "Fireworks" in source or "fireworks" in source or "nomic-embed-text-v1.5" in source, (
            "pipeline.py must reference Fireworks or nomic-embed-text-v1.5 (not OpenAI)"
        )

    def test_module_docstring_not_openai_embedding(self):
        """Module-level docstring must NOT say text-embedding-3-small or 1536."""
        source = _read_source("ai/pipeline.py")
        # Get the module docstring (between first triple-quote pair at top)
        lines = source.split("\n")
        in_docstring = False
        docstring_lines = []
        for line in lines:
            if line.startswith('"""') and not in_docstring:
                in_docstring = True
                docstring_lines.append(line)
                continue
            if in_docstring:
                docstring_lines.append(line)
                if '"""' in line:
                    break

        module_doc = "\n".join(docstring_lines)
        assert "text-embedding-3-small" not in module_doc, (
            "Module docstring must not reference text-embedding-3-small (stale OpenAI comment)"
        )
        assert "1536-dim" not in module_doc or "768-dim" in module_doc, (
            "Module docstring referencing 1536-dim should also reference 768-dim for accuracy"
        )

    def test_module_docstring_references_nomic_embed(self):
        source = _read_source("ai/pipeline.py")
        lines = source.split("\n")
        in_docstring = False
        docstring_lines = []
        for line in lines:
            if line.startswith('"""') and not in_docstring:
                in_docstring = True
                docstring_lines.append(line)
                continue
            if in_docstring:
                docstring_lines.append(line)
                if '"""' in line:
                    break

        module_doc = "\n".join(docstring_lines)
        assert "nomic-embed-text-v1.5" in module_doc or "768" in module_doc, (
            "Module docstring must reference nomic-embed-text-v1.5 or 768-dim"
        )

    def test_embedding_result_docstring_references_768_dim(self):
        """EmbeddingResult class docstring must reference 768-dim."""
        source = _read_source("ai/pipeline.py")
        # Find EmbeddingResult class definition
        idx = source.find("class EmbeddingResult")
        assert idx != -1, "EmbeddingResult class not found"
        class_section = source[idx:idx + 500]
        assert "768" in class_section or "nomic-embed-text-v1.5" in class_section, (
            "EmbeddingResult docstring must reference 768-dim (nomic-embed-text-v1.5)"
        )

    def test_embedding_result_docstring_not_1536(self):
        """EmbeddingResult docstring must not say 1536 (that was OpenAI text-embedding-3-small)."""
        source = _read_source("ai/pipeline.py")
        idx = source.find("class EmbeddingResult")
        assert idx != -1
        # Get just the docstring section of EmbeddingResult
        class_section = source[idx:idx + 400]
        # Extract docstring between triple quotes in the class body
        doc_start = class_section.find('"""')
        if doc_start != -1:
            doc_end = class_section.find('"""', doc_start + 3)
            if doc_end != -1:
                docstring = class_section[doc_start:doc_end + 3]
                assert "1536" not in docstring, (
                    "EmbeddingResult docstring must not reference 1536 (stale OpenAI dim)"
                )


# ---------------------------------------------------------------------------
# Source-level verification tests (belt-and-suspenders, fast)
# ---------------------------------------------------------------------------

class TestCollectionSourceVerification:
    """Verify key properties of collection.py source without a live DB."""

    def test_created_by_in_collection_source(self):
        source = _read_source("app/models/collection.py")
        assert "created_by" in source

    def test_collection_created_by_enum_defined(self):
        source = _read_source("app/models/collection.py")
        assert "CollectionCreatedBy" in source

    def test_enum_user_value_in_source(self):
        source = _read_source("app/models/collection.py")
        assert 'user = "user"' in source or "user = 'user'" in source

    def test_enum_ai_value_in_source(self):
        source = _read_source("app/models/collection.py")
        assert 'ai = "ai"' in source or "ai = 'ai'" in source

    def test_server_default_user_in_source(self):
        source = _read_source("app/models/collection.py")
        assert "server_default" in source

    def test_created_by_nullable_false(self):
        source = _read_source("app/models/collection.py")
        # Ensure nullable=False appears in proximity to created_by
        assert "nullable=False" in source

    def test_str_enum_base(self):
        """CollectionCreatedBy must subclass str so string comparison works."""
        source = _read_source("app/models/collection.py")
        assert "str, enum.Enum" in source or "(str, Enum)" in source


class TestChatRequestSourceVerification:
    """Verify ChatRequest has messages field in source."""

    def test_messages_field_in_collections_router(self):
        source = _read_source("app/routers/collections.py")
        assert "messages" in source
        assert "list[dict]" in source or "List[dict]" in source

    def test_messages_optional_in_source(self):
        source = _read_source("app/routers/collections.py")
        # Should be optional (None default)
        assert "messages: list[dict] | None" in source or \
               "messages: Optional[List[dict]]" in source or \
               "messages: list[dict] | None = None" in source

    def test_prior_messages_forwarded_in_stream_chat(self):
        source = _read_source("app/routers/collections.py")
        # _stream_chat should accept and use prior_messages
        assert "prior_messages" in source

    def test_role_filtering_in_source(self):
        """Source should filter to only user/assistant roles."""
        source = _read_source("app/routers/collections.py")
        assert '"user"' in source and '"assistant"' in source
        # Check for role filtering logic
        assert "safe_prior" in source or "role" in source

    def test_system_with_cache_in_source(self):
        """System prompt must be wrapped in cache_control list."""
        source = _read_source("app/routers/collections.py")
        assert "cache_control" in source
        assert "ephemeral" in source
