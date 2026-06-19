"""
Auth router — Sign in with Apple + Magic link email auth.

Auth flow overview
------------------
The iOS client delegates the full Supabase auth flow (Apple OAuth exchange,
magic-link OTP verification) to the Supabase client SDK.  After the SDK
completes, it hands the iOS app a short-lived Supabase access_token + refresh_token.

Our API then:
  POST /v1/auth/provision   — receive Supabase JWT, upsert user in Nexus DB,
                              return Nexus user profile.  Called after every
                              successful Supabase sign-in (Apple or magic link).
  POST /v1/auth/magic-link  — proxy: call Supabase Admin API to send OTP email.
                              Keeps the Supabase anon key out of the iOS app.
  GET  /v1/auth/me          — return current user's Nexus profile (JWT required).
  POST /v1/auth/refresh     — proxy Supabase token refresh (keeps anon key server-side).

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
