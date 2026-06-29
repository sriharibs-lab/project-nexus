"""
Tests for POST /v1/auth/apple — Apple Sign-In JWT exchange (1G-007).

Coverage:
- _upsert_apple_user: new user with email → stored as-is, is_new=True
- _upsert_apple_user: new user without email → placeholder email, is_new=True
- _upsert_apple_user: existing user, email=None → existing email preserved
- _upsert_apple_user: existing user, new email → email updated, commit called
- _issue_nexus_jwt: claims (sub, aud="authenticated", iss="nexus", nexus_uid) correct
- _issue_nexus_jwt: TTL is 30 days
- _issue_nexus_jwt: token decodable with same key + audience as auth middleware
- _verify_apple_identity_token: bad JWT format → 401
- _verify_apple_identity_token: unknown kid → 401
- _verify_apple_identity_token: valid mocked path → returns payload
- _verify_apple_identity_token: bundle ID empty → verify_aud=False passed to decode
"""

import json
import os
import sys
import types
import unittest
import uuid
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, patch

UTC = timezone.utc


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

def _make_settings_stub(bundle_id: str = "com.nexus.app"):
    return types.SimpleNamespace(
        supabase_secret_key="test-secret-key-at-least-32-chars!!",
        apple_app_bundle_id=bundle_id,
        supabase_url="https://stub.supabase.co",
        supabase_publishable_key="stub_pub",
        supabase_service_role_key="stub_svc",
    )


class FakeUser:
    # Class-level descriptor stub so `User.supabase_id == value` works in
    # SQLAlchemy where() expressions without a real ORM mapping.
    supabase_id = MagicMock()  # supports __eq__ without raising

    def __init__(self, supabase_id_val: str = "", email: str = "", **kwargs):
        self.id = uuid.uuid4()
        # Accept both positional supabase_id_val and keyword supabase_id
        self.supabase_id = kwargs.get("supabase_id", supabase_id_val)
        self.email = email


def _clear_auth_modules():
    """Remove all auth-related entries from sys.modules so we get a clean import."""
    keys_to_drop = [k for k in sys.modules if (
        k == "app" or k.startswith("app.") or
        k == "ai" or k.startswith("ai.")
    )]
    for k in keys_to_drop:
        sys.modules.pop(k, None)


def _inject_auth_stubs(bundle_id: str = "com.nexus.app") -> dict:
    """
    Inject minimal stubs into sys.modules so app.routers.auth can be imported
    without a real database, config file, or Supabase connection.
    Returns a dict with 'settings', 'FakeUser' for test assertions.
    """
    _clear_auth_modules()

    settings = _make_settings_stub(bundle_id)

    # Package stubs (must set __path__ for sub-imports to work)
    def _pkg(name, path_hint=None):
        m = types.ModuleType(name)
        m.__path__ = [path_hint or os.path.join(os.path.dirname(__file__), "..", "..", *name.split("."))]
        m.__package__ = name
        return m

    sys.modules["app"] = _pkg("app")
    sys.modules["app.core"] = _pkg("app.core")
    sys.modules["app.models"] = _pkg("app.models")
    sys.modules["app.middleware"] = _pkg("app.middleware")
    sys.modules["app.routers"] = _pkg("app.routers")

    # Config
    mock_cfg = types.ModuleType("app.core.config")
    mock_cfg.settings = settings
    sys.modules["app.core.config"] = mock_cfg

    # Database
    mock_db = types.ModuleType("app.core.database")

    class _FakeCtx:
        async def __aenter__(self): return MagicMock()
        async def __aexit__(self, *a): pass

    async def _get_db():
        yield MagicMock()

    mock_db.Base = object
    mock_db.get_db = _get_db
    mock_db.AsyncSessionLocal = _FakeCtx
    sys.modules["app.core.database"] = mock_db

    # Auth middleware
    mock_auth = types.ModuleType("app.middleware.auth")
    mock_auth.get_current_user = AsyncMock(return_value={"supabase_id": "stub", "email": "stub@nexus.app"})
    mock_auth.bearer_scheme = MagicMock()
    sys.modules["app.middleware.auth"] = mock_auth

    # User model
    mock_user_mod = types.ModuleType("app.models.user")
    mock_user_mod.User = FakeUser
    sys.modules["app.models.user"] = mock_user_mod

    return {"settings": settings}


# ---------------------------------------------------------------------------
# Tests for _upsert_apple_user
# ---------------------------------------------------------------------------

