# Nexus Build Loop — Agent Log

Append-only. Written by the ALM agent at the end of each cycle.

---

## Cycle 2026-06-13T00:00:00Z
Tasks completed: 1A-012, 0A-tok-css
Tasks blocked: none
Gated (waiting on human): 1A-008 (S3/R2 bucket — needs cloud storage credentials in api/.env)
Commit SHA: d5f2b7a

---

## Cycle 2026-06-13T12:00:00Z
Tasks completed: 0A-screens
Tasks blocked: 1A-013 (request_changes — duplicate revision ID 0002 in alembic/versions; content_type still plain str not enum in IngestRequest; leftover ContentType Literal in pipeline.py)
Gated (waiting on human): 1A-008 (S3/R2 bucket — needs cloud storage credentials in api/.env)
Commit SHA: 37499a7

---

## Cycle 2026-06-13T18:00:00Z
Tasks completed: 0A-responsive
Tasks blocked: none
Gated (waiting on human): 1A-008 (S3/R2 bucket — needs cloud storage credentials in api/.env)
Commit SHA: 633e097

---

## Cycle 2026-06-13T20:00:00Z
Tasks completed: none
Tasks blocked: none
Gated (waiting on human): 1A-008 (S3/R2 bucket — needs cloud storage credentials in api/.env), 1B-002 (Sign in with Apple + Magic link — needs Xcode provisioning profile with Apple Developer account for bundle ID app.nexus)
Commit SHA: (no merge — no tasks completed)

---

## Cycle 2026-06-18T00:00:00Z
Tasks completed: none
Tasks blocked: none
Gated (waiting on human): 1A-008 (S3/R2 bucket — needs cloud storage credentials in api/.env), 1B-002 (Sign in with Apple + Magic link — add "1B" to allow_phases in .nbl/config.md; Apple Developer gate resolved 2026-06-12), pgqueuer (not yet a formal task — Architect recommends adding to BUILD_PLAN.md), user_interest_profiles (not yet a formal task — Architect recommends adding before 1C)
Commit SHA: (no merge — no tasks completed)

---

## Cycle 2026-06-18T12:00:00Z
Tasks completed: 1B-002 (Sign in with Apple + Magic link auth — merged approve_with_notes)
Tasks blocked: 1B-003 (Share Extension — request_changes after 2 retries; save.py missing, iOS Swift files absent, uppercase ContentType enum still live in 3 extractors, pgqueuer migration absent, source_count increments before ingest completes, feedback router unregistered in main.py), 1B-006 (In-app feedback UI — request_changes after 2 retries; feedback router not registered in main.py, ContentType enum uppercase bug still live in 3 extractors, field named `text` not `message` despite SWE claim)
Gated (waiting on human): 1A-008 (S3/R2 bucket — needs cloud storage credentials in api/.env)
Commit SHA: 8f2de72

---

## Cycle 2026-06-18T18:00:00Z
Tasks completed: none
Tasks blocked: none
Gated (waiting on human): 1A-008 (S3/R2 bucket — needs cloud storage credentials in api/.env)
Commit SHA: (no merge — no tasks completed)

---

## Cycle 2026-06-19T00:00:00Z
Tasks completed: 1B-006 (In-app feedback UI — merged approve_with_notes; 11 backend tests pass, full iOS flow implemented)
Tasks blocked: 1B-003 (Share Extension — request_changes after 2 retries; auth.py still has `= None` instead of `= Depends(bearer_scheme)`; requirements.txt had major deps stripped; collection_id removed from ingest violating locked IA; Swift NexusShare files absent from branch; SWE must restart from main and make only targeted auth.py fix)
Gated (waiting on human): 1A-008 (S3/R2 bucket — needs cloud storage credentials in api/.env)
Commit SHA: f37aeb6

---

