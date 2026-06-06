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

    @property
    def is_production(self) -> bool:
        return self.environment == "production"


settings = Settings()
