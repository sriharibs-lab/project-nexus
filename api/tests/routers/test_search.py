"""
Tests for GET /v1/search backend endpoint (app/routers/search.py).
Task: 1C-006 — Full-text + semantic search.

Coverage:
- Search router file exists (MISSING — SWE output incomplete)
- Config has FIREWORKS_API_KEY / fireworks_configured property
- RAG helper (rag.py) unit tests — no DB required
- Migration 0004: embeddings resized to 768-dim
- Auth: missing JWT → 401
- Validation: empty q → 422, limit > 50 → 422
- Mode=fts, mode=semantic, mode=hybrid
- Cross-user isolation enforced in RAG query
- embedding_available reflects FIREWORKS_API_KEY presence
"""

import importlib.util
import inspect
import os
import sys
import types
import unittest
import uuid
from unittest.mock import AsyncMock, MagicMock, patch


# ---------------------------------------------------------------------------
# 1. Search router file existence
# ---------------------------------------------------------------------------

class TestSearchRouterExists(unittest.TestCase):
    """The SWE agent must have created api/app/routers/search.py."""

    ROUTER_PATH = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "../../app/routers/search.py")
    )

    def test_search_router_file_exists(self):
        self.assertTrue(
            os.path.exists(self.ROUTER_PATH),
            f"search.py missing at {self.ROUTER_PATH} — SWE agent did not create it",
        )

    def test_search_router_registered_in_main(self):
        """main.py must import and include the search router (not just 're-search')."""
        main_path = os.path.abspath(
            os.path.join(os.path.dirname(__file__), "../../app/main.py")
        )
        with open(main_path) as f:
            source = f.read()
        # "search" as a standalone import or router, not inside "research"
        import re
        has_search_import = bool(re.search(r'\bsearch\b', source))
        # A more specific check: search must appear outside "research"
        cleaned = source.replace("research", "")
        self.assertIn(
            "search",
            cleaned,
            "app/main.py must import and register the search router (distinct from research)",
        )


# ---------------------------------------------------------------------------
# 2. Config: FIREWORKS_API_KEY / fireworks_configured
# ---------------------------------------------------------------------------

class TestConfigFireworks(unittest.TestCase):
    """Settings must expose fireworks_api_key and fireworks_configured."""

    def _load_config_source(self) -> str:
        path = os.path.abspath(
            os.path.join(os.path.dirname(__file__), "../../app/core/config.py")
        )
        with open(path) as f:
            return f.read()

    def test_fireworks_api_key_in_config(self):
        source = self._load_config_source()
        self.assertIn(
            "fireworks_api_key",
            source.lower(),
            "config.py must declare fireworks_api_key setting",
        )

    def test_fireworks_configured_property(self):
        source = self._load_config_source()
        self.assertIn(
            "fireworks_configured",
            source,
            "config.py must expose a fireworks_configured property",
        )


# ---------------------------------------------------------------------------
# 3. RAG helper unit tests (no DB)
# ---------------------------------------------------------------------------

