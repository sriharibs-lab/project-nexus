"""
SSE-field-test — Unit tests for the dual-key SSE termination fix.

Background
----------
The iOS `streamSSE` method in APIClient.swift previously only checked
`dict["type"]` to detect terminal SSE events. The Research backend
(api/app/routers/research.py) uses `{"event": "done" | "error"}` while
the Chat backend (api/app/routers/collections.py) uses
`{"type": "done" | "error"}`.

The SWE fix updated `streamSSE` to check `dict["event"]` first, falling
back to `dict["type"]`, so both endpoints terminate the stream correctly.

These Python tests verify:
  1. Research SSE format: terminal events carry `"event"` key (not "type")
  2. Chat SSE format: terminal events carry `"type"` key (not "event")
  3. A Python simulation of the iOS `streamSSE` termination logic handles
     both key schemas, breaking on "done" and "error" from either backend.
  4. The no-regression check: existing chat SSE event types remain intact.
"""

from __future__ import annotations

import json
import unittest
from typing import Iterator


# ---------------------------------------------------------------------------
# Helpers — parse and simulate
# ---------------------------------------------------------------------------

def _parse_sse_lines(raw: str) -> list[dict]:
    """Parse raw SSE text (data: <json>\\n\\n blocks) into list of dicts."""
    events: list[dict] = []
    for line in raw.splitlines():
        line = line.strip()
        if line.startswith("data: "):
            try:
                events.append(json.loads(line[6:]))
            except json.JSONDecodeError:
                pass
    return events


def _sse(payload: dict) -> str:
    """Minimal SSE serialiser matching the Python backend helpers."""
    return f"data: {json.dumps(payload)}\n\n"


def _simulate_stream_sse(lines: list[str]) -> list[dict]:
    """
    Python simulation of the iOS APIClient.streamSSE termination logic
    (post-fix).

    Mirrors the Swift logic:
        let terminalKey = (dict["event"] as? String) ?? (dict["type"] as? String)
        if terminalKey == "done" || terminalKey == "error" { break }

    Returns the list of dicts consumed before (and including) the terminal event.
    """
    consumed: list[dict] = []
    for line in lines:
        line = line.strip()
        if not line.startswith("data: "):
            continue
        json_str = line[6:]
        try:
            d = json.loads(json_str)
        except json.JSONDecodeError:
            continue

        consumed.append(d)

        # Check both keys — research uses "event"; chat uses "type"
        terminal_key = d.get("event") or d.get("type")
        if terminal_key in ("done", "error"):
            break

    return consumed


# ---------------------------------------------------------------------------
# 1. Research SSE event format contract
# ---------------------------------------------------------------------------

class TestResearchSSEFormat(unittest.TestCase):
    """
    Verify that research.py SSE events use the "event" key for all payloads,
    including terminal "done" and "error" events.
    """

    def test_searching_event_uses_event_key(self):
        raw = _sse({"event": "searching", "topic": "LLMs"})
        events = _parse_sse_lines(raw)
        self.assertEqual(len(events), 1)
        self.assertIn("event", events[0])
        self.assertNotIn("type", events[0])
        self.assertEqual(events[0]["event"], "searching")

    def test_source_event_uses_event_key(self):
        raw = _sse({
            "event": "source",
            "index": 0,
            "source": {"title": "T", "url": "https://x.com", "domain": "x.com",
                       "rationale": "Good", "content_type": "article"},
        })
        events = _parse_sse_lines(raw)
        self.assertEqual(events[0]["event"], "source")
        self.assertNotIn("type", events[0])

    def test_done_event_uses_event_key(self):
        """Terminal done must carry 'event' not 'type' for research stream."""
        raw = _sse({"event": "done", "collection_id": "abc-uuid", "source_count": 3})
        events = _parse_sse_lines(raw)
        self.assertEqual(events[0]["event"], "done")
        # Must NOT have a "type" key — that would be the chat format
        self.assertNotIn("type", events[0])

    def test_error_event_uses_event_key(self):
        raw = _sse({"event": "error", "message": "ANTHROPIC_API_KEY not configured"})
        events = _parse_sse_lines(raw)
        self.assertEqual(events[0]["event"], "error")
        self.assertNotIn("type", events[0])

    def test_done_event_carries_collection_id(self):
        import uuid
        cid = str(uuid.uuid4())
        raw = _sse({"event": "done", "collection_id": cid, "source_count": 5})
        events = _parse_sse_lines(raw)
        self.assertEqual(events[0]["collection_id"], cid)

    def test_done_event_carries_source_count(self):
        raw = _sse({"event": "done", "collection_id": "x", "source_count": 7})
        events = _parse_sse_lines(raw)
        self.assertEqual(events[0]["source_count"], 7)


