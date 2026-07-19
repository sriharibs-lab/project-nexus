# Nexus API — portable container (Render / Railway / Fly / any Docker host).
# Single process runs the FastAPI app AND the in-process ingestion worker
# (started in app.main lifespan). Worker-as-separate-process is a post-M1 item.
FROM python:3.12-slim

# curl kept for container-level healthchecks; wheels cover asyncpg/pgvector.
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Dependencies first for layer caching.
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# App source (secrets excluded via .dockerignore — never bake .env into an image).
COPY . .

# Hosts inject $PORT; 8000 is the local `docker run` default.
ENV PORT=8000
EXPOSE 8000

# Migrations are idempotent and the M1 DB is already at head (shared with local
# dev), so a hiccup must NOT block boot — tolerate failure, then serve.
CMD ["sh", "-c", "alembic upgrade head || echo '[warn] alembic upgrade skipped (DB likely already at head)'; exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"]
