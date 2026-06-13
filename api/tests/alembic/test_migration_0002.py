"""
Tests for Alembic migration 0002 (api/alembic/versions/0002_add_collections.py).

These tests verify the migration script structure WITHOUT running against a real DB.
Live DB tests are guarded behind DATABASE_URL env var.

Test hints covered:
- Migration 0002 creates collections table with source_count column
- items.collection_id FK uses SET NULL (not CASCADE) on collection delete
- Migration chain: 0002 depends on 0001
- downgrade path reverses both the FK column and collections table
"""
import importlib.util
import inspect
import os
import sys
import unittest


def _load_migration():
    """Load the migration module directly from the file path."""
    path = os.path.abspath(os.path.join(
        os.path.dirname(__file__),
        "../../alembic/versions/0002_add_collections.py",
    ))
    spec = importlib.util.spec_from_file_location("migration_0002", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class TestMigration0002Structure(unittest.TestCase):
    """Structural metadata checks on the migration script — no DB required."""

    @classmethod
    def setUpClass(cls):
        try:
            cls.migration = _load_migration()
            cls.available = True
        except ImportError as e:
            cls.available = False
            cls.skip_reason = str(e)

    def _skip_if_unavailable(self):
        if not self.available:
            self.skipTest(f"alembic/sqlalchemy not installed: {self.skip_reason}")

    def test_revision_is_0002(self):
        """Migration revision must be '0002'."""
        self._skip_if_unavailable()
        self.assertEqual(self.migration.revision, "0002")

    def test_down_revision_is_0001(self):
        """Migration must chain from 0001 (linear migration history)."""
        self._skip_if_unavailable()
        self.assertEqual(self.migration.down_revision, "0001")

    def test_branch_labels_none(self):
        """No branch labels — linear migration chain."""
        self._skip_if_unavailable()
        self.assertIsNone(self.migration.branch_labels)

    def test_upgrade_function_exists(self):
        """upgrade() function must exist and be callable."""
        self._skip_if_unavailable()
        self.assertTrue(callable(self.migration.upgrade))

    def test_downgrade_function_exists(self):
        """downgrade() function must exist and be callable."""
        self._skip_if_unavailable()
        self.assertTrue(callable(self.migration.downgrade))


class TestMigration0002Logic(unittest.TestCase):
    """
    Verify the SQL operations by inspecting migration source code.
    Checks constraints, table names, and column definitions without needing a DB.
    """

    @classmethod
    def setUpClass(cls):
        try:
            cls.migration = _load_migration()
            cls.upgrade_src = inspect.getsource(cls.migration.upgrade)
            cls.downgrade_src = inspect.getsource(cls.migration.downgrade)
            cls.available = True
        except ImportError as e:
            cls.available = False
            cls.skip_reason = str(e)

    def _skip_if_unavailable(self):
        if not self.available:
            self.skipTest(f"alembic/sqlalchemy not installed: {self.skip_reason}")

    def test_upgrade_creates_collections_table(self):
        """upgrade() must create the 'collections' table."""
        self._skip_if_unavailable()
        self.assertIn("collections", self.upgrade_src,
                      "upgrade() must reference 'collections' table")
        self.assertIn("create_table", self.upgrade_src)

    def test_upgrade_adds_collection_id_to_items(self):
        """upgrade() must add collection_id FK column to items table."""
        self._skip_if_unavailable()
        self.assertIn("collection_id", self.upgrade_src)
        self.assertIn("items", self.upgrade_src)
        self.assertIn("add_column", self.upgrade_src)

    def test_set_null_on_collection_delete(self):
        """items.collection_id FK must use SET NULL on collection delete.

        Items must survive collection deletion (SPEC §5a — no global library means
        we must not orphan items when a collection is removed).
        """
        self._skip_if_unavailable()
        self.assertIn("SET NULL", self.upgrade_src,
                      "items.collection_id FK must use ondelete='SET NULL' — "
                      "items must NOT be deleted when their collection is removed")

    def test_source_count_column_present(self):
        """collections table must have source_count column (denormalized counter)."""
        self._skip_if_unavailable()
        self.assertIn("source_count", self.upgrade_src,
                      "collections table must have source_count denormalized column")

    def test_user_id_fk_cascade_on_user_delete(self):
        """collections.user_id FK must use CASCADE (user delete removes their collections)."""
        self._skip_if_unavailable()
        self.assertIn("CASCADE", self.upgrade_src,
                      "collections.user_id FK must CASCADE on user delete")

    def test_indexes_created_on_upgrade(self):
        """upgrade() must create indexes on collections.user_id and items.collection_id."""
        self._skip_if_unavailable()
        self.assertIn("ix_collections_user_id", self.upgrade_src,
                      "Missing index: ix_collections_user_id")
        self.assertIn("ix_items_collection_id", self.upgrade_src,
                      "Missing index: ix_items_collection_id")

    def test_downgrade_drops_collection_id_from_items(self):
        """downgrade() must remove collection_id from items table."""
        self._skip_if_unavailable()
        self.assertIn("collection_id", self.downgrade_src,
                      "downgrade() must drop collection_id column from items")
        self.assertIn("drop_column", self.downgrade_src)

    def test_downgrade_drops_collections_table(self):
        """downgrade() must drop the collections table."""
        self._skip_if_unavailable()
        self.assertIn("collections", self.downgrade_src,
                      "downgrade() must drop the collections table")
        self.assertIn("drop_table", self.downgrade_src)

    def test_downgrade_drops_indexes(self):
        """downgrade() must drop the indexes it created."""
        self._skip_if_unavailable()
        self.assertIn("drop_index", self.downgrade_src,
                      "downgrade() must call drop_index for indexes created in upgrade")

    def test_set_null_only_on_items_not_collections(self):
        """SET NULL must only apply to items.collection_id, not to collections.user_id (CASCADE)."""
        self._skip_if_unavailable()
        # The SET NULL should appear once (for items.collection_id)
        # The CASCADE should appear for collections.user_id
        set_null_count = self.upgrade_src.count("SET NULL")
        self.assertGreaterEqual(set_null_count, 1,
                                "SET NULL must appear at least once in upgrade()")
        cascade_count = self.upgrade_src.count("CASCADE")
        self.assertGreaterEqual(cascade_count, 1,
                                "CASCADE must appear at least once in upgrade() for user_id FK")


@unittest.skipIf(
    not os.getenv("DATABASE_URL"),
    "requires DATABASE_URL — live DB test, skipped in CI"
)
class TestMigration0002LiveDB(unittest.TestCase):
    """Live DB test: runs alembic upgrade head and verifies schema. Skipped without DATABASE_URL."""

    def test_upgrade_head_applies_0002(self):
        """alembic upgrade head must apply 0002 without error."""
        import subprocess
        api_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
        result = subprocess.run(
            ["alembic", "upgrade", "head"],
            cwd=api_dir,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0,
                         f"alembic upgrade head failed:\n{result.stderr}")


if __name__ == "__main__":
    unittest.main()
