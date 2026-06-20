# Nexus Build — Cycle Checkpoint
**Date:** 2026-06-19   **Status:** ⚠️ Review recommended

## What was built

Nexus can now open a saved source in a full reader view. Tapping any card in the Sources tab pushes a clean reading screen showing the AI summary, key insights, and the full extracted article text — with a link to open the original. Two stability fixes landed with this: the app no longer crashes when the backend omits the raw text field on the list endpoint, and failed items no longer incorrectly show stale AI summaries.

## ✅ Verify it worked

- [ ] **Reader view** — In the Sources tab, tap any completed source card. A full-screen reader should open with a summary hero block, numbered key insights, tags, and the extracted full text. Tap the "Open original" link at the bottom — it should open Safari.
- [ ] **No crash on Sources list** — With items in any processing or failed state, the Sources tab should load without crashing. Failed items must NOT show a summary or insights block.
- [ ] **pgvector dimension** — Run `SELECT atttypmod FROM pg_attribute JOIN pg_class ON attrelid=pg_class.oid WHERE relname='embeddings' AND attname='embedding'` — should return 772 (768 + 4 overhead). Confirmed already on main.

## 📋 Decisions made this cycle (no action needed)

| What was decided | Options considered | Why |
|---|---|---|
| Used `var rawContent: String? = nil` instead of custom Codable override | Custom CodingKeys init, try? wrapping | Matches existing `var tags: [String] = []` pattern — consistent and the Swift synthesiser handles it automatically |
| Guard summaryHero and insightsBlock on ingestStatus == .completed at the view layer | Guard in view model, add computed property on Item | View already checks ingestStatus for the processing branch — adding it as a leading condition is minimal and self-contained |
| Fireworks nomic-embed-text-v1.5 at 768-dim locked in; 1536-dim stub deleted | OpenAI text-embedding-3-small (1536-dim), self-hosted bge-m3 | 2.5x cost advantage, no meaningful quality difference for collection-scoped RAG at v1 scale |

## 🚨 Decisions that need your input

**1C-006 (Search) needs a full retry — 5 errors, not close to mergeable.** The SWE agent's retry commit is a dangling commit not reachable from main. The search router file exists only in the worktree, not on the branch. Key issues: `compute_embedding` is still a sync stub generating 1536-dim vectors (creating a DB dimension mismatch); `main.py` only registers 3 routers instead of 8 (regression); the config uses renamed Supabase field names that would break auth on merge; and the Alembic migration has a duplicate revision ID that would crash `alembic upgrade head`. Two retries exhausted. Recommend: discard the worktree, have SWE restart from current main HEAD and implement search as a focused add-only PR.

**1C-010 (Daily Briefing backend) needs a rebase — merge conflicts, not close to mergeable.** The implementation is functionally correct in the worktree but the branch was cut from an old base commit (b435ac2), and main has moved 15+ commits since then. There are 20 conflict markers in pipeline.py alone. Also: the migration is numbered 0002 (already exists on main), the user_interest_profile model uses `weights` but main's version uses `topics` (would be a silent runtime AttributeError), and `generate_daily_briefing()` is synchronous (blocks the event loop for 2-8 seconds per call). Recommend: SWE rebases onto current main, resolves conflicts, renames migration to 0005, unifies field name to `weights`, and converts to async.

## 🔜 Next cycle will work on

With 1C-003 (Reader) now done, 1C-007 (Nexus tab chat UI — the "Ask your library" SSE streaming screen) is unblocked. That is the last piece needed to complete the save → read → ask loop, which is the core demo. After that, the retried 1C-006 (search) and 1C-010 (briefing backend) can follow.

## ⏳ Waiting on you (blocked tasks)

| Task | What you need to do | What it unlocks |
|---|---|---|
| S3/R2 storage (1A-008) | Create an R2 or S3 bucket and paste the credentials into `api/.env` | Full-text storage for large articles; currently articles are held in memory only |
| APNs key (1C-011) | Generate an APNs key in your Apple Developer account and paste it into `api/.env` | Daily Briefing push notifications to iPhone |
