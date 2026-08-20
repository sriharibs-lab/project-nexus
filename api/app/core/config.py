from dotenv import load_dotenv
from pydantic_settings import BaseSettings, SettingsConfigDict

# Populate os.environ from .env so modules that read the environment directly
# (ai/pipeline.py, pipeline/jina.py, youtube.py, deepgram_extractor.py) see the
# same keys as pydantic-settings, regardless of how the server was launched.
load_dotenv()


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # Database
    database_url: str

    # Supabase — key names match api/.env exactly
    supabase_url: str
    supabase_secret_key: str           # JWT secret for HS256 token validation
    supabase_publishable_key: str      # anon/public key — safe for iOS binary
    supabase_service_role_key: str = ""  # Admin key — server-side only, never in iOS binary

    # Apple Sign-In — required for POST /v1/auth/apple
    # Must match the Bundle ID of the iOS app (app.nexus or com.example.nexus).
    # Gate: add APPLE_APP_BUNDLE_ID to api/.env before TestFlight.
    apple_app_bundle_id: str = ""

    # Anthropic — required for AI endpoints (1C-001 research, 1C-008 chat)
    # Gate: add ANTHROPIC_API_KEY to api/.env before live testing
    anthropic_api_key: str = ""

    # Fireworks — required for embedding (nomic-embed-text-v1.5, 768-dim)
    fireworks_api_key: str = ""
    # Open-source Fireworks text model for Create-tab artifact generation
    # (quiz, paper). gpt-oss-120b = OpenAI open-weights; swap here to retune.
    fireworks_text_model: str = "accounts/fireworks/models/gpt-oss-120b"

    # Cloudflare R2 / S3-compatible object storage (1A-008)
    # Gate: create the bucket and set these vars before 1E submission.
    # Fallback: if any of these are empty, raw_content stays in Postgres TEXT.
    r2_account_id: str = ""
    r2_access_key_id: str = ""
    r2_secret_access_key: str = ""
    r2_bucket_name: str = ""

    # App
    environment: str = "development"
    log_level: str = "info"

    # Admin token guarding /v1/admin/* (error monitor). Set ADMIN_TOKEN in the
    # environment; if empty, admin endpoints refuse (503) rather than open up.
    admin_token: str = ""

    # Chat RAG settings
    chat_rag_top_k: int = 8          # number of similar chunks retrieved per query
    chat_model: str = "claude-sonnet-4-6"  # model used for chat streaming; must match pipeline.py and research.py
    chat_max_tokens: int = 1024       # max tokens in the streamed reply

    # Research (collection discovery). web_search does the grounding, so the model
    # mostly curates/formats — Haiku ≈ halves cost vs Sonnet (search-result tokens
    # dominate input, billed at the model's input rate). Flip via env to trade a
    # little editorial currency for ~50% research savings.
    research_model: str = "claude-haiku-4-5"  # ~½ Sonnet cost; web_search does the grounding. Revert: RESEARCH_MODEL=claude-sonnet-4-6
    research_web_search_max_uses: int = 4   # was 6; each search adds ~$0.01 + result tokens

    # Search settings (1C-006)
    search_result_limit: int = 20       # max results returned to the client
    search_top_k: int = 20              # max rows from each leg before merge
    search_fts_weight: float = 0.3      # weight given to FTS rank in hybrid score (0-1)
    search_semantic_weight: float = 0.7  # weight given to cosine similarity (0-1)

    # Trending topics (1F-007)
    # How long to cache Google Trends RSS results in-process (seconds).
    # 15 min default: fresh enough for FRE sessions, low traffic load on Google.
    trending_cache_ttl_seconds: int = 900

    @property
    def is_production(self) -> bool:
        return self.environment == "production"

    @property
    def anthropic_configured(self) -> bool:
        return bool(self.anthropic_api_key)

    @property
    def embedding_configured(self) -> bool:
        return bool(self.fireworks_api_key)

    @property
    def r2_configured(self) -> bool:
        """True when all four R2 credentials are present. Falls back to Postgres TEXT if False."""
        return bool(
            self.r2_account_id
            and self.r2_access_key_id
            and self.r2_secret_access_key
            and self.r2_bucket_name
        )


settings = Settings()