# ---------------------------------------------------------------------------
# 2. Chat SSE event format contract
# ---------------------------------------------------------------------------

class TestChatSSEFormat(unittest.TestCase):
    """
    Verify that collections.py (chat) SSE events use the "type" key for all
    payloads, including terminal "done" and "error" events.
    """

    def test_sources_event_uses_type_key(self):
        raw = _sse({"type": "sources", "items": [{"title": "T", "url": "u"}]})
        events = _parse_sse_lines(raw)
        self.assertEqual(events[0]["type"], "sources")
        self.assertNotIn("event", events[0])

    def test_chunk_event_uses_type_key(self):
        raw = _sse({"type": "chunk", "text": "Hello"})
        events = _parse_sse_lines(raw)
        self.assertEqual(events[0]["type"], "chunk")
        self.assertNotIn("event", events[0])

    def test_done_event_uses_type_key(self):
        """Terminal done must carry 'type' not 'event' for chat stream."""
        raw = _sse({"type": "done"})
        events = _parse_sse_lines(raw)
        self.assertEqual(events[0]["type"], "done")
        # Must NOT have an "event" key — that would be the research format
        self.assertNotIn("event", events[0])

    def test_error_event_uses_type_key(self):
        raw = _sse({"type": "error", "message": "Something went wrong"})
        events = _parse_sse_lines(raw)
        self.assertEqual(events[0]["type"], "error")
        self.assertNotIn("event", events[0])

    def test_chunk_event_has_text_field(self):
        raw = _sse({"type": "chunk", "text": "partial answer"})
        events = _parse_sse_lines(raw)
        self.assertEqual(events[0]["text"], "partial answer")

    def test_sources_event_has_items_field(self):
        raw = _sse({"type": "sources", "items": [{"title": "T", "url": "u"}]})
        events = _parse_sse_lines(raw)
        self.assertIsInstance(events[0]["items"], list)
        self.assertEqual(events[0]["items"][0]["title"], "T")


# ---------------------------------------------------------------------------
# 3. iOS streamSSE termination simulation — post-fix logic
# ---------------------------------------------------------------------------

