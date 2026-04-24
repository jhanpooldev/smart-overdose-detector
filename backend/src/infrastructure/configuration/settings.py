"""
settings.py — Carga variables de entorno desde el archivo .env.
"""
import os
from pathlib import Path
from dotenv import load_dotenv

# Carga .env desde la raíz del backend
load_dotenv(Path(__file__).parent.parent.parent.parent / ".env")


class Settings:
    DATABASE_URL: str = os.getenv("DATABASE_URL", "")
    ENV: str = os.getenv("ENV", "development")
    # "memory" = sin BD real | "postgres" = PostgreSQL real
    STORAGE_BACKEND: str = os.getenv("STORAGE_BACKEND", "memory")


settings = Settings()
