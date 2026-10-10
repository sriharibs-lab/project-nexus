"""Create-tab artifact v2 helpers: infographic validator, TTS chunking, fal request build."""

import json
import os
import sys

import pytest

_API_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../"))
sys.path.insert(0, _API_DIR)

from ai import pipeline  # noqa: E402

_FIXTURES = json.load(open(os.path.join(os.path.dirname(__file__), "fixtures", "infographic_v2.json")))


# ── validate_infographic ───────────────────────────────────────────────────

def test_numbers_layout_truncates_validates_icons_and_pct():
    c = pipeline.validate_infographic(_FIXTURES["numbers"], "Nvidia")
    assert c["layout"] == "numbers"
    assert len(c["title"]) <= 48
    assert c["theme"] == "ocean"
    assert c["icon"] == "cpu.fill"
    assert c["hero"] == {"value": "$60.9B", "label": "FY2024 revenue"}
    assert len(c["takeaway"]) <= 110
    rows = c["numbers"]
    assert len(rows) == 6  # 7 valid items → capped at 6; the empty-value item dropped
    assert rows[0] == {"value": "$60.9B", "label": "FY2024 revenue", "icon": "banknote.fill", "pct": 100}
    assert rows[1]["pct"] is None
    assert rows[2]["icon"] == "cpu.fill"  # unknown symbol → falls back to the piece icon
    assert rows[2]["pct"] == 78
    assert rows[3]["pct"] == 100 and rows[4]["pct"] == 0  # clamped
    assert rows[5]["pct"] is None
    assert "timeline" not in c and "comparison" not in c


def test_timeline_layout_truncates_when_and_what_and_defaults_theme():
    c = pipeline.validate_infographic(_FIXTURES["timeline"], "Picasso")
    assert c["theme"] == "plum"  # unknown theme → plum
    assert c["hero"] is None
    assert c["subtitle"] == ""
    rows = c["timeline"]
    assert [r["when"] for r in rows] == ["1881", "1907", "1937–1939 Sp", ""]
    assert all(len(r["what"]) <= 64 for r in rows)
    assert rows[1]["icon"] == "paintpalette.fill"
    assert len(rows) == 4  # the item with no "what" is dropped


def test_comparison_layout_edges():
    c = pipeline.validate_infographic(_FIXTURES["comparison"], "Rust vs Go")
    comp = c["comparison"]
    assert comp["a"] == "Rust" and comp["b"] == "Go"
    assert [r["edge"] for r in comp["rows"]] == ["a", "b", None]
    assert len(comp["rows"]) == 3


def test_bad_layout_and_empty_section_raise():
    with pytest.raises(ValueError):
        pipeline.validate_infographic(_FIXTURES["bad_layout"], "x")
    with pytest.raises(ValueError):
        pipeline.validate_infographic(_FIXTURES["empty_numbers"], "x")


def test_icon_allowlist_matches_spec_count():
    assert len(pipeline._INFO_ICONS) == 49
    assert "sparkles" in pipeline._INFO_ICONS
    assert pipeline._icon("not.real") == "sparkles"


# ── split_for_tts ─────────────────────────────────────────────────────────

def test_split_for_tts_respects_limit_and_sentence_boundaries():
    script = " ".join(f"Sentence number {i} is here and it talks about something." for i in range(120))
    chunks = pipeline.split_for_tts(script, limit=1800)
    assert len(chunks) > 1
    assert all(len(c) <= 1800 for c in chunks)
    assert all(c.endswith(".") for c in chunks)
    # Nothing lost: rejoining gives back the original text.
    assert " ".join(chunks) == script


def test_split_for_tts_hard_wraps_pathological_sentence():
    chunks = pipeline.split_for_tts("word " * 1000, limit=100)
    assert all(len(c) <= 100 for c in chunks)
    assert "".join(c.replace(" ", "") for c in chunks) == "word" * 1000


# ── poster: fal request build (dry run, no network) ───────────────────────

def test_build_fal_request_requires_key(monkeypatch):
    monkeypatch.delenv("FAL_KEY", raising=False)
    monkeypatch.setattr(pipeline.settings, "fal_key", "")
    with pytest.raises(RuntimeError, match="not configured \\(FAL_KEY\\)"):
        pipeline.build_fal_request("x")


def test_build_fal_request_shape(monkeypatch):
    monkeypatch.setenv("FAL_KEY", "test-key-123")
    url, headers, body = pipeline.build_fal_request("a minimal poster")
    assert url == "https://fal.run/fal-ai/flux/schnell"
    assert headers["Authorization"] == "Key test-key-123"
    assert body == {
        "prompt": "a minimal poster",
        "image_size": "portrait_4_3",
        "num_inference_steps": 4,
        "num_images": 1,
        "enable_safety_checker": True,
        "output_format": "jpeg",
    }


@pytest.mark.asyncio
async def test_generate_poster_dry_run(monkeypatch):
    """Stub Fireworks brief, httpx and storage — assert the fal call + upload are correctly wired."""
    monkeypatch.setenv("FAL_KEY", "k")
    calls = {}

    async def fake_brief(name, ctx, style="editorial", instructions=None):
        return ({"headline": "H", "subline": "S", "prompt": "P", "style": style}, 10, 20)

    class FakeResp:
        def __init__(self, status_code, payload=None, content=b""):
            self.status_code, self._payload, self.content, self.text = status_code, payload, content, ""
        def json(self):
            return self._payload

    class FakeClient:
        def __init__(self, timeout=None):
            calls["timeout"] = timeout
        async def __aenter__(self):
            return self
        async def __aexit__(self, *a):
            return False
        async def post(self, url, headers=None, json=None):
            calls["post"] = (url, headers, json)
            return FakeResp(200, {"images": [{"url": "https://fal.tmp/x.jpg", "width": 768, "height": 1024}]})
        async def get(self, url):
            calls["get"] = url
            return FakeResp(200, content=b"\xff\xd8jpegbytes")

    async def fake_upload(path, data, content_type):
        calls["upload"] = (path, data, content_type)
        return f"https://cdn/{path}"

    import httpx
    import app.core.storage as storage
    monkeypatch.setattr(pipeline, "generate_poster_brief", fake_brief)
    monkeypatch.setattr(httpx, "AsyncClient", FakeClient)
    monkeypatch.setattr(storage, "upload_public", fake_upload)

    r = await pipeline.generate_poster("Coll", "ctx", artifact_id="abc", style="photo", instructions=None)
    assert calls["timeout"] == 120
    assert calls["post"][0] == "https://fal.run/fal-ai/flux/schnell"
    assert calls["post"][1]["Authorization"] == "Key k"
    assert calls["post"][2]["prompt"] == "P" and calls["post"][2]["output_format"] == "jpeg"
    assert calls["get"] == "https://fal.tmp/x.jpg"
    assert calls["upload"] == ("posters/abc.jpg", b"\xff\xd8jpegbytes", "image/jpeg")
    assert r.kind == "poster" and r.title == "H"
    assert r.content["image_url"] == "https://cdn/posters/abc.jpg"
    assert r.content["width"] == 768 and r.content["height"] == 1024 and r.content["style"] == "photo"
    assert r.model.endswith("+fal-ai/flux/schnell")
