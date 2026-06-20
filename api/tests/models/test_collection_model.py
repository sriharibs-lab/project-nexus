"""
Tests for app/models/collection.py

Hint: Python: import app.models.collection; assert hasattr(app.models.collection, 'CollectionCreatedBy')
      FastAPI should import collections router without ImportError.
"""
import pytest


def test_collection_model_importable():
    """Collection model module imports without error."""
    import app.models.collection as m
    assert m is not None


def test_collection_created_by_enum_exists():
    """CollectionCreatedBy enum is present on the module."""
    import app.models.collection as m
    assert hasattr(m, "CollectionCreatedBy")


def test_collection_created_by_enum_values():
    """CollectionCreatedBy has both expected values."""
    from app.models.collection import CollectionCreatedBy

    assert CollectionCreatedBy.user == "user"
    assert CollectionCreatedBy.ai == "ai"


def test_collection_class_exists():
    """Collection ORM class is present."""
    from app.models.collection import Collection

    assert Collection.__tablename__ == "collections"


def test_collections_router_importable():
    """collections router imports without ImportError."""
    import app.routers.collections as r
    assert r is not None
    assert r.router is not None
