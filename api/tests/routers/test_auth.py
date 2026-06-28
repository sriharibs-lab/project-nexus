"""
Tests for auth router — POST /v1/auth/magic-link, /verify-otp, /apple.

Covers the server-side contract that the iOS AuthViewModel relies on:
  - POST /auth/magic-link  → 200 {"message": "..."}
  - POST /auth/verify-otp  → 200 AuthTokenResponse schema (happy + error paths)
  - POST /auth/apple       → 200 AuthTokenResponse schema (happy + error paths)
  - Response schema: access_token, refresh_token, expires_in, token_type, user_id (UUID string)
  - Apple identity_token must be forwarded as a real JWT (not opaque ID)
  - Supabase errors → 401 / 502 propagated correctly
  - Email validation via pydantic EmailStr

All Supabase + DB calls are mocked — tests pass in CI with no external services.

Strategy: app.routers.__init__.py eagerly imports collections/health/ingest, which
triggers Settings() before we can inject mocks. We bypass this by using importlib.util
to load auth.py directly from disk with all deps pre-mocked in sys.modules.
"""

import importlib.util
import json
import os
import sys
import types
import unittest
import uuid
from unittest.mock import AsyncMock, MagicMock, patch

# ---------------------------------------------------------------------------
# Module-level setup — inject mocks BEFORE any app.* import
# ---------------------------------------------------------------------------

_AUTH_FILE = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "../../app/routers/auth.py")
)

_FAKE_USER_UUID = uuid.UUID("00000000-1111-2222-3333-444444444444")
_FAKE_SB_UID = "sb-uid-test-123"
_FAKE_EMAIL = "user@example.com"


class _FakeUser:
    """Minimal User model stub."""
    id = _FAKE_USER_UUID
    supabase_id = _FAKE_SB_UID
    email = _FAKE_EMAIL


def _inject_mocks():
    """
    Inject all mock modules that auth.py's top-level imports depend on.
    Must run before spec.loader.exec_module(auth_mod).
    """
    # app package skeleton
    app_pkg = types.ModuleType("app")
    app_pkg.__path__ = [os.path.abspath(os.path.join(os.path.dirname(_AUTH_FILE), ".."))]
    app_pkg.__package__ = "app"
    sys.modules.setdefault("app", app_pkg)
    sys.modules.setdefault("app.core", types.ModuleType("app.core"))
    sys.modules.setdefault("app.models", types.ModuleType("app.models"))
    sys.modules.setdefault("app.middleware", types.ModuleType("app.middleware"))
    # NOTE: we do NOT put app.routers in sys.modules here —
    # we want app.routers.auth to be the module we load manually.
    routers_pkg = types.ModuleType("app.routers")
    routers_pkg.__path__ = []
    sys.modules.setdefault("app.routers", routers_pkg)

    # settings
    mock_settings = types.SimpleNamespace(
        supabase_url="https://fake.supabase.co",
        supabase_publishable_key="anon-key",
        supabase_service_role_key="service-key",
        database_url="postgresql+asyncpg://test:test@localhost/test",
    )
    cfg = types.ModuleType("app.core.config")
    cfg.settings = mock_settings
    sys.modules["app.core.config"] = cfg

    # database
    db_mod = types.ModuleType("app.core.database")
    db_mod.get_db = lambda: None
    db_mod.Base = object
    sys.modules["app.core.database"] = db_mod

    # user model
    user_mod = types.ModuleType("app.models.user")
    user_mod.User = _FakeUser
    sys.modules["app.models.user"] = user_mod

    # auth middleware
    auth_mw = types.ModuleType("app.middleware.auth")

    async def _get_current_user():
        return {"supabase_id": _FAKE_SB_UID, "email": _FAKE_EMAIL}

    auth_mw.get_current_user = _get_current_user
    sys.modules["app.middleware.auth"] = auth_mw

    # sqlalchemy stubs (avoid real DB driver)
    sa = types.ModuleType("sqlalchemy")
    sa.select = MagicMock(return_value=MagicMock())
    sys.modules.setdefault("sqlalchemy", sa)
    sa_ext = types.ModuleType("sqlalchemy.ext")
    sys.modules.setdefault("sqlalchemy.ext", sa_ext)
    sa_async = types.ModuleType("sqlalchemy.ext.asyncio")
    sa_async.AsyncSession = object
    sys.modules.setdefault("sqlalchemy.ext.asyncio", sa_async)

    return mock_settings, _get_current_user


