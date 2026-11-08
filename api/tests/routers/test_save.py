"""
Tests for task 1B-003: Share Extension — capture URL from any app.

Covers the testable backend hints:
1. _detect_content_type() logic (function missing — save.py not created by SWE)
2. ContentType enum lowercase values in pipeline/base.py
3. Pipeline modules do NOT raise AttributeError on ContentType access
4. POST /v1/save router existence and auth/validation behaviour
5. pgqueuer fallback: start_worker() falls back to asyncio queue (existing ingestion.py)
6. Alembic migration 0002_pgqueuer_jobs.py existence

iOS hints are not testable in Python CI — documented as skipped.
"""

import inspect
import os
import sys
import unittest
from unittest.mock import MagicMock, patch

# ---------------------------------------------------------------------------
# Helper: add api/ to sys.path so bare imports work
# ---------------------------------------------------------------------------
_API_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
if _API_DIR not in sys.path:
    sys.path.insert(0, _API_DIR)


# ---------------------------------------------------------------------------
# 1. ContentType enum: canonical lowercase values exist
# ---------------------------------------------------------------------------
class TestContentTypeEnumLowercase(unittest.TestCase):
    """Verify ContentType.article / .video / .podcast all exist (lowercase, not uppercase)."""

    def setUp(self):
        from app.models.item import ContentType
        self.ContentType = ContentType

    def test_article_lowercase_exists(self):
        ct = self.ContentType
        self.assertTrue(hasattr(ct, "article"),
                        "ContentType.article must exist (lowercase)")

    def test_video_lowercase_exists(self):
        ct = self.ContentType
        self.assertTrue(hasattr(ct, "video"),
                        "ContentType.video must exist (lowercase)")

    def test_podcast_lowercase_exists(self):
        ct = self.ContentType
        self.assertTrue(hasattr(ct, "podcast"),
                        "ContentType.podcast must exist (lowercase)")

    def test_no_uppercase_article(self):
        ct = self.ContentType
        self.assertFalse(hasattr(ct, "ARTICLE"),
                         "ContentType.ARTICLE must NOT exist — use lowercase .article")

    def test_no_uppercase_video(self):
        ct = self.ContentType
        self.assertFalse(hasattr(ct, "VIDEO"),
                         "ContentType.VIDEO must NOT exist — use lowercase .video")

    def test_no_uppercase_podcast(self):
        ct = self.ContentType
        self.assertFalse(hasattr(ct, "PODCAST"),
                         "ContentType.PODCAST must NOT exist — use lowercase .podcast")

    def test_pipeline_base_reexports_same_class(self):
        """pipeline/base.py must re-export the same ContentType class (not a different one)."""
        from app.models.item import ContentType as ModelCT
        from pipeline.base import ContentType as PipelineCT
        self.assertIs(ModelCT, PipelineCT,
                      "pipeline/base.py must re-export the same ContentType class as app/models/item.py")


# ---------------------------------------------------------------------------
# 2. Jina pipeline: ContentType.ARTICLE raises AttributeError (bug detection)
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
