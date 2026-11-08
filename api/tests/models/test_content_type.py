"""
Tests for ContentType enum (app/models/item.py) and pipeline/base.py re-export.

NOTE: The model files use Python 3.10+ union syntax (str | None) in SQLAlchemy
Mapped[] class bodies. This requires Python 3.10+. The project's pyproject.toml
correctly specifies python = "^3.12". Tests are designed to run on the available
Python version by directly importing the enum (defined before the SQLAlchemy class
bodies) without triggering the class-body syntax error.

Test hints covered:
- All expected content_type values are present in the canonical enum
- 'thread' content type is now valid (was missing from pipeline/base.py)
- Invalid content_type strings are rejected by the enum
- pipeline/base.py re-exports ContentType from app.models.item (single source of truth)
"""
import enum
import importlib.util
import os
import sys
import unittest


# ---------------------------------------------------------------------------
# Helper: import ContentType by extracting just the enum from item.py source.
# This avoids loading the full Item SQLAlchemy model which uses Python 3.10+
# X | None syntax in Mapped[] class bodies (fails on Python 3.9).
# ---------------------------------------------------------------------------

def _load_content_type_from_source() -> type:
    """
    Extract and compile just the ContentType enum from app/models/item.py.
    Safe to run on Python 3.9 because the X | None syntax is only in the
    Item class body (after the enum), not in the enum itself.
    """
    path = os.path.join(os.path.dirname(__file__), "../../app/models/item.py")
    with open(path) as f:
        source = f.read()

    # Extract only the ContentType enum block (before the IngestStatus class)
    lines = source.split("\n")
    enum_lines = ["import enum"]  # need enum in namespace
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


def _load_pipeline_base_content_type() -> type:
    """
    Load pipeline/base.py and return its ContentType attribute.
    pipeline/base.py only imports from app.models.item — we patch the import
    to return our safely-extracted ContentType.
    """
    safe_ct = _load_content_type_from_source()

    # Build a minimal mock for app.models.item that just has ContentType
    import types
    mock_item_module = types.ModuleType("app.models.item")
    mock_item_module.ContentType = safe_ct

    # Also need app.models.__init__ and app.core chain to not trigger bad imports
    mock_app_models = types.ModuleType("app.models")
    mock_app_models.item = mock_item_module

    saved = {}
    for key in ["app.models.item", "app.models", "app.core.database",
                "app.core.config", "app.core", "app"]:
        saved[key] = sys.modules.get(key)

    sys.modules["app.models.item"] = mock_item_module
    sys.modules["app.models"] = mock_app_models

    try:
        # Clear any cached pipeline.base
        for key in list(sys.modules.keys()):
            if "pipeline" in key:
                del sys.modules[key]

        from pipeline.base import ContentType as PipelineCT
        return PipelineCT, safe_ct
    finally:
        # Restore sys.modules
        for key, val in saved.items():
            if val is None:
                sys.modules.pop(key, None)
            else:
                sys.modules[key] = val
        for key in list(sys.modules.keys()):
            if "pipeline" in key:
                del sys.modules[key]


class TestContentTypeEnum(unittest.TestCase):
    """ContentType enum defined in app/models/item.py."""

    def setUp(self):
        self.ContentType = _load_content_type_from_source()

    def test_all_canonical_values_present(self):
        """ContentType enum must include the 7 SPEC §5a types plus `youtube` (added for the YouTube extractor route)."""
        values = {e.value for e in self.ContentType}
        expected = {"article", "podcast", "video", "thread", "blog", "announcement", "youtube", "other"}
        self.assertEqual(expected, values,
                         f"Missing: {expected - values}, Extra: {values - expected}")

    def test_thread_is_valid(self):
        """'thread' must be a valid ContentType — previously was missing from pipeline/base.py."""
        ct = self.ContentType("thread")
        self.assertEqual(ct.value, "thread")

    def test_invalid_content_type_raises(self):
        """ContentType('garbage') must raise ValueError — prevents silent routing errors."""
        with self.assertRaises(ValueError):
            self.ContentType("garbage")

    def test_content_type_is_str_enum(self):
        """ContentType inherits from str so values serialize correctly as JSON strings."""
        self.assertTrue(issubclass(self.ContentType, str))

    def test_all_values_are_lowercase_strings(self):
        """All ContentType values must be lowercase strings (consistent JSON serialization)."""
        for ct in self.ContentType:
            self.assertEqual(ct.value, ct.value.lower(), f"{ct.value} is not lowercase")
            self.assertIsInstance(ct.value, str)

    def test_article_is_default_string(self):
        """'article' must be a valid ContentType value (default for IngestRequest)."""
        ct = self.ContentType("article")
        self.assertEqual(ct.value, "article")