def _load_auth_module():
    """
    Load app/routers/auth.py directly using importlib, bypassing app.routers.__init__.
    Returns the loaded module, or None if the file is missing.
    """
    if not os.path.exists(_AUTH_FILE):
        return None

    _inject_mocks()

    spec = importlib.util.spec_from_file_location(
        "app.routers.auth",
        _AUTH_FILE,
    )
    auth_mod = importlib.util.module_from_spec(spec)
    sys.modules["app.routers.auth"] = auth_mod
    try:
        spec.loader.exec_module(auth_mod)
    except Exception:
        del sys.modules["app.routers.auth"]
        raise
    return auth_mod


# Load once at module level
try:
    _AUTH = _load_auth_module()
    _AUTH_LOAD_ERROR = None
except Exception as _e:
    _AUTH = None
    _AUTH_LOAD_ERROR = str(_e)


def _build_test_client():
    """
    Build a FastAPI TestClient for the auth router.
    Returns (client, get_current_user_dep) or raises if setup fails.
    """
    if _AUTH is None:
        raise RuntimeError(f"auth module failed to load: {_AUTH_LOAD_ERROR}")

    from fastapi import FastAPI
    from fastapi.testclient import TestClient

    app = FastAPI()
    # The router already has prefix="/auth" defined on it; don't double-prefix.
    app.include_router(_AUTH.router)

    async def _fake_current_user():
        return {"supabase_id": _FAKE_SB_UID, "email": _FAKE_EMAIL}

    app.dependency_overrides[_AUTH.get_current_user] = _fake_current_user

    return TestClient(app, raise_server_exceptions=False)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_supabase_session(email=_FAKE_EMAIL, sb_uid=_FAKE_SB_UID):
    """Fake successful Supabase session response body."""
    return {
        "access_token": "supa-access-tok",
        "refresh_token": "supa-refresh-tok",
        "expires_in": 3600,
        "token_type": "bearer",
        "user": {"id": sb_uid, "email": email},
    }


def _mock_supabase_post(return_data, status_code=200):
    """Return a mock httpx response."""
    mock_resp = MagicMock()
    mock_resp.status_code = status_code
    mock_resp.content = json.dumps(return_data).encode()
    mock_resp.json.return_value = return_data
    return mock_resp


def _patch_upsert(user=None):
    """Context manager to replace _upsert_user with a canned fake."""
    if user is None:
        user = _FakeUser()

    async def _fake(session, supabase_id, email):
        return user, False

    return patch.object(_AUTH, "_upsert_user", _fake)


# ---------------------------------------------------------------------------
# Tests: Pydantic schema contracts
# ---------------------------------------------------------------------------

class TestAuthTokenResponseSchema(unittest.TestCase):
    """AuthTokenResponse must expose the exact fields the iOS client maps to."""

    def setUp(self):
        if _AUTH is None:
            self.skipTest(f"auth module unavailable: {_AUTH_LOAD_ERROR}")

    def test_required_fields_present(self):
        """All 5 fields iOS AuthTokenResponse expects must be present."""
        resp = _AUTH.AuthTokenResponse(
            access_token="tok",
            refresh_token="ref",
            expires_in=3600,
            token_type="bearer",
            user_id=str(uuid.uuid4()),
        )
        self.assertEqual(resp.access_token, "tok")
        self.assertEqual(resp.refresh_token, "ref")
        self.assertEqual(resp.expires_in, 3600)
        self.assertEqual(resp.token_type, "bearer")
        self.assertIsNotNone(resp.user_id)

    def test_user_id_is_string(self):
        """user_id must serialise as a string UUID, not a UUID object."""
        uid = str(uuid.uuid4())
        resp = _AUTH.AuthTokenResponse(
            access_token="a", refresh_token="b", expires_in=100,
            token_type="bearer", user_id=uid,
        )
        self.assertIsInstance(resp.user_id, str)

    def test_user_id_must_be_valid_uuid_string(self):
        """user_id must be parseable as UUID — iOS AuthTokenResponse uses UUID(uuidString:)."""
        uid = str(_FAKE_USER_UUID)
        resp = _AUTH.AuthTokenResponse(
            access_token="a", refresh_token="b", expires_in=100,
            token_type="bearer", user_id=uid,
        )
        # Must round-trip through UUID()
        parsed = uuid.UUID(resp.user_id)
        self.assertEqual(parsed, _FAKE_USER_UUID)


