"""
main.py — Punto de entrada del backend FastAPI.

Correcciones de seguridad aplicadas:
  - CORS restringido a orígenes explícitos (ALLOWED_ORIGINS en .env).
  - Security Headers HTTP (X-Content-Type-Options, X-Frame-Options, etc.).
  - Middleware de Correlation ID para trazabilidad de logs.
  - Health check enriquecido con ping a la BD.
  - Validación de settings críticos al arrancar.
  - reload=True eliminado (solo para desarrollo local directo).
"""
import logging
import os
import uuid
import time

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware

from src.infrastructure.configuration.settings import settings

# ── Controllers ───────────────────────────────────────────────────────────────
from src.infrastructure.adapters.input.controllers.simulator_controller import router as simulator_router
from src.infrastructure.adapters.input.controllers.risk_controller import router as risk_router
from src.infrastructure.adapters.input.controllers.auth_controller import router as auth_router
from src.infrastructure.adapters.input.controllers.contacts_controller import router as contacts_router
from src.infrastructure.adapters.input.controllers.settings_controller import router as settings_router
from src.infrastructure.adapters.input.controllers.telemetry_controller import router as telemetry_router

logger = logging.getLogger("src.main")

# ── Aplicación ────────────────────────────────────────────────────────────────
app = FastAPI(
    title="Smart Overdose Detector API",
    description=(
        "Backend con Arquitectura Hexagonal para detección temprana de sobredosis. "
        "PMV1 — Simulación biométrica | PMV2 — Telemetría IoT con token de sesión."
    ),
    version="2.0.0",
    # Deshabilitar docs automáticas en producción
    docs_url=None if settings.is_production else "/docs",
    redoc_url=None if settings.is_production else "/redoc",
)

# ── CORS restringido ──────────────────────────────────────────────────────────
# Los orígenes se leen de ALLOWED_ORIGINS en el .env (nunca "*").
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-Correlation-ID"],
)


# ── Security Headers ──────────────────────────────────────────────────────────
class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Añade cabeceras de seguridad HTTP a todas las respuestas."""

    async def dispatch(self, request: Request, call_next):
        response: Response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Permissions-Policy"] = "geolocation=(), microphone=()"
        if settings.is_production:
            response.headers["Strict-Transport-Security"] = (
                "max-age=63072000; includeSubDomains; preload"
            )
        return response


app.add_middleware(SecurityHeadersMiddleware)


# ── Correlation ID ────────────────────────────────────────────────────────────
class CorrelationIdMiddleware(BaseHTTPMiddleware):
    """
    Asigna un ID único a cada request para trazabilidad en logs.
    El cliente puede enviar X-Correlation-ID o se genera automáticamente.
    """

    async def dispatch(self, request: Request, call_next):
        correlation_id = request.headers.get("X-Correlation-ID") or str(uuid.uuid4())
        # Inyectar en el estado del request para que los handlers lo usen
        request.state.correlation_id = correlation_id

        start = time.monotonic()
        response: Response = await call_next(request)
        duration_ms = round((time.monotonic() - start) * 1000)

        response.headers["X-Correlation-ID"] = correlation_id
        logger.info(
            "method=%s path=%s status=%d duration_ms=%d correlation_id=%s",
            request.method,
            request.url.path,
            response.status_code,
            duration_ms,
            correlation_id,
        )
        return response


app.add_middleware(CorrelationIdMiddleware)


# ── Startup ───────────────────────────────────────────────────────────────────
def _initialize_db_schema() -> None:
    """Verifica e inicializa el esquema de la BD si no existe."""
    if settings.STORAGE_BACKEND != "postgres":
        return
    try:
        from sqlalchemy import create_engine, text

        logger.info(
            "Verificando esquema en %s...", settings.DATABASE_URL.split("@")[-1]
        )
        engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)
        with engine.connect() as conn:
            result = conn.execute(
                text(
                    "SELECT EXISTS ("
                    "SELECT FROM pg_tables "
                    "WHERE schemaname = 'public' AND tablename = 'users'"
                    ");"
                )
            )
            exists = result.scalar()
            if not exists:
                logger.info("Tabla 'users' no existe — inicializando esquema PMV2...")
                sql_path = os.path.join(
                    os.path.dirname(__file__),
                    "infrastructure",
                    "adapters",
                    "output",
                    "persistence",
                    "init_pmv2.sql",
                )
                with open(sql_path, encoding="utf-8") as f:
                    conn.execute(text(f.read()))
                conn.commit()
                logger.info("Esquema inicializado exitosamente.")
            else:
                logger.info("Esquema ya existe — sin cambios.")
    except Exception as exc:
        logger.error("Error al inicializar esquema DB: %s", exc)


@app.on_event("startup")
def on_startup() -> None:
    # Validar configuración crítica antes de arrancar
    settings.validate()
    _initialize_db_schema()
    logger.info(
        "🚀 Smart Overdose Detector API iniciada — ENV=%s STORAGE=%s",
        settings.ENV,
        settings.STORAGE_BACKEND,
    )


# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(auth_router)
app.include_router(simulator_router)
app.include_router(risk_router)
app.include_router(contacts_router)
app.include_router(settings_router)
app.include_router(telemetry_router)


# ── Health Check ──────────────────────────────────────────────────────────────
@app.get("/", tags=["Health"])
@app.get("/health", tags=["Health"])
def health_check() -> dict:
    """
    Health check enriquecido.
    Incluye ping a la BD para confirmar disponibilidad del servicio completo.
    """
    db_status = "ok"
    db_latency_ms: float | None = None

    if settings.STORAGE_BACKEND == "postgres" and settings.DATABASE_URL:
        try:
            from sqlalchemy import create_engine, text

            start = time.monotonic()
            engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)
            with engine.connect() as conn:
                conn.execute(text("SELECT 1"))
            db_latency_ms = round((time.monotonic() - start) * 1000, 2)
        except Exception as exc:
            db_status = f"error: {exc}"

    return {
        "status": "ok" if db_status == "ok" else "degraded",
        "version": "2.0.0",
        "env": settings.ENV,
        "storage": settings.STORAGE_BACKEND,
        "database": {"status": db_status, "latency_ms": db_latency_ms},
    }


# ── Entrypoint directo (desarrollo local) ─────────────────────────────────────
if __name__ == "__main__":
    import uvicorn

    # reload=True SOLO en desarrollo local; en producción usa el proceso Uvicorn
    # directamente: uvicorn src.main:app --host 0.0.0.0 --port 8000
    _reload = settings.ENV == "development"
    uvicorn.run("src.main:app", host="0.0.0.0", port=8000, reload=_reload)
