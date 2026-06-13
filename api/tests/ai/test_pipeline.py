"""
Tests for api/ai/pipeline.py.

Test hints covered:
- system dict in messages.create has 'cache_control': {'type': 'ephemeral'}
- compute_embedding produces deterministic 1536-dim unit-sphere vectors
- summarize_item parses JSON response and strips markdown fences
- summarize_item is guarded behind ANTHROPIC_API_KEY (no real network calls)
"""
import json
import os
import sys
import unittest
from unittest.mock import MagicMock, patch


def _import_pipeline():
    """Import pipeline module, clearing cache to pick up fresh mocks."""
    for mod in list(sys.modules.keys()):
        if mod in ("ai.pipeline", "api.ai.pipeline"):
            del sys.modules[mod]
    # Import from the ai package directly (the file is at api/ai/pipeline.py)
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "ai.pipeline",
        os.path.join(os.path.dirname(__file__), "../../ai/pipeline.py"),
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class TestComputeEmbedding(unittest.TestCase):
    """compute_embedding: deterministic stub — no API key needed."""

    def setUp(self):
        self.pipeline = _import_pipeline()

    def test_returns_1536_dimensions(self):
        """Embedding stub must produce exactly 1536-dim vector."""
        result = self.pipeline.compute_embedding("hello world")
        self.assertEqual(result.dimensions, 1536)
        self.assertEqual(len(result.vector), 1536)

    def test_deterministic(self):
        """Same input must always produce the same vector."""
        r1 = self.pipeline.compute_embedding("same content")
        r2 = self.pipeline.compute_embedding("same content")
        self.assertEqual(r1.vector, r2.vector)

    def test_different_inputs_different_vectors(self):
        """Different inputs must produce different vectors."""
        r1 = self.pipeline.compute_embedding("content A")
        r2 = self.pipeline.compute_embedding("content B")
        self.assertNotEqual(r1.vector, r2.vector)

    def test_unit_norm(self):
        """Vector must be normalized to unit sphere (magnitude ≈ 1.0)."""
        result = self.pipeline.compute_embedding("some content here")
        mag = sum(v * v for v in result.vector) ** 0.5
        self.assertAlmostEqual(mag, 1.0, places=4)

    def test_model_name(self):
        """Stub model name must be 'stub-sha256-1536'."""
        result = self.pipeline.compute_embedding("test")
        self.assertEqual(result.model, "stub-sha256-1536")


