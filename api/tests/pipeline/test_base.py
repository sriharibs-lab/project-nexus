"""
Tests for pipeline/base.py (ExtractionResult dataclass).

Test hints covered:
- ExtractionResult.ok is True when error is None
- ExtractionResult.ok is False when error is set
- ExtractionResult.preview truncates at the specified char count
- ContentType imported via pipeline.base is the same object as app.models.item.ContentType
"""
import enum
import importlib.util
import os
import sys
import types
import unittest


def _load_content_type_from_source() -> type:
    """Load ContentType enum directly from item.py source (avoids Python 3.9 class body issue)."""
    path = os.path.join(os.path.dirname(__file__), "../../app/models/item.py")
    with open(path) as f:
        source = f.read()

    lines = source.split("\n")
    enum_lines = ["import enum"]
    in_block = False
    for line in lines:
        if line.startswith("class ContentType"):
            in_block = True
        elif in_block and line.startswith("class ") and "ContentType" not in line:
            break
        if in_block:
            enum_lines.append(line)

    ns: dict = {}
    exec("\n".join(enum_lines), {"enum": enum}, ns)
    return ns["ContentType"]


def _load_pipeline_base():
    """
    Load pipeline/base.py with a mocked app.models.item that only exposes ContentType.
    Avoids the Python 3.10+ syntax error in SQLAlchemy model class bodies.
    """
    safe_ct = _load_content_type_from_source()

    mock_item_module = types.ModuleType("app.models.item")
    mock_item_module.ContentType = safe_ct

    mock_app_models = types.ModuleType("app.models")
    mock_app_models.item = mock_item_module

    saved = {}
    for key in ["app.models.item", "app.models", "app.core.database",
                "app.core.config", "app.core", "app"]:
        saved[key] = sys.modules.get(key)

    sys.modules["app.models.item"] = mock_item_module
    sys.modules["app.models"] = mock_app_models

    try:
        for key in list(sys.modules.keys()):
            if "pipeline" in key:
                del sys.modules[key]

        from pipeline.base import ExtractionResult, ContentType
        return ExtractionResult, ContentType, safe_ct
    finally:
        for key, val in saved.items():
            if val is None:
                sys.modules.pop(key, None)
            else:
                sys.modules[key] = val
        for key in list(sys.modules.keys()):
            if "pipeline" in key:
                del sys.modules[key]


class TestExtractionResult(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        try:
            cls.ExtractionResult, cls.ContentType, cls.ItemContentType = _load_pipeline_base()
            cls.available = True
        except Exception as e:
            cls.available = False
            cls.skip_reason = str(e)

    def _skip_if_unavailable(self):
        if not self.available:
            self.skipTest(f"pipeline.base import failed: {self.skip_reason}")

    def _make(self, **overrides):
        defaults = dict(
            extractor="test-extractor",
            url="https://example.com",
            content_type=self.ContentType.article,
            title="Test Title",
            content="Test content here.",
            word_count=3,
            elapsed_ms=100.0,
            cost_usd=None,
        )
        defaults.update(overrides)
        return self.ExtractionResult(**defaults)

    def test_ok_when_no_error(self):
        """ExtractionResult.ok must be True when error is None."""
        self._skip_if_unavailable()
        result = self._make(error=None)
        self.assertTrue(result.ok)

    def test_not_ok_when_error_set(self):
        """ExtractionResult.ok must be False when error is set."""
        self._skip_if_unavailable()
        result = self._make(error="Network timeout")
        self.assertFalse(result.ok)

    def test_preview_truncates(self):
        """preview() must truncate at the specified chars and append ellipsis."""
        self._skip_if_unavailable()
        result = self._make(content="A" * 500)
        preview = result.preview(chars=300)
        self.assertEqual(len(preview), 301)  # 300 chars + "…" (1 char)
        self.assertTrue(preview.endswith("…"))

    def test_preview_no_truncation_when_short(self):
        """preview() must not add ellipsis when content fits within limit."""
        self._skip_if_unavailable()
        result = self._make(content="Short content")
        preview = result.preview(chars=300)
        self.assertEqual(preview, "Short content")
        self.assertFalse(preview.endswith("…"))

    def test_preview_default_300_chars(self):
        """preview() defaults to 300 chars."""
        self._skip_if_unavailable()
        result = self._make(content="B" * 1000)
        preview = result.preview()
        # 300 content chars + "…"
        self.assertEqual(len(preview), 301)

    def test_preview_replaces_newlines(self):
        """preview() must replace newlines with spaces for single-line display."""
        self._skip_if_unavailable()
        result = self._make(content="line1\nline2\nline3")
        preview = result.preview(chars=300)
        self.assertNotIn("\n", preview)

    def test_content_type_field_accepts_all_enum_values(self):
        """ExtractionResult.content_type must accept all ContentType enum values."""
        self._skip_if_unavailable()
        for ct in self.ContentType:
            result = self._make(content_type=ct)
            self.assertEqual(result.content_type, ct)

    def test_metadata_defaults_to_empty_dict(self):
        """metadata defaults to {} when not specified."""
        self._skip_if_unavailable()
        result = self._make()
        self.assertEqual(result.metadata, {})

    def test_thread_content_type_valid(self):
        """ContentType.thread must be valid (was missing from old pipeline/base.py)."""
        self._skip_if_unavailable()
        ct = self.ContentType("thread")
        self.assertEqual(ct.value, "thread")
        result = self._make(content_type=ct)
        self.assertEqual(result.content_type.value, "thread")

    def test_ok_property_error_none_vs_empty_string(self):
        """ok must be True only when error is None, not when error is empty string."""
        self._skip_if_unavailable()
        result_none = self._make(error=None)
        result_empty = self._make(error="")
        self.assertTrue(result_none.ok)
        # Empty string is falsy but not None — ok checks `is None`
        # Let's verify the actual behavior from the code
        # pipeline/base.py: `return self.error is None`
        self.assertFalse(result_empty.ok)  # "" is not None


class TestPipelineBaseContentTypeIdentity(unittest.TestCase):
    """ContentType from pipeline.base must be the exact same class as app.models.item.ContentType."""

    def test_same_class_identity(self):
        """pipeline.base.ContentType must be the same object as app.models.item.ContentType."""
        ExtractionResult, pipeline_ct, item_ct = _load_pipeline_base()
        self.assertIs(pipeline_ct, item_ct,
                      "pipeline.base.ContentType must be the same object as "
                      "app.models.item.ContentType (re-exported, not copied)")


if __name__ == "__main__":
    unittest.main()