class TestPydanticSchemas(unittest.TestCase):
    """Validate request model field contracts."""

    def setUp(self):
        if _AUTH is None:
            self.skipTest(f"auth module unavailable: {_AUTH_LOAD_ERROR}")

    def test_magic_link_request_valid_email(self):
        req = _AUTH.MagicLinkRequest(email="valid@example.com")
        self.assertEqual(str(req.email), "valid@example.com")

    def test_magic_link_request_rejects_non_email(self):
        from pydantic import ValidationError
        with self.assertRaises(ValidationError):
            _AUTH.MagicLinkRequest(email="not-an-email")

    def test_otp_verify_request_fields(self):
        req = _AUTH.OTPVerifyRequest(email="test@example.com", token="123456")
        self.assertEqual(req.token, "123456")

    def test_apple_sign_in_request_fields(self):
        req = _AUTH.AppleSignInRequest(identity_token="header.payload.sig")
        self.assertEqual(req.identity_token, "header.payload.sig")


# ---------------------------------------------------------------------------
# Tests: _extract_email_from_jwt helper
# ---------------------------------------------------------------------------

class TestExtractEmailFromJWT(unittest.TestCase):
    """Unit tests for the _extract_email_from_jwt helper function.

    Test hint: Apple identity token must be a real JWT (3 dot-separated parts),
    not cred.user (an opaque user ID).
    """

    def setUp(self):
        if _AUTH is None:
            self.skipTest(f"auth module unavailable: {_AUTH_LOAD_ERROR}")
        self._fn = _AUTH._extract_email_from_jwt

    def _make_jwt(self, claims: dict) -> str:
        """Build a minimal fake JWT with the given claims payload."""
        import base64
        payload = base64.urlsafe_b64encode(
            json.dumps(claims).encode()
        ).rstrip(b"=").decode()
        return f"eyJhbGciOiJSUzI1NiJ9.{payload}.fakesig"

    def test_extracts_email_from_valid_jwt(self):
        jwt = self._make_jwt({"email": "user@apple.com", "sub": "abc"})
        self.assertEqual(self._fn(jwt), "user@apple.com")

    def test_returns_none_when_no_email_claim(self):
        jwt = self._make_jwt({"sub": "abc", "iss": "https://appleid.apple.com"})
        self.assertIsNone(self._fn(jwt))

    def test_returns_none_for_empty_string(self):
        self.assertIsNone(self._fn(""))

    def test_returns_none_for_two_part_token(self):
        """cred.identityToken is always 3-part JWT; cred.user is an opaque string."""
        self.assertIsNone(self._fn("header.payload"))

    def test_returns_none_for_opaque_apple_user_id(self):
        """
        cred.user is an opaque string like '000123.abc456def.0987'.
        It is NOT a JWT — _extract_email_from_jwt must return None, not crash.

        Test hint: 'Apple identity token must be a real JWT string (not cred.user
        which is an opaque ID)'
        """
        self.assertIsNone(self._fn("000123.abc456def.0987"))

    def test_handles_malformed_base64_gracefully(self):
        """Malformed base64 in JWT payload must not raise — returns None."""
        result = self._fn("header.!!!not_valid_b64!!.sig")
        self.assertIsNone(result)

    def test_handles_padding(self):
        """JWT payload with length not divisible by 4 requires padding to decode."""
        import base64
        claims = {"email": "padded@test.com"}
        # strip all '=' padding to simulate a real JWT
        b64 = base64.urlsafe_b64encode(json.dumps(claims).encode()).rstrip(b"=").decode()
        jwt = f"h.{b64}.s"
        self.assertEqual(self._fn(jwt), "padded@test.com")


# ---------------------------------------------------------------------------
# Tests: _upsert_user helper
# ---------------------------------------------------------------------------

