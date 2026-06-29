from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # Database
    database_url: str

    # Supabase — key names match api/.env exactly
    supabase_url: str
    supabase_secret_key: str       # JWT secret for HS256 token validation
    supabase_publishable_key: str  # anon/public key for client-side use

    # Anthropic — required for AI endpoints (1C-001 research, 1C-008 chat)
    # Gate: add ANTHROPIC_API_KEY to api/.env before live testing
    anthropic_api_key: str = ""

    # Fireworks — required for embedding (nomic-embed-text-v1.5, 768-dim)
    fireworks_api_key: str = ""

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

    # Chat RAG settings
    chat_rag_top_k: int = 8          # number of similar chunks retrieved per query
    chat_model: str = "claude-sonnet-4-6"  # model used for chat streaming; must match pipeline.py and research.py
    chat_max_tokens: int = 1024       # max tokens in the streamed reply

    # Search settings (1C-006)
    search_result_limit: int = 20       # max results returned to the client
    search_top_k: int = 20              # max rows from each leg before merge
    search_fts_weight: float = 0.3      # weight given to FTS rank in hybrid score (0-1)
    search_semantic_weight: float = 0.7  # weight given to cosine similarity (0-1)

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
