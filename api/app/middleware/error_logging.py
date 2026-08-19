"""Global error telemetry wiring.

We register exception *handlers* (not a BaseHTTPMiddleware) on purpose: the
research/chat endpoints return StreamingResponse, and BaseHTTPMiddleware has a
history of buffering/breaking SSE. Handlers sit outside the streaming path.

Two nets:
  • unhandled Exception  → HTTP 500, recorded as level=error, source="http"
  • StarletteHTTPException with status >= 500 → recorded (explicit 5xx)

Routine 4xx (401/404/422) are intentionally NOT recorded — they're client
noise. The failures that actually matter here (an AI provider 400 *inside* a
200 SSE stream) are captured at the call site via record_error(), because no
HTTP-status net can see them.
"""

import logging

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.telemetry import record_error

logger = logging.getLogger(__name__)


def install_error_telemetry(app: FastAPI) -> None:
    @app.exception_handler(Exception)
    async def _unhandled(request: Request, exc: Exception) -> JSONResponse:
        logger.exception("Unhandled exception on %s %s", request.method, request.url.path)
        await record_error(
            source="http",
            level="error",
            status_code=500,
            error_type=type(exc).__name__,
            message=str(exc) or type(exc).__name__,
            path=request.url.path,
            method=request.method,
        )
        return JSONResponse(status_code=500, content={"detail": "Internal Server Error"})

    @app.exception_handler(StarletteHTTPException)
    async def _http_exc(request: Request, exc: StarletteHTTPException) -> JSONResponse:
        if exc.status_code >= 500:
            await record_error(
                source="http",
                level="error",
                status_code=exc.status_code,
                error_type="HTTPException",
                message=str(exc.detail),
                path=request.url.path,
                method=request.method,
            )
        # Preserve default behaviour for the response itself (incl. 4xx).
        return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})
