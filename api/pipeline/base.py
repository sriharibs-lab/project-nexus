from dataclasses import dataclass, field
from enum import Enum
from typing import Optional


class ContentType(str, Enum):
    ARTICLE = "article"
    VIDEO = "video"
    PODCAST = "podcast"


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