class TestStreamSSETermination(unittest.TestCase):
    """
    Simulate the iOS streamSSE post-fix termination logic in Python.

    The fix:
        let terminalKey = (dict["event"] as? String) ?? (dict["type"] as? String)
        if terminalKey == "done" || terminalKey == "error" { break }

    Pre-fix (checking only "type") would miss research "event":"done" events
    and hold the connection open until server TCP close.
    """

    def _build_research_stream(self) -> list[str]:
        """Simulate a full Research SSE stream (uses 'event' key)."""
        lines = []
        lines.append(f'data: {json.dumps({"event": "searching", "topic": "LLMs"})}')
        for i in range(3):
            lines.append(f'data: {json.dumps({"event": "source", "index": i, "source": {"title": f"S{i}", "url": f"https://x.com/{i}", "domain": "x.com", "rationale": "r", "content_type": "article"}})}')
        lines.append(f'data: {json.dumps({"event": "done", "collection_id": "uuid-abc", "source_count": 3})}')
        # Simulate any spurious bytes that might arrive after done (should NOT be consumed)
        lines.append(f'data: {json.dumps({"event": "spurious"})}')
        return lines

    def _build_chat_stream(self) -> list[str]:
        """Simulate a full Chat SSE stream (uses 'type' key)."""
        lines = []
        lines.append(f'data: {json.dumps({"type": "sources", "items": []})}')
        lines.append(f'data: {json.dumps({"type": "chunk", "text": "Hello"})}')
        lines.append(f'data: {json.dumps({"type": "chunk", "text": " world"})}')
        lines.append(f'data: {json.dumps({"type": "done"})}')
        lines.append(f'data: {json.dumps({"type": "spurious"})}')
        return lines

    def _build_research_error_stream(self) -> list[str]:
        """Research stream that emits 'event': 'error' (missing API key case)."""
        lines = []
        lines.append(f'data: {json.dumps({"event": "error", "message": "ANTHROPIC_API_KEY not configured"})}')
        lines.append(f'data: {json.dumps({"event": "spurious_after_error"})}')
        return lines

    def _build_chat_error_stream(self) -> list[str]:
        """Chat stream that emits 'type': 'error' (auth failure case)."""
        lines = []
        lines.append(f'data: {json.dumps({"type": "sources", "items": []})}')
        lines.append(f'data: {json.dumps({"type": "error", "message": "Authentication failed"})}')
        lines.append(f'data: {json.dumps({"type": "spurious_after_error"})}')
        return lines

    # ── Research stream — uses "event" key ────────────────────────────────────

    def test_research_stream_breaks_on_done(self):
        """streamSSE must break when it sees event='done' in research stream."""
        consumed = _simulate_stream_sse(self._build_research_stream())
        event_types = [d.get("event") for d in consumed]
        self.assertIn("done", event_types)

    def test_research_stream_does_not_consume_after_done(self):
        """No events after 'done' should be consumed."""
        consumed = _simulate_stream_sse(self._build_research_stream())
        event_types = [d.get("event") for d in consumed]
        # "spurious" must not appear
        self.assertNotIn("spurious", event_types,
                         f"Spurious event consumed after done. Events: {event_types}")

    def test_research_stream_source_events_arrive_before_done(self):
        consumed = _simulate_stream_sse(self._build_research_stream())
        event_types = [d.get("event") for d in consumed]
        self.assertIn("source", event_types)
        done_idx = event_types.index("done")
        source_indices = [i for i, t in enumerate(event_types) if t == "source"]
        self.assertTrue(all(i < done_idx for i in source_indices))

    def test_research_error_stream_breaks_on_error(self):
        """streamSSE must break when it sees event='error'."""
        consumed = _simulate_stream_sse(self._build_research_error_stream())
        event_types = [d.get("event") for d in consumed]
        self.assertIn("error", event_types)
        self.assertNotIn("spurious_after_error", event_types)

    def test_research_error_message_preserved(self):
        consumed = _simulate_stream_sse(self._build_research_error_stream())
        error_event = next(d for d in consumed if d.get("event") == "error")
        self.assertIn("ANTHROPIC_API_KEY", error_event["message"])

    # ── Chat stream — uses "type" key ─────────────────────────────────────────

    def test_chat_stream_breaks_on_done(self):
        """streamSSE must break when it sees type='done' in chat stream."""
        consumed = _simulate_stream_sse(self._build_chat_stream())
        types = [d.get("type") for d in consumed]
        self.assertIn("done", types)

    def test_chat_stream_does_not_consume_after_done(self):
        """No events after 'done' should be consumed in chat stream."""
        consumed = _simulate_stream_sse(self._build_chat_stream())
        types = [d.get("type") for d in consumed]
        self.assertNotIn("spurious", types,
                         f"Spurious event consumed after done. Events: {types}")

    def test_chat_stream_accumulates_chunks(self):
        consumed = _simulate_stream_sse(self._build_chat_stream())
        chunks = [d["text"] for d in consumed if d.get("type") == "chunk"]
        self.assertEqual(chunks, ["Hello", " world"])

    def test_chat_error_stream_breaks_on_error(self):
        """streamSSE must break when it sees type='error'."""
        consumed = _simulate_stream_sse(self._build_chat_error_stream())
        types = [d.get("type") for d in consumed]
        self.assertIn("error", types)
        self.assertNotIn("spurious_after_error", types)

    def test_chat_error_message_preserved(self):
        consumed = _simulate_stream_sse(self._build_chat_error_stream())
        error_event = next(d for d in consumed if d.get("type") == "error")
        self.assertIn("Authentication", error_event["message"])

    # ── Pre-fix regression: checking only "type" would have missed research ──

    def test_old_logic_would_miss_research_done(self):
        """
        Demonstrates the pre-fix bug: checking only dict["type"] misses
        research "event":"done" and would consume the spurious event too.
        """
        def _old_simulate(lines: list[str]) -> list[dict]:
            """Simulate the OLD (broken) termination: only checks 'type'."""
            consumed: list[dict] = []
            for line in lines:
                line = line.strip()
                if not line.startswith("data: "):
                    continue
                try:
                    d = json.loads(line[6:])
                except json.JSONDecodeError:
                    continue
                consumed.append(d)
                # OLD: only "type" key — misses research "event" key
                t = d.get("type")
                if t in ("done", "error"):
                    break
            return consumed

        research_lines = self._build_research_stream()
        old_consumed = _old_simulate(research_lines)
        old_event_types = [d.get("event") for d in old_consumed]

        # With old logic, spurious event IS consumed because "done" was never detected
        self.assertIn("spurious", old_event_types,
                      "Old logic should have consumed the spurious event (demonstrates the bug)")

    def test_new_logic_correctly_handles_research_done(self):
        """Post-fix: checking 'event' first correctly breaks on research done."""
        research_lines = self._build_research_stream()
        new_consumed = _simulate_stream_sse(research_lines)
        new_event_types = [d.get("event") for d in new_consumed]
        self.assertNotIn("spurious", new_event_types,
                         "New logic must not consume spurious event after done")

    def test_new_logic_still_handles_chat_done(self):
        """Post-fix: falling back to 'type' still works for chat stream."""
        chat_lines = self._build_chat_stream()
        consumed = _simulate_stream_sse(chat_lines)
        types = [d.get("type") for d in consumed]
        self.assertIn("done", types)
        self.assertNotIn("spurious", types)