class TestUpsertAppleUser(unittest.IsolatedAsyncioTestCase):

    def setUp(self):
        _inject_auth_stubs()
        if "app.routers.auth" in sys.modules:
            sys.modules.pop("app.routers.auth")
        import app.routers.auth as _auth_mod
        self._auth_mod = _auth_mod
        self._fn = _auth_mod._upsert_apple_user

    def _make_session(self, existing_user=None):
        session = AsyncMock()
        session.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=lambda: existing_user)
        )
        session.add = MagicMock()
        session.commit = AsyncMock()
        session.refresh = AsyncMock()
        return session

    async def test_new_user_with_email_stored_correctly(self):
        session = self._make_session(existing_user=None)
        apple_sub = "001234.abc"
        email = "user@example.com"

        # Patch select on the module object to bypass SQLAlchemy introspection
        with patch.object(self._auth_mod, "select", return_value=MagicMock()):
            user, is_new = await self._fn(session, apple_sub, email)

        self.assertTrue(is_new)
        session.add.assert_called_once()
        added = session.add.call_args[0][0]
        self.assertEqual(added.supabase_id, apple_sub)
        self.assertEqual(added.email, email)

    async def test_new_user_without_email_gets_placeholder(self):
        session = self._make_session(existing_user=None)
        apple_sub = "001234.nomail"

        with patch.object(self._auth_mod, "select", return_value=MagicMock()):
            user, is_new = await self._fn(session, apple_sub, email=None)

        self.assertTrue(is_new)
        added = session.add.call_args[0][0]
        # Placeholder must contain apple_sub (uniqueness) and be a valid email shape
        self.assertIn(apple_sub, added.email)
        self.assertIn("@", added.email)

    async def test_existing_user_email_preserved_when_apple_returns_none(self):
        original_email = "original@example.com"
        existing = FakeUser(supabase_id_val="001234.existing", email=original_email)
        session = self._make_session(existing_user=existing)

        with patch.object(self._auth_mod, "select", return_value=MagicMock()):
            user, is_new = await self._fn(session, "001234.existing", email=None)

        self.assertFalse(is_new)
        # Email must not be wiped
        self.assertEqual(user.email, original_email)
        # No commit when email is unchanged
        session.commit.assert_not_called()

    async def test_existing_user_email_updated_when_apple_provides_new(self):
        existing = FakeUser(supabase_id_val="001234.update", email="old@relay.example.com")
        session = self._make_session(existing_user=existing)

        with patch.object(self._auth_mod, "select", return_value=MagicMock()):
            user, is_new = await self._fn(session, "001234.update", email="new@example.com")

        self.assertFalse(is_new)
        self.assertEqual(user.email, "new@example.com")
        session.commit.assert_called_once()


# ---------------------------------------------------------------------------
# Tests for _issue_nexus_jwt
# ---------------------------------------------------------------------------

class TestIssueNexusJwt(unittest.TestCase):

    def setUp(self):
        _inject_auth_stubs()
        if "app.routers.auth" in sys.modules:
            sys.modules.pop("app.routers.auth")

    def _get_fn(self):
        from app.routers.auth import _issue_nexus_jwt
        return _issue_nexus_jwt

    def test_jwt_contains_required_claims(self):
        from jose import jwt as jose_jwt

        fn = self._get_fn()
        nexus_uid = uuid.uuid4()
        apple_sub = "001234.claims_test"

        token, expires_in = fn(nexus_uid, apple_sub)

        secret = _make_settings_stub().supabase_secret_key
        payload = jose_jwt.decode(
            token, secret, algorithms=["HS256"], audience="authenticated"
        )
        self.assertEqual(payload["sub"], apple_sub)
        self.assertEqual(payload["aud"], "authenticated")
        self.assertEqual(payload["iss"], "nexus")
        self.assertEqual(payload["nexus_uid"], str(nexus_uid))

    def test_ttl_is_30_days(self):
        fn = self._get_fn()
        _, expires_in = fn(uuid.uuid4(), "001234.ttl")
        self.assertEqual(expires_in, 30 * 24 * 3600)

    def test_token_decodable_with_middleware_params(self):
        """
        The token must pass the IDENTICAL jose.jwt.decode call that auth middleware uses:
          jwt.decode(token, settings.supabase_secret_key,
                     algorithms=["HS256"], audience="authenticated")
        This ensures all protected routes accept the Apple-issued Nexus token.
        """
        from jose import jwt as jose_jwt

        fn = self._get_fn()
        token, _ = fn(uuid.uuid4(), "001234.middleware_compat")
        secret = _make_settings_stub().supabase_secret_key

        # This is exactly what auth middleware does
        payload = jose_jwt.decode(
            token, secret, algorithms=["HS256"], audience="authenticated"
        )
        self.assertIn("sub", payload)

    def test_token_has_sub_claim_matching_apple_sub(self):
        """Middleware uses payload['sub'] as supabase_id — must equal apple_sub."""
        from jose import jwt as jose_jwt

        fn = self._get_fn()
        apple_sub = "001234.sub_check"
        token, _ = fn(uuid.uuid4(), apple_sub)
        secret = _make_settings_stub().supabase_secret_key
        payload = jose_jwt.decode(
            token, secret, algorithms=["HS256"], audience="authenticated"
        )
        self.assertEqual(payload["sub"], apple_sub)


