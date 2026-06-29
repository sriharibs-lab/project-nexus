"""
Auth router — Sign in with Apple + Magic link email auth.

Auth flow overview
------------------
POST /v1/auth/apple   — Apple Sign-In (primary, no Supabase dependency).
                        iOS sends Apple's identityToken (a short-lived JWT
                        signed by Apple's RS256 private keys).  The server:
                          1. Fetches Apple's public JWKS from appleid.apple.com
                          2. Verifies the token signature + expiry + audience
                        3. Upserts a User row keyed on Apple's stable sub claim
                          4. Issues a Nexus JWT (HS256, 30-day TTL) the iOS app
                             stores and presents as its bearer token on all calls.

POST /v1/auth/provision   — legacy: receive a Supabase JWT after Supabase
                            auth, upsert user in Nexus DB.
POST /v1/auth/magic-link  — proxy OTP email via Supabase Admin API.
GET  /v1/auth/me          — return current user's Nexus profile (JWT required).
POST /v1/auth/refresh     — proxy Supabase token refresh.

All protected routes accept a Nexus or Supabase bearer token.
"""

import logging
import uuid as uuid_mod
from datetime import datetime, timedelta, timezone
from typing import Optional

UTC = timezone.utc

import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from jose import JWTError, jwt as jose_jwt
from pydantic import BaseModel, EmailStr
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.middleware.auth import get_current_user
from app.models.user import User

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["auth"])

# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------


class AppleSignInRequest(BaseModel):
    identity_token: str                   # Apple-issued JWT (short-lived, ~10 min)
    user_id: str                          # Apple's stable opaque user identifier (sub claim)
    email: Optional[str] = None           # Only present on first sign-in; None on subsequent ones
    full_name: Optional[str] = None


class AppleSignInResponse(BaseModel):
    access_token: str     # Nexus-issued JWT (30-day TTL); use as bearer on all calls
    token_type: str = "bearer"
    expires_in: int       # seconds until expiry (30 days = 2592000)
    user: "UserProfile"
    is_new: bool


class MagicLinkRequest(BaseModel):
    email: EmailStr


class MagicLinkResponse(BaseModel):
    message: str


class TokenRefreshRequest(BaseModel):
    refresh_token: str


class TokenRefreshResponse(BaseModel):
    access_token: str
    refresh_token: str
    expires_in: int
    token_type: str


class UserProfile(BaseModel):
    id: str
    supabase_id: str
    email: str

    model_config = {"from_attributes": True}


class ProvisionResponse(BaseModel):
    user: UserProfile
    is_new: bool


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_SUPABASE_HEADERS = {
    "apikey": "",  # filled at call-site from settings
    "Content-Type": "application/json",
}


def _supabase_admin_headers() -> dict:
    """Headers for Supabase Admin (service_role) endpoints."""
    return {
        "apikey": settings.supabase_service_role_key,
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
        "Content-Type": "application/json",
    }


# ---------------------------------------------------------------------------
# Apple Sign-In JWT verification
# ---------------------------------------------------------------------------

_APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"
_APPLE_ISSUER = "https://appleid.apple.com"
_NEXUS_JWT_TTL_DAYS = 30
_NEXUS_JWT_ALGORITHM = "HS256"

# In-process JWKS cache: tuple(keys_list, fetched_at).
# Apple rotates keys infrequently; a 1-hour TTL is safe and avoids a network
# call on every sign-in while still picking up key rotations promptly.
_jwks_cache: Optional[tuple] = None  # tuple[list[dict], datetime] | None
_JWKS_CACHE_TTL = timedelta(hours=1)


async def _fetch_apple_jwks() -> list[dict]:
    """Return Apple's public JWKS, using an in-process cache to avoid repeated fetches."""
    global _jwks_cache
    now = datetime.now(UTC)
    if _jwks_cache and (now - _jwks_cache[1]) < _JWKS_CACHE_TTL:
        return _jwks_cache[0]

    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            resp = await client.get(_APPLE_JWKS_URL)
            resp.raise_for_status()
            keys: list[dict] = resp.json().get("keys", [])
        except Exception as exc:
            logger.error("Failed to fetch Apple JWKS: %s", exc)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Could not reach Apple's auth service — please try again",
            ) from exc

    _jwks_cache = (keys, now)
    return keys


