from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = (
        "postgresql+asyncpg://trailmate:trailmate@localhost:5432/trailmate"
    )
    jwt_secret: str = "change_me"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7
    supabase_url: str = ""
    supabase_key: str = ""


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
