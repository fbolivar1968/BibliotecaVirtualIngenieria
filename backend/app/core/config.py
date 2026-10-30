from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    APP_NAME: str = "Biblioteca Virtual de Ingeniería - Forjas Bolívar"
    APP_ENV: str = "development"
    APP_VERSION: str = "0.1.0"
    API_V1_PREFIX: str = "/api/v1"
    DEBUG: bool = True

    # Seguridad & JWT (ADR-002)
    JWT_SECRET_KEY: str = "CHANGE_ME_IN_PRODUCTION"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    AUTH_MAX_FAILED_ATTEMPTS: int = 5
    AUTH_LOCKOUT_MINUTES: int = 15

    # Base de Datos PostgreSQL + pgvector (ADR-003)
    DATABASE_URL: str = (
        "postgresql+psycopg://fobol_app:fobol_dev_password@localhost:5432/fobol_engineering_kb"
    )

    # Cola Asíncrona (ADR-004)
    REDIS_URL: str = "redis://localhost:6379/0"

    # Almacenamiento Documental (DDD §1.1)
    DOCUMENT_STORAGE_PATH: str = "./storage_data/documents"
    REPORT_STORAGE_PATH: str = "./storage_data/reports"

    # RAG & Inferencia Local (ADR-005)
    LLM_BASE_URL: str = "http://localhost:11434/v1"
    LLM_MODEL_NAME: str = "deepseek-r1:14b-q4_K_M"
    EMBEDDING_MODEL_NAME: str = "intfloat/multilingual-e5-large"
    EMBEDDING_DIMENSION: int = 1024
    RAG_MIN_CONFIDENCE_THRESHOLD: float = 0.72

    # CORS
    CORS_ORIGINS: list[str] = [
        "http://localhost:5173",
        "http://bibliotecatecnica.forjasbolivar.local",
    ]


settings = Settings()