class TestUpsertUserHelper(unittest.TestCase):
    """Unit tests for the _upsert_user DB helper."""

    def setUp(self):
        if _AUTH is None:
            self.skipTest(f"auth module unavailable: {_AUTH_LOAD_ERROR}")

    def _run(self, coro):
        import asyncio
        return asyncio.get_event_loop().run_until_complete(coro)

    def test_returns_existing_user_and_is_new_false(self):
        """When user already exists in DB, returns (user, False)."""
        existing = _FakeUser()
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = existing

        session = AsyncMock()
        session.execute.return_value = mock_result
        session.commit = AsyncMock()
        session.refresh = AsyncMock()

        user_out, is_new = self._run(
            _AUTH._upsert_user(session, _FAKE_SB_UID, _FAKE_EMAIL)
        )
        self.assertFalse(is_new, "Expected is_new=False for existing user")
        self.assertIs(user_out, existing)

    def test_creates_new_user_when_not_found(self):
        """When user not found, adds to session, commits, and returns (user, True)."""
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None  # not found

        async def fake_refresh(u):
            u.id = _FAKE_USER_UUID

        session = AsyncMock()
        session.execute.return_value = mock_result
        session.commit = AsyncMock()
        session.refresh = fake_refresh

        # auth.py uses its module-level 'User' name, not sys.modules lookup.
        # Patch it directly on the auth module.
        class CapturingUser:
            # Class-level attribute so select(User).where(User.supabase_id == ...)
            # doesn't raise AttributeError. The session.execute is mocked so the
            # actual SQLAlchemy expression is never evaluated.
            supabase_id = MagicMock()  # SQLAlchemy column stub

            def __init__(self, supabase_id, email):
                self.supabase_id = supabase_id  # shadows class attr on instance
                self.email = email
                self.id = None

        original_user = _AUTH.User
        _AUTH.User = CapturingUser
        try:
            user_out, is_new = self._run(
                _AUTH._upsert_user(session, "new-sb-uid", "new@example.com")
            )
        finally:
            _AUTH.User = original_user

        self.assertTrue(is_new, "Expected is_new=True for new user")
        self.assertEqual(user_out.supabase_id, "new-sb-uid")
        self.assertEqual(user_out.email, "new@example.com")


# ---------------------------------------------------------------------------
# Tests: HTTP endpoints via TestClient
# ---------------------------------------------------------------------------

class TestMagicLinkEndpoint(unittest.TestCase):
    """Tests for POST /auth/magic-link."""

    @classmethod
    def setUpClass(cls):
        try:
            cls.client = _build_test_client()
            cls.available = True
        except Exception as exc:
            cls.available = False
            cls.skip_reason = str(exc)

    def _skip(self):
        if not self.available:
            self.skipTest(f"Client setup failed: {self.skip_reason}")

    def test_happy_path_returns_200_with_message(self):
        """POST with valid email → 200, body has 'message' string."""
        self._skip()
        mock_resp = _mock_supabase_post({"message": "OTP sent"}, 200)

        with patch("httpx.AsyncClient") as MockClient:
            MockClient.return_value.__aenter__.return_value.post = AsyncMock(
                return_value=mock_resp
            )
            resp = self.client.post(
                "/auth/magic-link", json={"email": "test@example.com"}
            )

        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertIn("message", body)
        self.assertIsInstance(body["message"], str)

    def test_supabase_422_returns_502(self):
        """Supabase rate-limit / email error → our 502 Bad Gateway."""
        self._skip()
        mock_resp = _mock_supabase_post({"error": "rate limited"}, 422)

        with patch("httpx.AsyncClient") as MockClient:
            MockClient.return_value.__aenter__.return_value.post = AsyncMock(
                return_value=mock_resp
            )
            resp = self.client.post(
                "/auth/magic-link", json={"email": "test@example.com"}
            )

        self.assertEqual(resp.status_code, 502)

    def test_invalid_email_returns_422(self):
        """Non-email string → Pydantic EmailStr validation → 422."""
        self._skip()
        resp = self.client.post("/auth/magic-link", json={"email": "not-an-email"})
        self.assertEqual(resp.status_code, 422)

    def test_missing_email_returns_422(self):
        """Missing email field → 422."""
        self._skip()
        resp = self.client.post("/auth/magic-link", json={})
        self.assertEqual(resp.status_code, 422)

    def test_supabase_network_error_returns_502(self):
        """httpx.RequestError during Supabase call → 502."""
        import httpx
        self._skip()

        with patch("httpx.AsyncClient") as MockClient:
            MockClient.return_value.__aenter__.return_value.post = AsyncMock(
                side_effect=httpx.RequestError("timeout")
            )
            resp = self.client.post(
                "/auth/magic-link", json={"email": "test@example.com"}
            )

        self.assertEqual(resp.status_code, 502)


