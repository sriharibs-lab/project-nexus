"""
Deepgram Nova-3 audio transcription (SDK v6).

Accepts any direct audio URL (MP3, WAV, M4A, OGG, FLAC).
Requires DEEPGRAM_API_KEY env var.

Pricing (as of 2025):
  nova-3: $0.0043/min  (~$0.26/hr of audio)
  nova-2: $0.0059/min  (~$0.35/hr)

Deepgram SDK v6 API:
  client.listen.v1.media.transcribe_url(url=..., model=..., **options)
  Returns: ListenV1Response → .results.channels[0].alternatives[0]
"""

import os
import time
from typing import Optional

from deepgram import DeepgramClient, ListenV1Response

from .base import ContentType, ExtractionResult

COST_PER_MINUTE_USD = 0.0043  # nova-3 pricing


def extract(audio_url: str, *, diarize: bool = True) -> ExtractionResult:
    api_key: Optional[str] = os.getenv("DEEPGRAM_API_KEY")
    if not api_key:
        return ExtractionResult(
            extractor="Deepgram Nova-3",
            url=audio_url,
            content_type=ContentType.PODCAST,
            title=None,
            content="",
            word_count=0,
            elapsed_ms=0,
            cost_usd=None,
            error="DEEPGRAM_API_KEY not set",
        )

    t0 = time.perf_counter()
    try:
        client = DeepgramClient(api_key=api_key)

        response = client.listen.v1.media.transcribe_url(
            url=audio_url,
            model="nova-3",
            smart_format=True,
            diarize=diarize,
            paragraphs=True,
            language="en",
            punctuate=True,
        )

        elapsed = (time.perf_counter() - t0) * 1000

        if not isinstance(response, ListenV1Response):
            raise ValueError(f"Unexpected callback/async response: {type(response)}")

        channel = response.results.channels[0].alternatives[0]

        # Build output with speaker-labeled paragraphs when diarized
        content = ""
        if diarize and channel.paragraphs and channel.paragraphs.paragraphs:
            lines = []
            for para in channel.paragraphs.paragraphs:
                speaker = f"[Speaker {para.speaker}] " if para.speaker is not None else ""
                text = " ".join(s.text for s in para.sentences)
                lines.append(f"{speaker}{text}")
            content = "\n\n".join(lines)
        else:
            content = channel.transcript or ""

        # Duration for cost calc — use last word's end time
        duration_s: float = 0.0
        if channel.words:
            duration_s = channel.words[-1].end or 0.0
        duration_min = duration_s / 60
        cost = round(duration_min * COST_PER_MINUTE_USD, 6)

        confidence = round(channel.confidence, 3) if channel.confidence is not None else None

        return ExtractionResult(
            extractor="Deepgram Nova-3",
            url=audio_url,
            content_type=ContentType.PODCAST,
            title=None,
            content=content,
            word_count=len(content.split()),
            elapsed_ms=elapsed,
            cost_usd=cost,
            metadata={
                "duration_seconds": round(duration_s, 1),
                "confidence": confidence,
                "model": "nova-3",
                "diarized": diarize,
            },
        )

    except Exception as exc:
        elapsed = (time.perf_counter() - t0) * 1000
        return ExtractionResult(
            extractor="Deepgram Nova-3",
            url=audio_url,
            content_type=ContentType.PODCAST,
            title=None,
            content="",
            word_count=0,
            elapsed_ms=elapsed,
            cost_usd=None,
            error=str(exc),
        )
