"""
Tests for api/ai/pipeline.py — summarize_item.

Covers:
- system block passed to messages.create carries cache_control: ephemeral
- response JSON is parsed into ProcessedItem; markdown fences are stripped
- model is claude-haiku-4-5; content is truncated at 8000 chars
- summarize_item never hits the network here (the Anthropic client is patched)

History: the deterministic sha256 embedding stub this file once tested was
replaced by Fireworks nomic-embed (see test_pipeline_embedding.py), and the
pipeline moved to AsyncAnthropic (`_client`), so the old sync tests were retired.
"""
import json
import os
import unittest
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

import ai.pipeline as pipeline


def _mock_response(text: str) -> MagicMock:
    block = MagicMock()
    block.type = "text"
    block.text = text
    resp = MagicMock()
    resp.content = [block]
    resp.usage.input_tokens = 100
    resp.usage.output_tokens = 20
    resp.usage.cache_read_input_tokens = 0
    return resp


def _payload(**overrides) -> str:
    data = {
        "tldr": "Test summary",
        "insights": ["insight 1", "insight 2", "insight 3"],
        "tags": ["test", "mock"],
    }
    data.update(overrides)
    return json.dumps(data)


async def _run_with_client(text: str, content: str = "Some article content.", content_type: str = "article"):
    client = MagicMock()
    client.messages.create = AsyncMock(return_value=_mock_response(text))
    with patch.object(pipeline, "_client", client):
        result = await pipeline.summarize_item(content, content_type)
    return result, client.messages.create.call_args.kwargs


async def test_cache_control_set_in_system_block():
    _, kwargs = await _run_with_client(_payload())
    assert isinstance(kwargs["system"], list), "system must be a list of blocks for cache_control"
    first = kwargs["system"][0]
    assert first["type"] == "text"
    assert first["cache_control"] == {"type": "ephemeral"}


async def test_summarize_item_parses_response():
    result, _ = await _run_with_client(_payload(tldr="AI is transforming the world."))
    assert result.tldr == "AI is transforming the world."
    assert len(result.insights) == 3
    assert result.tags == ["test", "mock"]
    assert result.model == "claude-haiku-4-5"
    assert result.input_tokens == 100


async def test_summarize_item_strips_markdown_fences():
    fenced = f"```json\n{_payload(tldr='Summary with fence.')}\n```"
    result, _ = await _run_with_client(fenced)
    assert result.tldr == "Summary with fence."


async def test_model_is_claude_haiku():
    _, kwargs = await _run_with_client(_payload())
    assert kwargs["model"] == "claude-haiku-4-5"


async def test_content_truncated_at_8000_chars():
    _, kwargs = await _run_with_client(_payload(), content="x" * 20_000)
    user_content = kwargs["messages"][0]["content"]
    content_part = user_content.split("---\n")[1].rstrip("\n---")
    assert len(content_part) <= 8001, f"Content not truncated: {len(content_part)} chars"


@pytest.mark.skipif(not os.getenv("ANTHROPIC_API_KEY"), reason="requires ANTHROPIC_API_KEY (live call)")
async def test_live_summarize_item():
    """Live smoke test — only runs when a real key is present."""
    result = await pipeline.summarize_item("The quick brown fox jumps over the lazy dog. " * 100, "article")
    assert result.tldr