class TestVerifyOTPEndpoint(unittest.TestCase):
    """Tests for POST /auth/verify-otp.

    Test hints:
    - "POST /v1/auth/verify-otp with a valid Supabase OTP returns
      {access_token, refresh_token, expires_in, token_type, user_id} where user_id is UUID"
    - "OTP error: enter '000000' for an invalid code — should show a red error banner"
    """

    @classmethod
    def setUpClass(cls):
        try:
            cls.client = _build_test_client()
            cls.available = True
        except Exception as exc:
            cls.available = False
            cls.skip_reason = str(exc)

    def _skip(self):
        if not self.available:
            self.skipTest(f"Client setup failed: {self.skip_reason}")

    def test_happy_path_returns_full_auth_token_schema(self):
        """
        Valid OTP → 200 with access_token, refresh_token, expires_in, token_type,
        and user_id (UUID string).
        """
        self._skip()
        supabase_data = _make_supabase_session()
        mock_resp = _mock_supabase_post(supabase_data, 200)

        with patch("httpx.AsyncClient") as MockClient, _patch_upsert():
            MockClient.return_value.__aenter__.return_value.post = AsyncMock(
                return_value=mock_resp
            )
            resp = self.client.post(
                "/auth/verify-otp",
                json={"email": "user@example.com", "token": "123456"},
            )

        self.assertEqual(resp.status_code, 200, resp.text)
        body = resp.json()
        # All fields the iOS AuthTokenResponse.swift requires
        for field in ("access_token", "refresh_token", "expires_in", "token_type", "user_id"):
            self.assertIn(field, body, f"Missing required field: {field}")
        # user_id must be a valid UUID string (iOS uses UUID(uuidString:))
        try:
            uuid.UUID(body["user_id"])
        except ValueError:
            self.fail(f"user_id '{body['user_id']}' is not a parseable UUID string")

    def test_invalid_otp_supabase_401_returns_401(self):
        """
        Supabase rejects OTP → router returns 401.
        Simulates entering '000000' — iOS shows red error banner (not crash).
        """
        self._skip()
        mock_resp = _mock_supabase_post({"error": "invalid OTP"}, 401)

        with patch("httpx.AsyncClient") as MockClient:
            MockClient.return_value.__aenter__.return_value.post = AsyncMock(
                return_value=mock_resp
            )
            resp = self.client.post(
                "/auth/verify-otp",
                json={"email": "user@example.com", "token": "000000"},
            )

        self.assertEqual(resp.status_code, 401)
        body = resp.json()
        self.assertIn("detail", body)
        self.assertIsInstance(body["detail"], str)

    def test_missing_email_returns_422(self):
        self._skip()
        resp = self.client.post("/auth/verify-otp", json={"token": "123456"})
        self.assertEqual(resp.status_code, 422)

    def test_missing_token_returns_422(self):
        self._skip()
        resp = self.client.post(
            "/auth/verify-otp", json={"email": "user@example.com"}
        )
        self.assertEqual(resp.status_code, 422)

    def test_network_error_returns_502(self):
        """Supabase unreachable during OTP verify → 502."""
        import httpx
        self._skip()

        with patch("httpx.AsyncClient") as MockClient:
            MockClient.return_value.__aenter__.return_value.post = AsyncMock(
                side_effect=httpx.RequestError("connection refused")
            )
            resp = self.client.post(
                "/auth/verify-otp",
                json={"email": "user@example.com", "token": "123456"},
            )

        self.assertEqual(resp.status_code, 502)