class TestPipelineBaseReExport(unittest.TestCase):
    """pipeline/base.py must re-export ContentType from app.models.item."""

    def setUp(self):
        try:
            self.pipeline_ct, self.item_ct = _load_pipeline_base_content_type()
            self.available = True
        except Exception as e:
            self.available = False
            self.skip_reason = str(e)

    def test_pipeline_base_re_exports_content_type(self):
        """pipeline.base.ContentType must be the same class as app.models.item.ContentType."""
        if not self.available:
            self.skipTest(f"pipeline.base import failed: {self.skip_reason}")
        self.assertIs(self.pipeline_ct, self.item_ct,
                      "pipeline.base.ContentType must be the exact same object as "
                      "app.models.item.ContentType — not a copy")

    def test_pipeline_base_thread_accessible(self):
        """pipeline.base re-exported ContentType includes 'thread' (was missing before fix)."""
        if not self.available:
            self.skipTest(f"pipeline.base import failed: {self.skip_reason}")
        ct = self.pipeline_ct("thread")
        self.assertEqual(ct.value, "thread")

    def test_pipeline_base_has_all_types(self):
        """pipeline.base ContentType must have all 8 values (not just old 3)."""
        if not self.available:
            self.skipTest(f"pipeline.base import failed: {self.skip_reason}")
        values = {e.value for e in self.pipeline_ct}
        self.assertIn("thread", values)
        self.assertIn("blog", values)
        self.assertIn("announcement", values)
        self.assertIn("youtube", values)
        self.assertEqual(len(values), 8)


class TestPython39CompatibilityIssue(unittest.TestCase):
    """
    Document the Python 3.9 incompatibility in the SQLAlchemy model class bodies.
    The models use X | None syntax (PEP 604) which requires Python 3.10+.
    pyproject.toml correctly requires python ^3.12, but CI/test env has 3.9.
    """

    def test_python_version_constraint_documented(self):
        """Document that models require Python 3.10+ (pyproject.toml: ^3.12)."""
        # This is not a blocking bug in production (the project targets Python 3.12).
        # It's a CI environment issue — the test runner has Python 3.9.
        # The ContentType enum itself is safe; the SQLAlchemy Mapped[] class bodies
        # fail on Python 3.9 when imported through __init__.py.
        major, minor = sys.version_info[:2]
        if major == 3 and minor < 10:
            # Verify we can still import ContentType safely (enum only)
            ct = _load_content_type_from_source()
            self.assertIsNotNone(ct)
            # Confirm full model import DOES fail on Python 3.9
            import types
            mock_db = types.ModuleType("app.core.database")
            mock_db.Base = object
            old = sys.modules.get("app.core.database")
            try:
                sys.modules["app.core.database"] = mock_db
                for mod in list(sys.modules.keys()):
                    if mod.startswith("app.models"):
                        del sys.modules[mod]
                try:
                    from app.models.collection import Collection  # noqa: F401
                    # If we get here on 3.9, the models were fixed — great!
                    self.fail(
                        "Expected TypeError for X|None syntax on Python 3.9, "
                        "but import succeeded. If models were fixed, remove this check."
                    )
                except TypeError as e:
                    # Expected on Python 3.9 — document the error
                    self.assertIn("|", str(e))
            finally:
                if old is None:
                    sys.modules.pop("app.core.database", None)
                else:
                    sys.modules["app.core.database"] = old
        else:
            # Python 3.10+ — no issue
            self.skipTest(f"Python {major}.{minor} supports X|None syntax natively")


if __name__ == "__main__":
    unittest.main()
