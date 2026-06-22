"""
settings.py — Configuración centralizada con Pydantic.

Todas las variables sensibles se leen EXCLUSIVAMENTE desde el archivo .env;
ningún valor secreto está hardcodeado en el código fuente.
"""
import os
from pathlib import Path
from dotenv import load_dotenv

# Carga .env desde la raíz del backend
load_dotenv(Path(__file__).parent.parent.parent.parent / ".env")


class Settings:
    # ── Base de datos ──────────────────────────────────────────────────────────
    DATABASE_URL: str = os.getenv("DATABASE_URL", "")
    # "memory" = sin BD real | "postgres" = PostgreSQL real
    STORAGE_BACKEND: str = os.getenv("STORAGE_BACKEND", "memory")

    # ── Entorno ────────────────────────────────────────────────────────────────
    ENV: str = os.getenv("ENV", "development")

    @property
    def is_production(self) -> bool:
        return self.ENV.lower() == "production"

    # ── JWT / Seguridad ────────────────────────────────────────────────────────
    SECRET_KEY: str = os.getenv("SECRET_KEY", "")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = int(
        os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "1440")  # 24 horas por defecto
    )

    # ── CORS ───────────────────────────────────────────────────────────────────
    # Lista de orígenes separados por coma en .env: "http://localhost,https://mi-app.com"
    _raw_origins: str = os.getenv("ALLOWED_ORIGINS", "http://localhost")

    @property
    def allowed_origins(self) -> list[str]:
        return [o.strip() for o in self._raw_origins.split(",") if o.strip()]

    def validate(self) -> None:
        """Valida que las variables críticas estén configuradas al arrancar."""
        errors: list[str] = []
        if not self.SECRET_KEY:
            errors.append("SECRET_KEY no está definida en .env")
        if len(self.SECRET_KEY) < 32:
            errors.append("SECRET_KEY debe tener al menos 32 caracteres")
        if self.STORAGE_BACKEND == "postgres" and not self.DATABASE_URL:
            errors.append("STORAGE_BACKEND=postgres pero DATABASE_URL no está definida")
        if errors:
            raise RuntimeError(
                "Configuración inválida — corrige el archivo .env:\n  • "
                + "\n  • ".join(errors)
            )


settings = Settings()