# ---------------------------------------------------------------------------
# Tests for _verify_apple_identity_token
# ---------------------------------------------------------------------------

class TestVerifyAppleIdentityToken(unittest.IsolatedAsyncioTestCase):

    def setUp(self):
        _inject_auth_stubs(bundle_id="com.nexus.app")
        if "app.routers.auth" in sys.modules:
            sys.modules.pop("app.routers.auth")

    async def test_bad_jwt_format_raises_401(self):
        import app.routers.auth as auth_mod
        from fastapi import HTTPException
        from jose import JWTError

        with patch.object(auth_mod, "jose_jwt") as mock_jwt:
            mock_jwt.get_unverified_header.side_effect = JWTError("bad format")

            with self.assertRaises(HTTPException) as ctx:
                await auth_mod._verify_apple_identity_token("not.a.jwt")
            self.assertEqual(ctx.exception.status_code, 401)

    async def test_unknown_kid_raises_401(self):
        import app.routers.auth as auth_mod
        from fastapi import HTTPException

        with patch.object(auth_mod, "jose_jwt") as mock_jwt:
            mock_jwt.get_unverified_header.return_value = {"kid": "unknown", "alg": "RS256"}
            with patch.object(auth_mod, "_fetch_apple_jwks", new=AsyncMock(return_value=[])):
                with self.assertRaises(HTTPException) as ctx:
                    await auth_mod._verify_apple_identity_token("h.p.s")
                self.assertEqual(ctx.exception.status_code, 401)

    async def test_valid_token_returns_payload(self):
        import app.routers.auth as auth_mod

        apple_sub = "001234.valid"
        fake_key = {"kid": "test_kid", "kty": "RSA"}
        fake_payload = {
            "sub": apple_sub,
            "email": "user@example.com",
            "iss": "https://appleid.apple.com",
            "aud": "com.nexus.app",
            "exp": int((datetime.now(UTC) + timedelta(hours=1)).timestamp()),
        }

        with patch.object(auth_mod, "jose_jwt") as mock_jwt:
            mock_jwt.get_unverified_header.return_value = {"kid": "test_kid", "alg": "RS256"}
            mock_jwt.decode.return_value = fake_payload
            with patch.object(auth_mod, "_fetch_apple_jwks", new=AsyncMock(return_value=[fake_key])):
                result = await auth_mod._verify_apple_identity_token("h.p.s")

        self.assertEqual(result["sub"], apple_sub)

    async def test_bundle_id_empty_skips_audience_check(self):
        """When APPLE_APP_BUNDLE_ID is unset, verify_aud must be False."""
        _inject_auth_stubs(bundle_id="")  # no bundle ID
        if "app.routers.auth" in sys.modules:
            sys.modules.pop("app.routers.auth")

        import app.routers.auth as auth_mod

        fake_key = {"kid": "kid2", "kty": "RSA"}
        fake_payload = {"sub": "001234.no_aud", "iss": "https://appleid.apple.com"}

        with patch.object(auth_mod, "jose_jwt") as mock_jwt:
            mock_jwt.get_unverified_header.return_value = {"kid": "kid2", "alg": "RS256"}
            mock_jwt.decode.return_value = fake_payload
            with patch.object(auth_mod, "_fetch_apple_jwks", new=AsyncMock(return_value=[fake_key])):
                result = await auth_mod._verify_apple_identity_token("h.p.s")

        call_kwargs = mock_jwt.decode.call_args.kwargs
        verify_aud = call_kwargs.get("options", {}).get("verify_aud", True)
        self.assertFalse(verify_aud, "verify_aud should be False when bundle_id is empty")

    async def test_expired_token_raises_401(self):
        import app.routers.auth as auth_mod
        from fastapi import HTTPException
        from jose import JWTError

        fake_key = {"kid": "kid3", "kty": "RSA"}

        with patch.object(auth_mod, "jose_jwt") as mock_jwt:
            mock_jwt.get_unverified_header.return_value = {"kid": "kid3", "alg": "RS256"}
            mock_jwt.decode.side_effect = JWTError("Signature has expired")
            with patch.object(auth_mod, "_fetch_apple_jwks", new=AsyncMock(return_value=[fake_key])):
                with self.assertRaises(HTTPException) as ctx:
                    await auth_mod._verify_apple_identity_token("h.p.s")
                self.assertEqual(ctx.exception.status_code, 401)


if __name__ == "__main__":
    unittest.main()