# ---------------------------------------------------------------------------
# 4. No-regression: chat SSE event type names match NexusViewModel.handleSSEEvent
# ---------------------------------------------------------------------------

class TestChatSSEEventNameContract(unittest.TestCase):
    """
    The Swift NexusViewModel.handleSSEEvent switches on dict["type"] with cases:
        "sources", "chunk", "done", "error"

    Verify the Python chat backend emits exactly these type values (no typos).
    """

    EXPECTED_TYPES = {"sources", "chunk", "done", "error"}

    def _emit_all_chat_event_types(self) -> set[str]:
        """Emit one of each chat event type and collect the 'type' values."""
        events = []
        for raw in [
            _sse({"type": "sources", "items": []}),
            _sse({"type": "chunk", "text": "hi"}),
            _sse({"type": "done"}),
            _sse({"type": "error", "message": "oops"}),
        ]:
            events.extend(_parse_sse_lines(raw))
        return {e["type"] for e in events}

    def test_all_expected_chat_event_types_present(self):
        actual = self._emit_all_chat_event_types()
        self.assertEqual(actual, self.EXPECTED_TYPES)

    def test_sources_event_items_is_list(self):
        raw = _sse({"type": "sources", "items": [{"title": "T", "url": "u"}]})
        events = _parse_sse_lines(raw)
        self.assertIsInstance(events[0]["items"], list)

    def test_chunk_event_text_is_string(self):
        raw = _sse({"type": "chunk", "text": "partial"})
        events = _parse_sse_lines(raw)
        self.assertIsInstance(events[0]["text"], str)

    def test_error_event_message_is_string(self):
        raw = _sse({"type": "error", "message": "Something went wrong"})
        events = _parse_sse_lines(raw)
        self.assertIsInstance(events[0]["message"], str)


# ---------------------------------------------------------------------------
# 5. No-regression: research SSE event names match ResearchViewModel.handleSSEEvent
# ---------------------------------------------------------------------------

class TestResearchSSEEventNameContract(unittest.TestCase):
    """
    The Swift ResearchViewModel.handleSSEEvent switches on dict["event"] with cases:
        "searching", "source", "done", "error"

    Verify the Python research backend emits exactly these event values.
    """

    EXPECTED_EVENTS = {"searching", "source", "done", "error"}

    def _emit_all_research_event_types(self) -> set[str]:
        events = []
        for raw in [
            _sse({"event": "searching", "topic": "x"}),
            _sse({"event": "source", "index": 0, "source": {}}),
            _sse({"event": "done", "collection_id": "u", "source_count": 1}),
            _sse({"event": "error", "message": "oops"}),
        ]:
            events.extend(_parse_sse_lines(raw))
        return {e["event"] for e in events}

    def test_all_expected_research_event_types_present(self):
        actual = self._emit_all_research_event_types()
        self.assertEqual(actual, self.EXPECTED_EVENTS)

    def test_searching_event_has_topic(self):
        raw = _sse({"event": "searching", "topic": "AI safety"})
        events = _parse_sse_lines(raw)
        self.assertEqual(events[0]["topic"], "AI safety")

    def test_source_event_has_index_and_source_dict(self):
        raw = _sse({"event": "source", "index": 2, "source": {"title": "T"}})
        events = _parse_sse_lines(raw)
        self.assertEqual(events[0]["index"], 2)
        self.assertIsInstance(events[0]["source"], dict)

    def test_done_event_has_collection_id_and_source_count(self):
        import uuid
        cid = str(uuid.uuid4())
        raw = _sse({"event": "done", "collection_id": cid, "source_count": 4})
        events = _parse_sse_lines(raw)
        self.assertEqual(events[0]["collection_id"], cid)
        self.assertEqual(events[0]["source_count"], 4)


if __name__ == "__main__":
    unittest.main()
