from dataclasses import dataclass, field
from typing import Optional

# ContentType is defined once in app/models/item.py (the canonical location).
# Importing here so pipeline modules have a single source of truth and the
# ingest router routes correctly — a mismatched enum caused silent AI
# routing errors when item.py extended the values and base.py did not.
from app.models.item import ContentType  # noqa: F401 — re-exported for pipeline modules


@dataclass
class ExtractionResult:
    extractor: str
    url: str
    content_type: ContentType
    title: Optional[str]
    content: str
    word_count: int
    elapsed_ms: float
    # None = free/unknown; float = USD per call
    cost_usd: Optional[float]
    error: Optional[str] = None
    metadata: dict = field(default_factory=dict)

    @property
    def ok(self) -> bool:
        return self.error is None

    def preview(self, chars: int = 300) -> str:
        return self.content[:chars].replace("\n", " ").strip() + ("…" if len(self.content) > chars else "")
