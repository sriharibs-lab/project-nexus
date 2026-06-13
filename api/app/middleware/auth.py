import httpx
from jose import JWTError, jwk, jwt
from fastapi import HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.config import settings

bearer_scheme = HTTPBearer(auto_error=False)

# Cached JWKS keys — fetched once on first request, reused thereafter
_jwks_cache: list[dict] | None = None


def _get_jwks_keys() -> list[dict]:
    global _jwks_cache
    if _jwks_cache is None:
        resp = httpx.get(settings.supabase_jwks_url, timeout=10)
        resp.raise_for_status()
        _jwks_cache = resp.json().get("keys", [])
    return _jwks_cache


def _decode_supabase_jwt(token: str) -> dict:
    try:
        header = jwt.get_unverified_header(token)
    except JWTError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Malformed token") from exc

    kid = header.get("kid")
    alg = header.get("alg", "ES256")
    keys = _get_jwks_keys()

    # Match by kid if present, otherwise try all keys
    candidates = [k for k in keys if k.get("kid") == kid] if kid else keys
    if not candidates:
        candidates = keys

    last_exc: Exception | None = None
    for key_data in candidates:
        try:
            public_key = jwk.construct(key_data)
            payload = jwt.decode(
                token,
                public_key,
                algorithms=[alg, "ES256", "RS256"],
                options={"verify_aud": False},
            )
            return payload
        except JWTError as exc:
            last_exc = exc
            continue

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired token",
    ) from last_exc


async def get_current_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = None,
) -> dict:
    """
    FastAPI dependency. Returns the decoded Supabase JWT payload.
    Attach as Depends(get_current_user) on any protected route.
    """
    if credentials is None:
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")
        token = auth_header.removeprefix("Bearer ").strip()
    else:
        token = credentials.credentials

    payload = _decode_supabase_jwt(token)

    supabase_user_id: str | None = payload.get("sub")
    if not supabase_user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token missing sub claim")

    return {"supabase_id": supabase_user_id, "email": payload.get("email"), "raw": payload}