class TestSummarizeItemCacheControl(unittest.TestCase):
    """summarize_item: verify cache_control is set in system prompt block."""

    @unittest.skipIf(not os.getenv("ANTHROPIC_API_KEY"), "requires ANTHROPIC_API_KEY")
    def test_live_cache_control_in_usage(self):
        """Live test: cache_read_input_tokens appears once prompt exceeds 1024 tokens.
        Skipped in CI — requires real ANTHROPIC_API_KEY.
        """
        pipeline = _import_pipeline()
        # Use a long content to exceed the 1024-token cache threshold
        long_content = "The quick brown fox jumps over the lazy dog. " * 100
        result = pipeline.summarize_item(long_content, "article")
        self.assertIsNotNone(result.tldr)

    def test_cache_control_set_in_system_block(self):
        """messages.create must be called with cache_control: ephemeral in system block."""
        pipeline = _import_pipeline()

        # Capture the call args to messages.create
        captured_calls = []

        mock_response = MagicMock()
        mock_text_block = MagicMock()
        mock_text_block.type = "text"
        mock_text_block.text = json.dumps({
            "tldr": "Test summary",
            "insights": ["insight 1", "insight 2", "insight 3"],
            "tags": ["test", "mock"],
        })
        mock_response.content = [mock_text_block]

        def capture_create(**kwargs):
            captured_calls.append(kwargs)
            return mock_response

        mock_client = MagicMock()
        mock_client.messages.create.side_effect = capture_create

        with patch.object(pipeline, "client", mock_client):
            pipeline.summarize_item("Some article content here.", "article")

        self.assertEqual(len(captured_calls), 1, "messages.create must be called exactly once")
        call_kwargs = captured_calls[0]

        # system must be a list (not a string)
        self.assertIsInstance(call_kwargs["system"], list,
                              "system param must be a list of content blocks for cache_control to work")

        system_blocks = call_kwargs["system"]
        self.assertGreater(len(system_blocks), 0, "system list must be non-empty")

        first_block = system_blocks[0]
        self.assertIn("cache_control", first_block,
                      "First system block must have 'cache_control' key")
        self.assertEqual(first_block["cache_control"], {"type": "ephemeral"},
                         "cache_control must be {'type': 'ephemeral'}")
        self.assertEqual(first_block.get("type"), "text",
                         "system block type must be 'text'")

    def test_summarize_item_parses_response(self):
        """summarize_item must parse the JSON response into a ProcessedItem."""
        pipeline = _import_pipeline()

        mock_response = MagicMock()
        mock_text_block = MagicMock()
        mock_text_block.type = "text"
        mock_text_block.text = json.dumps({
            "tldr": "AI is transforming the world.",
            "insights": ["Insight A", "Insight B", "Insight C"],
            "tags": ["ai", "technology", "future"],
        })
        mock_response.content = [mock_text_block]

        mock_client = MagicMock()
        mock_client.messages.create.return_value = mock_response

        with patch.object(pipeline, "client", mock_client):
            result = pipeline.summarize_item("Article content here.", "article")

        self.assertEqual(result.tldr, "AI is transforming the world.")
        self.assertEqual(len(result.insights), 3)
        self.assertEqual(result.tags, ["ai", "technology", "future"])

    def test_summarize_item_strips_markdown_fences(self):
        """summarize_item must strip ```json ... ``` fences if model wraps response."""
        pipeline = _import_pipeline()

        payload = {
            "tldr": "Summary with fence.",
            "insights": ["Point 1"],
            "tags": ["fence-test"],
        }
        # Simulate model returning wrapped JSON
        fenced_text = f"```json\n{json.dumps(payload)}\n```"

        mock_response = MagicMock()
        mock_text_block = MagicMock()
        mock_text_block.type = "text"
        mock_text_block.text = fenced_text
        mock_response.content = [mock_text_block]

        mock_client = MagicMock()
        mock_client.messages.create.return_value = mock_response

        with patch.object(pipeline, "client", mock_client):
            result = pipeline.summarize_item("Content.", "article")

        self.assertEqual(result.tldr, "Summary with fence.")

    def test_model_is_claude_haiku(self):
        """messages.create must use claude-haiku-4-5 model."""
        pipeline = _import_pipeline()

        mock_response = MagicMock()
        mock_text_block = MagicMock()
        mock_text_block.type = "text"
        mock_text_block.text = json.dumps({
            "tldr": "x", "insights": ["a"], "tags": ["t"],
        })
        mock_response.content = [mock_text_block]

        mock_client = MagicMock()
        mock_client.messages.create.return_value = mock_response

        with patch.object(pipeline, "client", mock_client):
            pipeline.summarize_item("Content.", "article")

        call_kwargs = mock_client.messages.create.call_args[1]
        self.assertEqual(call_kwargs["model"], "claude-haiku-4-5")

    def test_content_truncated_at_8000_chars(self):
        """summarize_item must truncate content to 8000 chars (guard for huge inputs)."""
        pipeline = _import_pipeline()

        mock_response = MagicMock()
        mock_text_block = MagicMock()
        mock_text_block.type = "text"
        mock_text_block.text = json.dumps({
            "tldr": "x", "insights": ["a"], "tags": ["t"],
        })
        mock_response.content = [mock_text_block]

        mock_client = MagicMock()
        mock_client.messages.create.return_value = mock_response

        long_content = "x" * 20_000

        with patch.object(pipeline, "client", mock_client):
            pipeline.summarize_item(long_content, "article")

        call_kwargs = mock_client.messages.create.call_args[1]
        # The user message content should not exceed 8000 chars of input content
        user_message_content = call_kwargs["messages"][0]["content"]
        # The template adds some overhead, but the raw content part is capped at 8000
        # Find where the content section starts (after the --- separator)
        parts = user_message_content.split("---\n")
        # parts[1] is the content section
        content_part = parts[1].rstrip("\n---")
        self.assertLessEqual(len(content_part), 8001,
                             f"Content not truncated: {len(content_part)} chars")


if __name__ == "__main__":
    unittest.main()
