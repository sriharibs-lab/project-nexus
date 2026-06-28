"""
Auth router — Sign in with Apple + Magic link email auth.

Auth flow overview
------------------
All Supabase credentials (service_role key, anon key) stay server-side.
The iOS client never touches Supabase directly.

Endpoints:
  POST /v1/auth/magic-link  — send OTP email via Supabase Admin API.
  POST /v1/auth/verify-otp  — verify 6-digit OTP, upsert Nexus user, return tokens + user_id.
  POST /v1/auth/apple       — exchange Apple identity token with Supabase, upsert user, return tokens.
  POST /v1/auth/provision   — (legacy) receive existing Supabase JWT, upsert user. Still valid.
  POST /v1/auth/refresh     — proxy Supabase token refresh.
  GET  /v1/auth/me          — return current user's Nexus profile (JWT required).

All protected routes accept a Bearer token (Supabase access_token).
"""

import logging

import httpx
from fastapi import APIRouter, Depends, HTTPException, status
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


class OTPVerifyRequest(BaseModel):
    email: EmailStr
    token: str  # 6-digit OTP from email


class AppleSignInRequest(BaseModel):
    identity_token: str  # JWT from ASAuthorizationAppleIDCredential.identityToken


class AuthTokenResponse(BaseModel):
    """Returned after a successful sign-in (OTP verify or Apple)."""

    access_token: str
    refresh_token: str
    expires_in: int
    token_type: str
    user_id: str  # Nexus DB UUID (str for JSON compat)


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


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


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
    email: str | None = current_user.get("email")

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


@router.post(
    "/verify-otp",
    response_model=AuthTokenResponse,
    status_code=status.HTTP_200_OK,
)
async def verify_otp(
    payload: OTPVerifyRequest,
    db: AsyncSession = Depends(get_db),
) -> AuthTokenResponse:
    """
    Verify a 6-digit OTP sent via magic link.

    Proxies Supabase POST /auth/v1/verify (type=email).
    On success: upserts the user in Nexus DB and returns session tokens + Nexus user_id.

    Keeping this server-side means neither the anon key nor service key ships in the iOS binary.
    Supabase endpoint: POST /auth/v1/verify
    """
    url = f"{settings.supabase_url}/auth/v1/verify"

    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            resp = await client.post(
                url,
                json={
                    "email": payload.email,
                    "token": payload.token,
                    "type": "email",
                },
                headers={
                    "apikey": settings.supabase_publishable_key,
                    "Content-Type": "application/json",
                },
            )
            if resp.status_code != 200:
                body = resp.json() if resp.content else {}
                logger.warning(
                    "Supabase OTP verify failed status=%s body=%s",
                    resp.status_code,
                    body,
                )
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid or expired code — please try again",
                )
            data = resp.json()
        except httpx.RequestError as exc:
            logger.error("Supabase verify-otp network error: %s", exc)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Could not reach auth service — please try again",
            ) from exc

    supabase_id: str = data.get("user", {}).get("id", "")
    email: str = data.get("user", {}).get("email", payload.email)

    user, _ = await _upsert_user(db, supabase_id, email)

    return AuthTokenResponse(
        access_token=data["access_token"],
        refresh_token=data["refresh_token"],
        expires_in=data.get("expires_in", 3600),
        token_type=data.get("token_type", "bearer"),
        user_id=str(user.id),
    )


@router.post(
    "/apple",
    response_model=AuthTokenResponse,
    status_code=status.HTTP_200_OK,
)
async def sign_in_with_apple(
    payload: AppleSignInRequest,
    db: AsyncSession = Depends(get_db),
) -> AuthTokenResponse:
    """
    Exchange an Apple identity token (JWT from ASAuthorizationAppleIDCredential)
    with Supabase to get a session.

    Supabase endpoint: POST /auth/v1/token?grant_type=id_token
    On success: upserts the user in Nexus DB and returns session tokens + Nexus user_id.

    Keeping this server-side means the Supabase anon key never ships in the iOS binary.
    """
    url = f"{settings.supabase_url}/auth/v1/token"

    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            resp = await client.post(
                url,
                params={"grant_type": "id_token"},
                json={
                    "id_token": payload.identity_token,
                    "provider": "apple",
                },
                headers={
                    "apikey": settings.supabase_publishable_key,
                    "Content-Type": "application/json",
                },
            )
            if resp.status_code != 200:
                body = resp.json() if resp.content else {}
                logger.warning(
                    "Supabase Apple sign-in failed status=%s body=%s",
                    resp.status_code,
                    body,
                )
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Apple sign-in failed — please try again",
                )
            data = resp.json()
        except httpx.RequestError as exc:
            logger.error("Supabase apple sign-in network error: %s", exc)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Could not reach auth service — please try again",
            ) from exc

    supabase_id: str = data.get("user", {}).get("id", "")
    email: str = data.get("user", {}).get("email", "")

    if not email:
        # Apple can hide the email — extract from token if present
        email = _extract_email_from_jwt(data.get("access_token", "")) or ""

    user, _ = await _upsert_user(db, supabase_id, email)

    return AuthTokenResponse(
        access_token=data["access_token"],
        refresh_token=data["refresh_token"],
        expires_in=data.get("expires_in", 3600),
        token_type=data.get("token_type", "bearer"),
        user_id=str(user.id),
    )


def _extract_email_from_jwt(token: str) -> str | None:
    """
    Best-effort: decode JWT payload (no signature verification) to get the email claim.
    Used only as a fallback when the Supabase response body omits the email.
    """
    import base64
    import json

    try:
        parts = token.split(".")
        if len(parts) != 3:
            return None
        # Add padding if needed
        padded = parts[1] + "=" * (-len(parts[1]) % 4)
        decoded = base64.urlsafe_b64decode(padded)
        claims = json.loads(decoded)
        return claims.get("email")
    except Exception:
        return None


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