async def _verify_apple_identity_token(identity_token: str) -> dict:
    """
    Verify an Apple identity token (JWT) against Apple's public JWKS.

    Returns the decoded payload on success.
    Raises HTTP 401 on any validation failure.

    Validation steps per Apple's documentation:
      1. Decode the token header to get the key ID (kid) and algorithm (alg).
      2. Fetch Apple's JWKS and find the matching key by kid.
      3. Decode + verify the signature, expiry, issuer, and audience (bundle ID).
    """
    # Step 1: peek at header without verifying yet (we need kid to choose the right key)
    try:
        header = jose_jwt.get_unverified_header(identity_token)
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Apple identity token — could not parse header",
        ) from exc

    kid = header.get("kid")
    alg = header.get("alg", "RS256")

    # Step 2: find the matching public key
    jwks = await _fetch_apple_jwks()
    key = next((k for k in jwks if k.get("kid") == kid), None)
    if key is None:
        # Key not in cache — could be a recent rotation; force-refresh and retry once
        global _jwks_cache
        _jwks_cache = None
        jwks = await _fetch_apple_jwks()
        key = next((k for k in jwks if k.get("kid") == kid), None)

    if key is None:
        logger.warning("Apple JWKS: no key with kid=%s in %d keys", kid, len(jwks))
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Apple identity token signed with unknown key",
        )

    # Step 3: verify signature, expiry, issuer, audience
    audience = settings.apple_app_bundle_id or None  # skip audience check if not configured
    try:
        options: dict = {"verify_aud": bool(audience)}
        payload = jose_jwt.decode(
            identity_token,
            key,
            algorithms=[alg],
            audience=audience,
            issuer=_APPLE_ISSUER,
            options=options,
        )
    except JWTError as exc:
        logger.warning("Apple identity token verification failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Apple identity token is invalid or expired",
        ) from exc

    return payload


def _issue_nexus_jwt(nexus_user_id: uuid_mod.UUID, apple_sub: str) -> tuple[str, int]:
    """
    Issue a Nexus-signed HS256 JWT the iOS client uses as its bearer token.

    Payload mirrors the shape get_current_user() already extracts from Supabase
    tokens so all protected routes work unchanged:
      sub         → Apple's stable user identifier (used as supabase_id in the DB)
      nexus_uid   → Nexus DB user UUID (for direct queries if needed)
      aud         → "authenticated" (same as Supabase tokens)
      iss         → "nexus"
    """
    ttl_seconds = _NEXUS_JWT_TTL_DAYS * 24 * 3600
    now = datetime.now(UTC)
    payload = {
        "sub": apple_sub,
        "nexus_uid": str(nexus_user_id),
        "aud": "authenticated",
        "iss": "nexus",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(seconds=ttl_seconds)).timestamp()),
    }
    token = jose_jwt.encode(payload, settings.supabase_secret_key, algorithm=_NEXUS_JWT_ALGORITHM)
    return token, ttl_seconds


async def _upsert_user(session: AsyncSession, supabase_id: str, email: str) -> tuple[User, bool]:
    """
    Upsert a user by supabase_id.  Returns (user, is_new).
    Uses a SELECT-then-INSERT pattern for clarity and SQLAlchemy compatibility.
    """
    result = await session.execute(select(User).where(User.supabase_id == supabase_id))
    user = result.scalar_one_or_none()

    if user is not None:
        # Sync email in case user changed it in Supabase
        if user.email != email:
            user.email = email
            await session.commit()
            await session.refresh(user)
        return user, False

    user = User(supabase_id=supabase_id, email=email)
    session.add(user)
    await session.commit()
    await session.refresh(user)
    logger.info("Provisioned new user supabase_id=%s", supabase_id)
    return user, True


