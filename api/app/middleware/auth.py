from jose import JWTError, jwt
from fastapi import HTTPException, Request, status

from app.core.config import settings

# Claims Supabase includes in every JWT
_SUPABASE_ALGORITHMS = ["HS256"]


def _decode_supabase_jwt(token: str) -> dict:
    try:
        payload = jwt.decode(
            token,
            settings.supabase_jwt_secret,
            algorithms=_SUPABASE_ALGORITHMS,
            audience="authenticated",
        )
        return payload
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        ) from exc


async def get_current_user(request: Request) -> dict:
    """
    FastAPI dependency. Returns the decoded Supabase JWT payload.
    Reads the bearer token exclusively from the Authorization header so that
    FastAPI does not treat this function as a second request-body source on
    POST routes (which would require a {"payload": {...}} wrapper instead of a
    flat JSON body).
    """
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")
    token = auth_header.removeprefix("Bearer ").strip()

    payload = _decode_supabase_jwt(token)

    supabase_user_id: str | None = payload.get("sub")
    if not supabase_user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token missing sub claim")

    return {"supabase_id": supabase_user_id, "email": payload.get("email"), "raw": payload}