## Cycle 2026-06-19T12:00:00Z
Tasks completed: 1C-001 (POST /collections/research SSE endpoint — approve_with_notes; 21 tests pass), 1C-008 (POST /collections/{id}/chat SSE endpoint — approve_with_notes; 9 tests pass; collections.py merge conflict resolved by ALM combining CRUD + chat into single router), 1C-queue-durability (pgqueuer upgrade — approve_with_notes; 11 tests pass)
Tasks blocked: none
Gated (waiting on human): 1A-008 (S3/R2 bucket — needs cloud storage credentials in api/.env), 1C-011 (Daily Briefing push UI — needs APNs key)
Commit SHA: b21fbb1

---

## Cycle 2026-06-19T18:00:00Z
Tasks completed: 1C-002 (library view — CollectionCard upgrade, SourceCard with IngestStatusPill/tag chips, pull-to-refresh, Codable tags bug fixed; 50/51 tests pass — approve_with_notes), 1C-009 (interest profile background computation — bump/decay/prune tag weights wired into _process_job; 8/8 algorithm tests pass; approve_with_notes)
Tasks blocked: none
Gated (waiting on human): 1A-008 (S3/R2 bucket — needs cloud storage credentials in api/.env), 1C-011 (Daily Briefing push UI — needs APNs key), 1C-005 (Research FRE iOS screen — gates on 1C-002 now complete)
Commit SHA: a3d4b34

---

## Cycle 2026-06-19T22:00:00Z
Tasks completed: 1C-003 (Item detail / Reader view — approve_with_notes; rawContent fix, summaryHero/insightsBlock ingestStatus guards; 64 tests pass; cherry-picked onto main), pgvector-audit (768-dim embedding fix — approve_with_notes; already on main via 3bc497a)
Tasks blocked: 1C-006 (search — request_changes after 2 retries; dangling commit not on main, compute_embedding still sync stub, migration duplicate revision 0002, config field name drift supabase_jwt_secret vs supabase_secret_key, main.py missing 5 routers), 1C-010 (Daily Briefing backend — request_changes; branch cut from b435ac2, 20 merge conflict markers in pipeline.py, duplicate migration revision 0002, user_interest_profile field name collision weights vs topics, generate_daily_briefing() sync blocks event loop)
Gated (waiting on human): 1A-008 (S3/R2 bucket — needs cloud storage credentials in api/.env), 1C-011 (Daily Briefing push UI — needs APNs key), 1C-007 (Nexus tab chat UI — gated on 1C-003 now complete)
Commit SHA: 43fd26a

---

## Cycle 2026-06-20T00:00:00Z
Tasks completed: BLOCKER-collections-enum (CollectionCreatedBy enum + created_by field — approve; 39 tests pass; FastAPI startup ImportError eliminated), 1C-007 (Nexus tab chat UI — approve_with_notes; iOS SSE consumer, EchoPulse wait state, citation chips, Liquid Glass tab capsule, 6-turn history; nexus-tab-chat.html + 26 tests pass), 1C-004 (Sources tab polish — approve_with_notes; ContentTypeIcon, TagChips, SwipeRow swipe-to-delete, PullToRefresh; 48 tests pass)
Tasks blocked: none
Gated (waiting on human): 1A-008 (S3/R2 bucket — needs cloud storage credentials in api/.env), 1C-011 (Daily Briefing iOS UI — needs APNs key from Apple Developer portal)
Commit SHA: 96f7846

---

## Cycle 2026-06-20T12:00:00Z
Tasks completed: 1C-007 (NexusTabView — approve_with_notes; 72/72 tests pass; SSE chat, EchoPulse, citation chips, Liquid Glass capsule, 6-turn history), 1C-004 (SourcesTabView — approve_with_notes; 94/94 tests pass; tag chips, content-type icons, swipe-to-delete, pull-to-refresh), 0-004 (waitlist landing page — approve_with_notes; 51/51 tests pass; single-box CTA, Echo mark, Liquid Glass nav)
Tasks blocked: none
Gated (waiting on human): 1A-008 (S3/R2 bucket — needs cloud storage credentials in api/.env), 1C-011 (Daily Briefing iOS UI — needs APNs key from Apple Developer portal)
Commit SHA: 12d67e3