async def _upsert_apple_user(
    session: AsyncSession,
    apple_sub: str,
    email: Optional[str],
) -> tuple:
    """
    Upsert a user identified by Apple's stable `sub` claim.

    Apple only provides the email on the very first sign-in.  On subsequent
    sign-ins the email field is None.  We handle this by:
      - New user + no email: use a derived placeholder so the NOT NULL constraint
        is satisfied.  When Apple supplies the email on first sign-in we use it.
      - Existing user + no email: keep the email we already have.
      - Existing user + new email: update (user may have changed privacy relay).

    `apple_sub` is stored in the supabase_id column, which already has a unique
    index — no schema changes required.
    """
    result = await session.execute(select(User).where(User.supabase_id == apple_sub))
    user = result.scalar_one_or_none()

    if user is not None:
        # Existing user — update email if Apple provided one
        if email and user.email != email:
            user.email = email
            await session.commit()
            await session.refresh(user)
        return user, False

    # New user
    resolved_email = email or f"apple_{apple_sub}@privaterelay.appleid.com"
    user = User(supabase_id=apple_sub, email=resolved_email)
    session.add(user)
    await session.commit()
    await session.refresh(user)
    logger.info("Provisioned new Apple Sign-In user apple_sub=%s", apple_sub)
    return user, True


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@router.post(
    "/apple",
    response_model=AppleSignInResponse,
    status_code=status.HTTP_200_OK,
    summary="Sign in with Apple — server-side identity token verification",
)
async def sign_in_with_apple(
    payload: AppleSignInRequest,
    db: AsyncSession = Depends(get_db),
) -> AppleSignInResponse:
    """
    POST /v1/auth/apple

    Called by the iOS client immediately after Apple's ASAuthorization succeeds.
    The client sends Apple's identityToken (NOT the raw user identifier) so we
    can verify it cryptographically.

    Request:
        {
          "identity_token": "<Apple JWT>",
          "user_id": "<Apple opaque user ID — stable across re-installs>",
          "email": "<user email — only present on first sign-in>",
          "full_name": "<display name — only present on first sign-in>"
        }

    Response:
        {
          "access_token": "<Nexus JWT>",
          "token_type": "bearer",
          "expires_in": 2592000,
          "user": { "id": "...", "supabase_id": "...", "email": "..." },
          "is_new": true
        }

    Security guarantees:
      - Apple's RS256 signature is verified against the live JWKS at
        https://appleid.apple.com/auth/keys (with 1-hour in-process cache).
      - Token expiry is enforced by python-jose.
      - `aud` is validated against APPLE_APP_BUNDLE_ID if that env var is set.
      - The raw Apple user identifier is NEVER accepted as a bearer token.
        Only a successfully verified Nexus JWT grants access to protected routes.
    """
    # Verify the Apple identity token — raises HTTP 401 on failure
    apple_payload = await _verify_apple_identity_token(payload.identity_token)

    # Extract the stable subject claim
    apple_sub: Optional[str] = apple_payload.get("sub")
    if not apple_sub:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Apple identity token missing sub claim",
        )

    # Cross-check: the sub in the JWT must match the user_id from the iOS SDK
    if apple_sub != payload.user_id:
        logger.warning(
            "Apple sub mismatch: jwt_sub=%s ios_user_id=%s",
            apple_sub,
            payload.user_id,
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Identity token sub does not match provided user_id",
        )

    # Email from the JWT takes precedence (more reliable than the iOS field)
    email = apple_payload.get("email") or payload.email

    # Upsert the user record
    user, is_new = await _upsert_apple_user(db, apple_sub, email)

    # Issue a Nexus JWT the iOS app will use as its bearer token
    access_token, expires_in = _issue_nexus_jwt(user.id, apple_sub)

    logger.info(
        "Apple Sign-In success apple_sub=%s nexus_user_id=%s is_new=%s",
        apple_sub,
        user.id,
        is_new,
    )

    return AppleSignInResponse(
        access_token=access_token,
        expires_in=expires_in,
        user=UserProfile.model_validate(user),
        is_new=is_new,
    )