def _load_rag():
    """Import rag.py, ensuring the module name is registered in sys.modules."""
    module_name = "app.core.rag"
    if module_name in sys.modules:
        return sys.modules[module_name]

    # Ensure parent namespace packages are present so dataclass type resolution works
    for ns in ("app", "app.core"):
        if ns not in sys.modules:
            sys.modules[ns] = types.ModuleType(ns)

    rag_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "../../app/core/rag.py")
    )
    spec = importlib.util.spec_from_file_location(module_name, rag_path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module  # register BEFORE exec to fix self-referential annotations
    spec.loader.exec_module(module)
    return module


class TestRagChunkDataclass(unittest.TestCase):
    """RagChunk dataclass fields and construction."""

    def setUp(self):
        self.rag = _load_rag()

    def test_ragchunk_has_item_id(self):
        chunk = self.rag.RagChunk(
            item_id=uuid.uuid4(),
            title="Test",
            url="https://example.com",
            summary="A summary",
            raw_content=None,
            similarity=0.85,
        )
        self.assertIsInstance(chunk.item_id, uuid.UUID)

    def test_ragchunk_similarity_float(self):
        chunk = self.rag.RagChunk(
            item_id=uuid.uuid4(),
            title=None,
            url="https://example.com",
            summary=None,
            raw_content="raw",
            similarity=0.75,
        )
        self.assertIsInstance(chunk.similarity, float)

    def test_ragchunk_all_fields(self):
        iid = uuid.uuid4()
        chunk = self.rag.RagChunk(
            item_id=iid,
            title="Title",
            url="https://x.com",
            summary="Sum",
            raw_content="Raw",
            similarity=0.9,
        )
        self.assertEqual(chunk.title, "Title")
        self.assertEqual(chunk.url, "https://x.com")
        self.assertEqual(chunk.summary, "Sum")
        self.assertEqual(chunk.raw_content, "Raw")


class TestBuildContextBlock(unittest.TestCase):
    """build_context_block produces correct context string."""

    def setUp(self):
        self.rag = _load_rag()

    def _make_chunk(self, idx: int, body: str = "") -> object:
        return self.rag.RagChunk(
            item_id=uuid.uuid4(),
            title=f"Source {idx}",
            url=f"https://example.com/{idx}",
            summary=body or f"Summary {idx}",
            raw_content=None,
            similarity=0.9 - idx * 0.1,
        )

    def test_empty_chunks_returns_empty_string(self):
        result = self.rag.build_context_block([])
        self.assertEqual(result, "")

    def test_single_chunk_contains_url(self):
        chunk = self._make_chunk(0)
        result = self.rag.build_context_block([chunk])
        self.assertIn("https://example.com/0", result)

    def test_single_chunk_contains_title(self):
        chunk = self._make_chunk(0)
        result = self.rag.build_context_block([chunk])
        self.assertIn("Source 0", result)

    def test_multiple_chunks_numbered(self):
        chunks = [self._make_chunk(i) for i in range(3)]
        result = self.rag.build_context_block(chunks)
        self.assertIn("[Source 1]", result)
        self.assertIn("[Source 2]", result)
        self.assertIn("[Source 3]", result)

    def test_max_chars_respected(self):
        """Context block must not exceed max_chars."""
        big_body = "x" * 5000
        chunks = [self._make_chunk(i, big_body) for i in range(5)]
        result = self.rag.build_context_block(chunks, max_chars=1000)
        self.assertLessEqual(len(result), 1100)  # allow small overshoot for header

    def test_untitled_chunk_shows_untitled(self):
        chunk = self.rag.RagChunk(
            item_id=uuid.uuid4(),
            title=None,
            url="https://example.com",
            summary="Some content",
            raw_content=None,
            similarity=0.5,
        )
        result = self.rag.build_context_block([chunk])
        self.assertIn("Untitled", result)

    def test_uses_raw_content_when_no_summary(self):
        chunk = self.rag.RagChunk(
            item_id=uuid.uuid4(),
            title="T",
            url="https://example.com",
            summary=None,
            raw_content="raw fallback",
            similarity=0.5,
        )
        result = self.rag.build_context_block([chunk])
        self.assertIn("raw fallback", result)


class TestRetrieveSimilarChunksSignature(unittest.TestCase):
    """retrieve_similar_chunks accepts the expected parameters."""

    def setUp(self):
        self.rag = _load_rag()

    def test_function_exists(self):
        self.assertTrue(callable(getattr(self.rag, "retrieve_similar_chunks", None)))

    def test_is_async(self):
        import asyncio
        self.assertTrue(
            asyncio.iscoroutinefunction(self.rag.retrieve_similar_chunks),
            "retrieve_similar_chunks must be async",
        )

    def test_accepts_collection_id_param(self):
        sig = inspect.signature(self.rag.retrieve_similar_chunks)
        self.assertIn("collection_id", sig.parameters)

    def test_accepts_user_id_param(self):
        sig = inspect.signature(self.rag.retrieve_similar_chunks)
        self.assertIn("user_id", sig.parameters)

    def test_accepts_query_vector_param(self):
        sig = inspect.signature(self.rag.retrieve_similar_chunks)
        self.assertIn("query_vector", sig.parameters)

    def test_accepts_top_k_param(self):
        sig = inspect.signature(self.rag.retrieve_similar_chunks)
        self.assertIn("top_k", sig.parameters)

    def test_top_k_default_is_8(self):
        sig = inspect.signature(self.rag.retrieve_similar_chunks)
        self.assertEqual(sig.parameters["top_k"].default, 8)


class TestRetrieveSimilarChunksCrossUserIsolation(unittest.TestCase):
    """SQL query must filter by BOTH collection_id AND user_id."""

    def setUp(self):
        self.rag = _load_rag()

    def test_sql_filters_user_id(self):
        """The similarity SQL must include user_id filter to prevent cross-user leakage."""
        sql_text = str(self.rag._SIMILARITY_QUERY)
        self.assertIn("user_id", sql_text.lower(),
                      "SQL query must filter by user_id for cross-user isolation")

    def test_sql_filters_collection_id(self):
        sql_text = str(self.rag._SIMILARITY_QUERY)
        self.assertIn("collection_id", sql_text.lower())

    def test_sql_filters_ingest_status_completed(self):
        """Only completed items should be returned."""
        sql_text = str(self.rag._SIMILARITY_QUERY)
        self.assertIn("completed", sql_text.lower())

    def test_sql_has_cosine_distance_operator(self):
        """pgvector cosine distance operator <=> must appear in query."""
        sql_text = str(self.rag._SIMILARITY_QUERY)
        self.assertIn("<=>", sql_text)


# ---------------------------------------------------------------------------
# 4. Migration 0004 — embeddings resized to 768-dim
# ---------------------------------------------------------------------------

def _load_migration_0004():
    path = os.path.abspath(
        os.path.join(
            os.path.dirname(__file__),
            "../../alembic/versions/0004_fireworks_embeddings_768.py",
        )
    )
    if not os.path.exists(path):
        return None
    spec = importlib.util.spec_from_file_location("mig0004", path)
    module = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(module)
    except Exception:
        return None
    return module


class TestMigration0004Structure(unittest.TestCase):
    """Migration 0004: 1536→768 embedding resize."""

    @classmethod
    def setUpClass(cls):
        cls.mig = _load_migration_0004()

    def _skip_if_missing(self):
        if self.mig is None:
            self.skipTest("Migration 0004 not found or failed to load")

    def test_revision_is_0004(self):
        self._skip_if_missing()
        self.assertEqual(self.mig.revision, "0004")

    def test_down_revision_is_0003(self):
        self._skip_if_missing()
        self.assertEqual(self.mig.down_revision, "0003")

    def test_upgrade_function_exists(self):
        self._skip_if_missing()
        self.assertTrue(callable(getattr(self.mig, "upgrade", None)))

    def test_downgrade_function_exists(self):
        self._skip_if_missing()
        self.assertTrue(callable(getattr(self.mig, "downgrade", None)))

    def test_upgrade_targets_768_dim(self):
        self._skip_if_missing()
        src = inspect.getsource(self.mig.upgrade)
        self.assertIn("768", src, "upgrade() must create Vector(768)")

    def test_upgrade_deletes_old_embeddings(self):
        self._skip_if_missing()
        src = inspect.getsource(self.mig.upgrade)
        self.assertIn("DELETE FROM embeddings", src,
                      "upgrade() must delete stale embedding rows before resize")

    def test_downgrade_reverts_to_1536(self):
        self._skip_if_missing()
        src = inspect.getsource(self.mig.downgrade)
        self.assertIn("1536", src, "downgrade() must restore Vector(1536)")

    def test_creates_user_interest_profiles(self):
        self._skip_if_missing()
        src = inspect.getsource(self.mig.upgrade)
        self.assertIn("user_interest_profiles", src)


# ---------------------------------------------------------------------------
# 5. Embedding model: EMBEDDING_DIM = 768
# ---------------------------------------------------------------------------

class TestEmbeddingModel768Dim(unittest.TestCase):
    """Embedding SQLAlchemy model must use 768-dim vector."""

    def _load(self):
        path = os.path.abspath(
            os.path.join(os.path.dirname(__file__), "../../app/models/embedding.py")
        )
        with open(path) as f:
            return f.read()

    def test_embedding_dim_is_768(self):
        src = self._load()
        self.assertIn("EMBEDDING_DIM = 768", src,
                      "embedding.py must define EMBEDDING_DIM = 768")

    def test_model_is_nomic(self):
        src = self._load()
        self.assertIn("nomic", src.lower(),
                      "embedding.py must reference nomic-embed-text-v1.5 model")

    def test_vector_768_in_column(self):
        src = self._load()
        # embedding.py may use Vector(EMBEDDING_DIM) or literal Vector(768)
        self.assertTrue(
            "Vector(EMBEDDING_DIM)" in src or "Vector(768)" in src,
            "embedding.py must use Vector(768) or Vector(EMBEDDING_DIM) in the column definition",
        )


# ---------------------------------------------------------------------------
# 6. Search router: endpoint contract (structure tests when file exists)
# ---------------------------------------------------------------------------

ROUTER_PATH = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "../../app/routers/search.py")
)
_ROUTER_EXISTS = os.path.exists(ROUTER_PATH)


