from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, HttpUrl

from app.middleware.auth import get_current_user
from app.queue.ingestion import enqueue_item

router = APIRouter(prefix="/ingest", tags=["ingest"])


class IngestRequest(BaseModel):
    url: HttpUrl
    content_type: str = "article"


class IngestResponse(BaseModel):
    job_id: str
    status: str
    message: str


@router.post("", status_code=status.HTTP_202_ACCEPTED, response_model=IngestResponse)
async def ingest_item(
    payload: IngestRequest,
    current_user: dict = Depends(get_current_user),
) -> IngestResponse:
    job_id = await enqueue_item(
        url=str(payload.url),
        content_type=payload.content_type,
        user_id=current_user["supabase_id"],
    )
    return IngestResponse(
        job_id=job_id,
        status="queued",
        message="Item queued for ingestion",
    )
