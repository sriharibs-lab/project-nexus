# Nexus Build — Cycle Checkpoint
**Date:** 2026-06-19   **Status:** ⚠️ Review recommended

## What was built

Nexus can now create AI-seeded collections from a topic: type a subject, and the app streams back a curated list of sources in real time while Claude assembles them. Once a collection has sources, users can ask questions about them — the app finds the most relevant saved content using semantic search, passes it to Claude Sonnet, and streams back a grounded answer with citations. The ingest queue was also upgraded from in-memory (lost on restart) to a Postgres-backed durable queue — jobs survive server restarts and can be retried on failure.

## ✅ Verify it worked

- [ ] **Research endpoint** — `curl -N -X POST http://localhost:8000/v1/collections/research -H "Authorization: Bearer <token>" -H "Content-Type: application/json" -d '{"topic":"longevity and aging"}' ` — should stream `data:` events ending with `{"event":"done","collection_id":"...","source_count":N}`
- [ ] **Chat endpoint** — `curl -N -X POST http://localhost:8000/v1/collections/<id>/chat -H "Authorization: Bearer <token>" -H "Content-Type: application/json" -d '{"message":"What are the key themes?"}' ` — should stream `{"type":"sources",...}` then `{"type":"chunk",...}` events, ending with `{"type":"done"}`
- [ ] **Durable queue** — start server, queue an ingest job via `POST /v1/ingest`, kill the server, restart — the job should still be in `pgqueuer_jobs` table (`SELECT * FROM pgqueuer_jobs WHERE queue_name='nexus_ingest'`)
- [ ] **Auth body fix** — `POST /v1/collections` with `{"name":"test"}` and a Bearer token should return 201, not 422 (the body-schema nesting bug is fixed)

## 📋 Decisions made this cycle (no action needed)

| What was decided | Options considered | Why |
|---|---|---|
| SSE (Server-Sent Events) for both AI endpoints | WebSocket, polling | SSE is one-way — exactly right for streaming AI; works natively on iOS with URLSessionDataTask |
| Claude Sonnet for research and chat (not Haiku) | Haiku for cost, Opus for quality | SPEC §9c requires Sonnet quality floor for user-facing AI; Opus reserved for internal tooling only |
| pgvector RAG read path as a shared module (`rag.py`) | Inline per-endpoint | Both chat and semantic search (1C-006) share the same cosine similarity query; centralise once |
| pgqueuer over Redis for queue durability | Redis+Celery, Redis+custom | No new infrastructure — reuses existing Supabase Postgres; zero extra ops cost before TestFlight |
| Auth fix: `Depends(bearer_scheme)` in auth.py | Add `Body()` to every route | Root cause fix in one place; fixes all routers, not just the new ones |
| Always emit terminal SSE event (done or error) | Let exceptions propagate | iOS cannot see HTTP status codes mid-stream; a torn connection shows as a stuck spinner |
| Sources event emitted before chat text | Sources after response | Users see citation list instantly while Claude types; feels faster and more transparent |
| Double security filter (collection_id + user_id) in RAG SQL | Filter on collection_id only | Defense in depth: guessed UUID cannot leak another user's saved content even if route auth is bypassed |

## 🚨 Decisions that need your input

**1C-001 + 1C-008 merge:** Both tasks wrote a `collections.py` router in parallel. The ALM combined them into one file with all CRUD routes plus the chat SSE endpoint. Scan `api/app/routers/collections.py` once to confirm the combined file looks right before the next cycle builds iOS screens on top of it.

**Token telemetry is still estimated:** Both AI endpoints log approximate token counts rather than exact usage from the Anthropic API. Documented in code with a `# TODO: upgrade before TestFlight` comment. No action now — but add `ANTHROPIC_API_KEY` to `api/.env` before any live AI testing.

## 🔜 Next cycle will work on

The research and chat endpoints are live — next is the iOS side: the "Research a topic" FRE flow (1C-005) that calls the research endpoint and shows sources arriving in real time, and the Library view (1C-002) that displays your collections. These two screens are the core product loop a user experiences on first launch.

## ⏳ Waiting on you (blocked tasks)

| Task | What you need to do | What it unlocks |
|---|---|---|
| S3/R2 full-text storage (1A-008) | Create an R2 or S3 bucket and paste credentials into `api/.env` | Full article text stored durably; reader view can load offline |
| ANTHROPIC_API_KEY | Add your Anthropic API key to `api/.env` | Research and chat endpoints return real AI responses (currently return a structured error event) |
| APNs key (1C-011) | Add Apple Push Notification key to `api/.env` | Daily Briefing push notifications to iPhone |
