from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # Database
    database_url: str

    # Supabase
    supabase_url: str
    supabase_jwt_secret: str
    supabase_anon_key: str

    # App
    environment: str = "development"
    log_level: str = "info"

    # Ingest pipeline performance
    # Jina timeout tuned to keep save-to-summary SLO < 10 000 ms.
    # 8s leaves room for AI summarization (~2-3s) and DB write (~0.5s).
    jina_timeout: int = 8
    # When Jina times out or fails, fall back to local trafilatura extraction.
    jina_fallback_to_readability: bool = True
    # Target SLO (milliseconds). Logged as a warning when exceeded.
    ingest_slo_ms: int = 10_000

    @property
    def is_production(self) -> bool:
        return self.environment == "production"


settings = Settings()