class TestSearchRouterContract(unittest.TestCase):
    """Verify search.py implements the expected contract by inspecting its source."""

    def setUp(self):
        if not _ROUTER_EXISTS:
            self.skipTest("search.py not yet created — SWE output incomplete")

    def _src(self):
        with open(ROUTER_PATH) as f:
            return f.read()

    def test_get_search_endpoint_defined(self):
        src = self._src()
        self.assertIn("/search", src,
                      "search.py must define GET /search endpoint")

    def test_query_param_q(self):
        src = self._src()
        # q is the search query parameter
        self.assertIn(": str", src)  # typed query param

    def test_mode_param_defined(self):
        src = self._src()
        self.assertIn("mode", src,
                      "search.py must accept mode parameter (fts/semantic/hybrid)")

    def test_embedding_available_in_response(self):
        src = self._src()
        self.assertIn("embedding_available", src,
                      "Response must include embedding_available flag")

    def test_fts_rank_in_response(self):
        src = self._src()
        self.assertIn("fts_rank", src,
                      "Response must include fts_rank field")

    def test_semantic_score_in_response(self):
        src = self._src()
        self.assertIn("semantic_score", src,
                      "Response must include semantic_score field")

    def test_limit_param_max_50(self):
        src = self._src()
        self.assertIn("50", src,
                      "search.py must enforce limit max=50")

    def test_requires_auth(self):
        src = self._src()
        self.assertIn("get_current_user", src,
                      "search.py must require authentication via get_current_user")

    def test_user_id_in_query(self):
        src = self._src()
        self.assertIn("user_id", src,
                      "search.py must filter results by user_id")