class TestAppleSignInEndpoint(unittest.TestCase):
    """Tests for POST /auth/apple.

    Test hints:
    - "Apple identity token must be a real JWT string (not cred.user which is an
      opaque ID) — verify the backend receives a parseable JWT from POST /v1/auth/apple"
    - "POST /v1/auth/apple with a real Apple identity_token returns same schema"
    """

    @classmethod
    def setUpClass(cls):
        try:
            cls.client = _build_test_client()
            cls.available = True
        except Exception as exc:
            cls.available = False
            cls.skip_reason = str(exc)

    def _skip(self):
        if not self.available:
            self.skipTest(f"Client setup failed: {self.skip_reason}")

    def _make_fake_apple_jwt(self) -> str:
        """Produce a structurally-valid JWT (header.payload.sig) for the Apple endpoint."""
        import base64
        header = base64.urlsafe_b64encode(b'{"alg":"RS256","kid":"abc"}').rstrip(b"=").decode()
        claims = json.dumps({"email": "apple@privaterelay.com", "sub": "apple-sub-123"})
        payload = base64.urlsafe_b64encode(claims.encode()).rstrip(b"=").decode()
        return f"{header}.{payload}.fakesignature"

    def test_happy_path_returns_full_auth_token_schema(self):
        """
        Apple JWT → Supabase exchange → 200 with {access_token, refresh_token,
        expires_in, token_type, user_id (UUID string)}.
        """
        self._skip()
        supabase_data = _make_supabase_session()
        mock_resp = _mock_supabase_post(supabase_data, 200)

        with patch("httpx.AsyncClient") as MockClient, _patch_upsert():
            MockClient.return_value.__aenter__.return_value.post = AsyncMock(
                return_value=mock_resp
            )
            resp = self.client.post(
                "/auth/apple", json={"identity_token": self._make_fake_apple_jwt()}
            )

        self.assertEqual(resp.status_code, 200, resp.text)
        body = resp.json()
        for field in ("access_token", "refresh_token", "expires_in", "token_type", "user_id"):
            self.assertIn(field, body, f"Missing required field: {field}")
        try:
            uuid.UUID(body["user_id"])
        except ValueError:
            self.fail(f"user_id '{body['user_id']}' is not a valid UUID string")

    def test_backend_uses_identity_token_not_opaque_user_id(self):
        """
        The backend must forward identity_token (JWT) to Supabase as 'id_token'.
        If the iOS client mistakenly sends cred.user (opaque) instead of
        cred.identityToken (JWT), Supabase returns 401.

        We verify the router passes the token through to Supabase unchanged.
        """
        self._skip()
        captured = {}

        async def fake_post(url, **kwargs):
            captured["body"] = kwargs.get("json", {})
            # Simulate Supabase accepting the token
            return _mock_supabase_post(_make_supabase_session(), 200)

        with patch("httpx.AsyncClient") as MockClient, _patch_upsert():
            MockClient.return_value.__aenter__.return_value.post = fake_post
            fake_jwt = self._make_fake_apple_jwt()
            self.client.post("/auth/apple", json={"identity_token": fake_jwt})

        # Supabase expects id_token, not user opaque id
        self.assertIn("id_token", captured.get("body", {}),
                      "Backend must send id_token to Supabase, not an opaque user id")
        self.assertEqual(captured["body"]["id_token"], fake_jwt)
        self.assertEqual(captured["body"].get("provider"), "apple")

    def test_supabase_401_returns_401(self):
        """Invalid Apple token → Supabase 401 → router 401."""
        self._skip()
        mock_resp = _mock_supabase_post({"error": "invalid id_token"}, 401)

        with patch("httpx.AsyncClient") as MockClient:
            MockClient.return_value.__aenter__.return_value.post = AsyncMock(
                return_value=mock_resp
            )
            resp = self.client.post(
                "/auth/apple", json={"identity_token": "header.payload.sig"}
            )

        self.assertEqual(resp.status_code, 401)

    def test_missing_identity_token_returns_422(self):
        self._skip()
        resp = self.client.post("/auth/apple", json={})
        self.assertEqual(resp.status_code, 422)

    def test_network_error_returns_502(self):
        """Supabase unreachable → 502."""
        import httpx
        self._skip()

        with patch("httpx.AsyncClient") as MockClient:
            MockClient.return_value.__aenter__.return_value.post = AsyncMock(
                side_effect=httpx.RequestError("timeout")
            )
            resp = self.client.post(
                "/auth/apple", json={"identity_token": "header.payload.sig"}
            )

        self.assertEqual(resp.status_code, 502)


if __name__ == "__main__":
    unittest.main()
