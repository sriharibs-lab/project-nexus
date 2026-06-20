"""
Tests for ai/pipeline.py — compute_embedding stub.

Covers hint 12:
  from ai.pipeline import compute_embedding; import asyncio;
  r = asyncio.run(compute_embedding('test'));
  assert r.dimensions == 768; assert r.model == 'nomic-ai/nomic-embed-text-v1.5'
"""
import asyncio
import math
import pytest


def test_compute_embedding_importable():
    """compute_embedding is importable from ai.pipeline."""
    from ai.pipeline import compute_embedding  # noqa: F401


def test_compute_embedding_returns_768_dims():
    """compute_embedding stub returns a 768-dimension vector."""
    from ai.pipeline import compute_embedding

    result = asyncio.run(compute_embedding("test"))
    assert result.dimensions == 768


def test_compute_embedding_model_name():
    """compute_embedding stub reports the correct model name."""
    from ai.pipeline import compute_embedding

    result = asyncio.run(compute_embedding("test"))
    assert result.model == "nomic-ai/nomic-embed-text-v1.5"


def test_compute_embedding_vector_length():
    """Returned vector has exactly 768 floats."""
    from ai.pipeline import compute_embedding

    result = asyncio.run(compute_embedding("test"))
    assert len(result.vector) == 768


def test_compute_embedding_unit_normalized():
    """Returned vector is approximately unit-normalized (for cosine similarity)."""
    from ai.pipeline import compute_embedding

    result = asyncio.run(compute_embedding("hello world"))
    magnitude = math.sqrt(sum(v * v for v in result.vector))
    assert abs(magnitude - 1.0) < 1e-5


def test_compute_embedding_deterministic():
    """Same input produces same embedding (hash-based stub)."""
    from ai.pipeline import compute_embedding

    r1 = asyncio.run(compute_embedding("same input"))
    r2 = asyncio.run(compute_embedding("same input"))
    assert r1.vector == r2.vector


def test_compute_embedding_different_inputs_differ():
    """Different inputs produce different embeddings."""
    from ai.pipeline import compute_embedding

    r1 = asyncio.run(compute_embedding("input A"))
    r2 = asyncio.run(compute_embedding("input B"))
    assert r1.vector != r2.vector


def test_embedding_result_has_required_fields():
    """EmbeddingResult dataclass has vector, dimensions, model fields."""
    from ai.pipeline import EmbeddingResult

    e = EmbeddingResult(vector=[0.0], dimensions=1, model="test")
    assert hasattr(e, "vector")
    assert hasattr(e, "dimensions")
    assert hasattr(e, "model")