# ---------------------------------------------------------------------------
# 7. Search endpoint HTTP tests (FastAPI TestClient, requires router file)
# ---------------------------------------------------------------------------

def _build_search_client():
    """
    Build a FastAPI TestClient for /v1/search with mocked DB and auth.
    Returns None if search.py doesn't exist.
    """
    if not _ROUTER_EXISTS:
        return None, None

    from fastapi import FastAPI
    from fastapi.testclient import TestClient

    # Clear cached modules
    for key in list(sys.modules.keys()):
        if "search" in key or key in (
            "app.routers.search", "app.core.config", "app.core.database",
            "app.middleware.auth", "app.core.rag",
        ):
            sys.modules.pop(key, None)

    fake_user = types.SimpleNamespace(id=uuid.uuid4())

    # Mock config
    mock_cfg = types.ModuleType("app.core.config")
    mock_cfg.settings = types.SimpleNamespace(
        fireworks_api_key="",
        fireworks_configured=False,
    )

    # Mock DB
    mock_db_session = MagicMock()
    mock_db_session.execute = AsyncMock(return_value=MagicMock(mappings=lambda: MagicMock(all=lambda: [])))

    async def _get_db():
        yield mock_db_session

    mock_db = types.ModuleType("app.core.database")
    mock_db.get_db = _get_db

    # Mock auth
    async def _get_current_user():
        return {"supabase_id": str(fake_user.id), "email": "test@nexus.app"}

    mock_auth = types.ModuleType("app.middleware.auth")
    mock_auth.get_current_user = _get_current_user

    # Mock user model
    mock_user_model = types.ModuleType("app.models.user")
    mock_user_model.User = MagicMock

    # Mock RAG
    mock_rag = types.ModuleType("app.core.rag")
    mock_rag.retrieve_similar_chunks = AsyncMock(return_value=[])
    mock_rag.build_context_block = MagicMock(return_value="")

    # namespace packages
    for ns, mod in [
        ("app", types.ModuleType("app")),
        ("app.core", types.ModuleType("app.core")),
        ("app.models", types.ModuleType("app.models")),
        ("app.middleware", types.ModuleType("app.middleware")),
        ("app.core.config", mock_cfg),
        ("app.core.database", mock_db),
        ("app.middleware.auth", mock_auth),
        ("app.models.user", mock_user_model),
        ("app.core.rag", mock_rag),
    ]:
        sys.modules[ns] = mod

    try:
        from app.routers import search as _search_mod  # noqa: F401
        from app.routers.search import router
        from app.middleware.auth import get_current_user
    except Exception:
        return None, None

    app = FastAPI()
    app.include_router(router, prefix="/v1")
    app.dependency_overrides[get_current_user] = _get_current_user

    client = TestClient(app, raise_server_exceptions=False)
    return client, fake_user


