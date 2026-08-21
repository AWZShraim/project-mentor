from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql+psycopg://mentor:mentor@localhost:5432/mentor"

    aws_region: str = "ca-central-1"
    cognito_user_pool_id: str
    cognito_app_client_id: str


settings = Settings()
