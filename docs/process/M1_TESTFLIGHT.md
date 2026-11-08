# Milestone 1 — Presence on TestFlight

**Goal:** a functioning Nexus build on Srihari's iPhone via internal TestFlight, hitting a **live deployed backend** (not the Mac's LAN IP). Internal only — no Beta App Review, no legal pages, no polish bar. That's Milestone 2.

**Live backend:** **https://<your-render-service>.onrender.com** ✅ (Render, smoke-tested green 2026-07-18: `/health` DB-connected, prod-config confirmed). The deploy bottleneck is **cleared** — remaining work is Apple signing + upload.

_Owner key:_ 🤖 Claude · 🙋 Srihari · 🤝 together · Last updated: 2026-07-18

---

## Status board

| # | Step | Owner | Status |
|---|------|-------|--------|
| 1 | Backend deploy-ready (Dockerfile, render.yaml, .dockerignore) | 🤖 | ✅ done |
| 2 | Env-var list for the host dashboard | 🤖 | ✅ done (below) |
| 3 | Pick host + create account + connect repo + deploy | 🙋 | ✅ done — Render |
| 4 | Set backend secrets in the host dashboard | 🙋 | ✅ done |
| 5 | Keep-alive (GitHub Actions hourly → Supabase-safe; UptimeRobot optional for Render-warm) | 🤖 | ✅ done |
| 6 | Point Release `API_BASE_URL` at the deployed URL | 🤖 | ✅ done → onrender URL |
| 7 | Smoke-test the live backend (curl) | 🤖 | ✅ done — all green |
| 8 | Enroll in Apple Developer Program | 🙋 | ✅ done — approved |
| 9 | Signing + archive-ready build | 🤝 | ✅ done — team C7FA8XLN5P, auto, `app.nexus`, 1.0(1) |
| 10 | Archive + upload + ASC record + internal tester | 🙋 | ⏳ **final step — you're here** |

---

## What Claude did (steps 1–2)

- **`api/Dockerfile`** — portable image (pip + `requirements.txt`), runs `alembic upgrade head` (tolerant — the M1 DB is already migrated) then serves `uvicorn`. Works on Render / Railway / Fly.
- **`render.yaml`** — one-click Render Blueprint (free plan, `/health` healthcheck, all secrets `sync:false`).
- **`api/.dockerignore`** — guarantees `.env` never bakes into the image.
- In-process worker (started in `app.main` lifespan) ships in the same web process — fine for M1. Worker-as-separate-process is post-M1.

---

## Your next action (step 3) — deploy to Render (recommended, free)

1. Push this branch to GitHub (Claude will commit these files).
2. [render.com](https://render.com) → sign up → **New → Blueprint** → connect the `project-nexus` repo → it reads `render.yaml` → **Apply**.
3. Render builds `api/Dockerfile` and gives you a URL like `https://nexus-api.onrender.com`.
4. Do **step 4** (secrets) before it can boot — see the table below.
5. Paste the URL back to Claude → step 6 (wire the app) + step 7 (smoke test).

_Alternative hosts:_ Railway or Fly both work with the same `api/Dockerfile` (set root/context to `api`). Render is the least-config free path.

> **Free-tier note:** Render free web services sleep after ~15 min idle (cold start ~30–60s). The keep-alive ping (step 5) keeps it warm **and** keeps Supabase free-tier from its 7-day auto-pause. No Supabase Pro needed.

---

## Step 4 — Env vars (set in the host dashboard, copy values from local `api/.env`)

| Variable | Required | Where the value comes from |
|----------|----------|----------------------------|
| `DATABASE_URL` | ✅ | Supabase → Project Settings → Database → **Connection Pooler → Session mode** URI (see gotcha below) |
| `SUPABASE_URL` | ✅ | local `api/.env` |
| `SUPABASE_SECRET_KEY` | ✅ | local `api/.env` (JWT secret, HS256) |
| `SUPABASE_PUBLISHABLE_KEY` | ✅ | local `api/.env` |
| `SUPABASE_SERVICE_ROLE_KEY` | recommended | local `api/.env` |
| `ANTHROPIC_API_KEY` | ✅ (AI) | local `api/.env` |
| `FIREWORKS_API_KEY` | ✅ (embeddings) | local `api/.env` |
| `APPLE_APP_BUNDLE_ID` | for Apple Sign-In | your bundle id, e.g. `app.nexus` |
| `ENVIRONMENT` | ✅ | literal `production` (already in render.yaml) |
| `LOG_LEVEL` | optional | literal `info` (already in render.yaml) |
| `DEEPGRAM_API_KEY` | optional | local `api/.env` (podcasts) |
| `JINA_API_KEY` | optional | local `api/.env` (reader rate limit) |
| `YOUTUBE_API_KEY` | optional | local `api/.env` (video metadata) |

_OTP email is **not** here — it's sent by Supabase Auth (Resend SMTP configured in the Supabase dashboard), so no email keys live in the backend. Your own address already works._

> **⚠️ `DATABASE_URL` gotcha (most likely deploy snag):** Supabase's *direct* connection (`db.<ref>.supabase.co:5432`) is IPv6-only and many hosts can't reach it. Use the **Session-mode pooler** URI (IPv4) from the Supabase dashboard instead. If asyncpg errors on prepared statements, we'll append `?prepared_statement_cache_size=0` — flag it to Claude and we'll fix it in <2 attempts.

---

## Notes / decisions
- Backend deploy is host-agnostic (Docker). Render chosen for the fastest free path.
- Migrations run on boot but are tolerant (DB already at head via shared Supabase).
- CORS is empty in production — fine for the native iOS app (CORS is browser-only). If we later want the Next.js prototype to hit prod, we'll allow its origin.
- `/docs` is disabled in production (by design).
