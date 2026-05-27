"""
config_db.py — Pool de conexiones asíncronas con SQLAlchemy (AsyncSession).
Lee credenciales desde entorno usando Pydantic BaseSettings.
PMV2 — Arquitectura Hexagonal.
"""
from functools import lru_cache
from typing import AsyncGenerator

from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.pool import NullPool


# ── Configuración con Pydantic BaseSettings ───────────────────────────────────
class DatabaseSettings(BaseSettings):
    """Lee variables desde .env con prefijo DB_ o sin prefijo."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/Overdose-detector"
    DB_POOL_SIZE: int = 10
    DB_MAX_OVERFLOW: int = 20
    DB_POOL_TIMEOUT: int = 30
    DB_ECHO_SQL: bool = False


@lru_cache(maxsize=1)
def get_db_settings() -> DatabaseSettings:
    """Singleton de configuración (cacheado una vez al arranque)."""
    return DatabaseSettings()


# ── Engine y Session Factory ──────────────────────────────────────────────────
def _build_engine(settings: DatabaseSettings) -> AsyncEngine:
    """Construye el engine asíncrono con pool configurado."""
    url = settings.DATABASE_URL
    # asyncpg no acepta el prefijo 'postgresql://', necesita 'postgresql+asyncpg://'
    if url.startswith("postgresql://"):
        url = url.replace("postgresql://", "postgresql+asyncpg://", 1)

    return create_async_engine(
        url,
        echo=settings.DB_ECHO_SQL,
        pool_size=settings.DB_POOL_SIZE,
        max_overflow=settings.DB_MAX_OVERFLOW,
        pool_timeout=settings.DB_POOL_TIMEOUT,
        pool_pre_ping=True,       # Verifica la conexión antes de cada checkout
        pool_recycle=3600,        # Recicla conexiones cada hora
        # NullPool en tests para evitar concurrencia de eventos
        # poolclass=NullPool,
    )


_db_settings: DatabaseSettings = get_db_settings()
_async_engine: AsyncEngine = _build_engine(_db_settings)

AsyncSessionLocal: async_sessionmaker[AsyncSession] = async_sessionmaker(
    bind=_async_engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
    autocommit=False,
)


# ── Dependency Injection — FastAPI ────────────────────────────────────────────
async def get_async_db() -> AsyncGenerator[AsyncSession, None]:
    """
    Generador async para inyectar sesiones de BD en FastAPI (Depends).

    Uso en controlador:
        @router.post("/endpoint")
        async def handler(db: AsyncSession = Depends(get_async_db)):
            ...
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


async def ping_db() -> bool:
    """Verifica conectividad con la BD. Útil para health checks."""
    try:
        async with AsyncSessionLocal() as session:
            await session.execute(__import__("sqlalchemy").text("SELECT 1"))
        return True
    except Exception:
        return False
