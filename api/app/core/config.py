from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # Database
    database_url: str

    # Supabase — key names match api/.env exactly
    supabase_url: str
    supabase_secret_key: str           # JWT secret for HS256 token validation
    supabase_publishable_key: str      # anon/public key — safe for iOS binary
    supabase_service_role_key: str = ""  # Admin key — server-side only, never in iOS binary

    # Anthropic — required for AI endpoints (1C-001 research, 1C-008 chat)
    # Gate: add ANTHROPIC_API_KEY to api/.env before live testing
    anthropic_api_key: str = ""

    # Fireworks — required for embedding (nomic-embed-text-v1.5, 768-dim)
    fireworks_api_key: str = ""

    # App
    environment: str = "development"
    log_level: str = "info"

    # Chat RAG settings
    chat_rag_top_k: int = 8          # number of similar chunks retrieved per query
    chat_model: str = "claude-sonnet-4-6"  # model used for chat streaming; must match pipeline.py and research.py
    chat_max_tokens: int = 1024       # max tokens in the streamed reply

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


settings = Settings()