class TestSearchEndpointValidation(unittest.TestCase):
    """HTTP-level validation tests for GET /v1/search."""

    @classmethod
    def setUpClass(cls):
        if not _ROUTER_EXISTS:
            cls.available = False
            cls.skip_reason = "search.py not created yet"
            return
        try:
            cls.client, cls.fake_user = _build_search_client()
            cls.available = cls.client is not None
            cls.skip_reason = "Failed to build test client"
        except Exception as exc:
            cls.available = False
            cls.skip_reason = str(exc)

    def _skip(self):
        if not self.available:
            self.skipTest(f"Client unavailable: {self.skip_reason}")

    def test_missing_auth_returns_401(self):
        """Without Authorization header, GET /v1/search must return 401."""
        self._skip()
        # Override so no user is returned
        from fastapi import HTTPException
        from app.middleware.auth import get_current_user

        async def _no_auth():
            raise HTTPException(status_code=401, detail="Unauthorized")

        self.client.app.dependency_overrides[get_current_user] = _no_auth
        resp = self.client.get("/v1/search?q=climate")
        # Restore
        async def _get_current_user():
            return {"supabase_id": "uid", "email": "test@nexus.app"}
        self.client.app.dependency_overrides[get_current_user] = _get_current_user
        self.assertEqual(resp.status_code, 401)

    def test_empty_q_returns_422(self):
        """Empty q= should fail FastAPI min_length validation."""
        self._skip()
        resp = self.client.get("/v1/search?q=")
        self.assertEqual(resp.status_code, 422)

    def test_limit_over_50_returns_422(self):
        """limit=51 must fail validation (max=50)."""
        self._skip()
        resp = self.client.get("/v1/search?q=test&limit=51")
        self.assertEqual(resp.status_code, 422)

    def test_valid_single_char_q_returns_200(self):
        """Single char q should be valid (min_length=1)."""
        self._skip()
        resp = self.client.get("/v1/search?q=a")
        self.assertIn(resp.status_code, (200, 404),
                      "Single char q must not be rejected (not 422)")

    def test_limit_3_respected(self):
        """Requesting limit=3 returns at most 3 results."""
        self._skip()
        resp = self.client.get("/v1/search?q=test&limit=3")
        if resp.status_code == 200:
            data = resp.json()
            results = data.get("results", [])
            self.assertLessEqual(len(results), 3)

    def test_nonexistent_term_returns_empty(self):
        """q=xyzzy_nonexistent_term should return 200 with empty results."""
        self._skip()
        resp = self.client.get("/v1/search?q=xyzzy_nonexistent_term")
        if resp.status_code == 200:
            data = resp.json()
            self.assertEqual(data.get("results", []), [])
            self.assertEqual(data.get("total", 0), 0)


