from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # Database
    database_url: str

    # Supabase (new key format — publishable replaces anon, secret replaces service_role)
    supabase_url: str
    supabase_publishable_key: str
    supabase_secret_key: str

    # Derived from supabase_url — no separate env var needed
    @property
    def supabase_jwks_url(self) -> str:
        return f"{self.supabase_url}/auth/v1/.well-known/jwks.json"

    # Anthropic
    anthropic_api_key: str = ""

    # OpenAI (embeddings)
    openai_api_key: str = ""

    # App
    environment: str = "development"
    log_level: str = "info"

    @property
    def is_production(self) -> bool:
        return self.environment == "production"


settings = Settings()