@router.post("/provision", response_model=ProvisionResponse, status_code=status.HTTP_200_OK)
async def provision_user(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ProvisionResponse:
    """
    Called by the iOS client immediately after a successful Supabase sign-in
    (Apple or magic link).  Upserts the user in the Nexus DB and returns the
    Nexus user profile.

    The Supabase access_token in the Authorization header is verified by
    get_current_user before this handler runs.
    """
    supabase_id: str = current_user["supabase_id"]
    email: Optional[str] = current_user.get("email")

    if not email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Supabase token missing email claim — ensure email scope is enabled",
        )

    user, is_new = await _upsert_user(db, supabase_id, email)
    return ProvisionResponse(user=UserProfile.model_validate(user), is_new=is_new)


@router.post(
    "/magic-link",
    response_model=MagicLinkResponse,
    status_code=status.HTTP_200_OK,
)
async def send_magic_link(payload: MagicLinkRequest) -> MagicLinkResponse:
    """
    Request a magic-link / OTP email via Supabase Admin API.

    Keeping this server-side means the Supabase service_role key never ships
    in the iOS binary — only the anon key needs to be on-device (for reading
    public data), and sign-in calls go through our API.

    Supabase endpoint: POST /auth/v1/otp
    """
    url = f"{settings.supabase_url}/auth/v1/otp"

    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            resp = await client.post(
                url,
                json={"email": payload.email, "create_user": True},
                headers=_supabase_admin_headers(),
            )
            if resp.status_code not in (200, 204):
                # Supabase may return 422 for rate-limit or invalid email
                body = resp.json() if resp.content else {}
                logger.warning(
                    "Supabase OTP request failed status=%s body=%s",
                    resp.status_code,
                    body,
                )
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="Could not send magic link — please try again",
                )
        except httpx.RequestError as exc:
            logger.error("Supabase OTP network error: %s", exc)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Could not reach auth service — please try again",
            ) from exc

    return MagicLinkResponse(message="Magic link sent — check your email")


@router.post("/refresh", response_model=TokenRefreshResponse, status_code=status.HTTP_200_OK)
async def refresh_token(payload: TokenRefreshRequest) -> TokenRefreshResponse:
    """
    Proxy Supabase token refresh.  Keeps the service_role key server-side;
    the iOS client only stores the refresh_token (not the service key).

    Supabase endpoint: POST /auth/v1/token?grant_type=refresh_token
    """
    url = f"{settings.supabase_url}/auth/v1/token"
    headers = {
        "apikey": settings.supabase_publishable_key,
        "Content-Type": "application/json",
    }

    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            resp = await client.post(
                url,
                params={"grant_type": "refresh_token"},
                json={"refresh_token": payload.refresh_token},
                headers=headers,
            )
            if resp.status_code != 200:
                body = resp.json() if resp.content else {}
                logger.warning(
                    "Supabase token refresh failed status=%s body=%s",
                    resp.status_code,
                    body,
                )
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Token refresh failed — please sign in again",
                )
            data = resp.json()
        except httpx.RequestError as exc:
            logger.error("Supabase refresh network error: %s", exc)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Could not reach auth service — please try again",
            ) from exc

    return TokenRefreshResponse(
        access_token=data["access_token"],
        refresh_token=data["refresh_token"],
        expires_in=data["expires_in"],
        token_type=data.get("token_type", "bearer"),
    )


@router.get("/me", response_model=UserProfile, status_code=status.HTTP_200_OK)
async def get_me(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> UserProfile:
    """
    Return the authenticated user's Nexus profile.
    Returns 404 if the user exists in Supabase but hasn't been provisioned
    (iOS client should call /provision first).
    """
    supabase_id: str = current_user["supabase_id"]
    result = await db.execute(select(User).where(User.supabase_id == supabase_id))
    user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found — call /auth/provision after sign-in",
        )

    return UserProfile.model_validate(user)