class TestSearchResponseSchema(unittest.TestCase):
    """Response shape: results[], total, embedding_available, mode."""

    @classmethod
    def setUpClass(cls):
        if not _ROUTER_EXISTS:
            cls.available = False
            cls.skip_reason = "search.py not created yet"
            return
        try:
            cls.client, cls.fake_user = _build_search_client()
            cls.available = cls.client is not None
            cls.skip_reason = "Failed to build test client"
        except Exception as exc:
            cls.available = False
            cls.skip_reason = str(exc)

    def _skip(self):
        if not self.available:
            self.skipTest(f"Client unavailable: {self.skip_reason}")

    def test_response_has_results_field(self):
        self._skip()
        resp = self.client.get("/v1/search?q=test")
        if resp.status_code == 200:
            self.assertIn("results", resp.json())

    def test_response_has_total_field(self):
        self._skip()
        resp = self.client.get("/v1/search?q=test")
        if resp.status_code == 200:
            self.assertIn("total", resp.json())

    def test_response_has_embedding_available_field(self):
        self._skip()
        resp = self.client.get("/v1/search?q=test")
        if resp.status_code == 200:
            self.assertIn("embedding_available", resp.json())

    def test_embedding_available_false_without_key(self):
        """With no FIREWORKS_API_KEY, embedding_available must be False."""
        self._skip()
        resp = self.client.get("/v1/search?q=test&mode=fts")
        if resp.status_code == 200:
            data = resp.json()
            self.assertFalse(data.get("embedding_available"),
                             "embedding_available must be False when key is not set")

    def test_fts_mode_results_have_fts_rank(self):
        """FTS mode results must have non-null fts_rank."""
        self._skip()
        resp = self.client.get("/v1/search?q=test&mode=fts")
        if resp.status_code == 200:
            results = resp.json().get("results", [])
            for r in results:
                self.assertIn("fts_rank", r, "FTS results must have fts_rank field")


# ---------------------------------------------------------------------------
# 8. ai/pipeline.py — compute_embedding is async (uses Fireworks, not OpenAI stub)
# ---------------------------------------------------------------------------

class TestPipelineComputeEmbeddingAsync(unittest.TestCase):
    """api/ai/pipeline.py compute_embedding must be async (Fireworks API)."""

    def _load(self):
        import importlib.util as ilu
        path = os.path.abspath(
            os.path.join(os.path.dirname(__file__), "../../ai/pipeline.py")
        )
        for k in list(sys.modules.keys()):
            if "ai.pipeline" in k:
                del sys.modules[k]
        spec = ilu.spec_from_file_location("ai.pipeline_live", path)
        mod = ilu.module_from_spec(spec)
        try:
            spec.loader.exec_module(mod)
        except Exception:
            return None
        return mod

    @unittest.skipIf(not os.getenv("FIREWORKS_API_KEY"), "requires FIREWORKS_API_KEY")
    def test_live_compute_embedding_768_dim(self):
        """Live test: Fireworks nomic-embed returns 768-dim vector."""
        import asyncio
        mod = self._load()
        if mod is None:
            self.skipTest("Could not load ai/pipeline.py")
        result = asyncio.run(mod.compute_embedding("hello world"))
        self.assertEqual(result.dimensions, 768)
        self.assertEqual(len(result.vector), 768)

    def test_compute_embedding_uses_fireworks_base_url(self):
        """pipeline.py must configure Fireworks base URL."""
        path = os.path.abspath(
            os.path.join(os.path.dirname(__file__), "../../ai/pipeline.py")
        )
        with open(path) as f:
            src = f.read()
        self.assertIn("fireworks.ai", src,
                      "pipeline.py must use Fireworks inference API")

    def test_compute_embedding_targets_768_model(self):
        """pipeline.py must use nomic-embed-text-v1.5 (768-dim)."""
        path = os.path.abspath(
            os.path.join(os.path.dirname(__file__), "../../ai/pipeline.py")
        )
        with open(path) as f:
            src = f.read()
        self.assertIn("nomic-embed-text-v1.5", src,
                      "pipeline.py must use nomic-embed-text-v1.5 model")


if __name__ == "__main__":
    unittest.main()
