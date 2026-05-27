from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from src.infrastructure.adapters.input.controllers.simulator_controller import router as simulator_router
from src.infrastructure.adapters.input.controllers.risk_controller import router as risk_router
from src.infrastructure.adapters.input.controllers.auth_controller import router as auth_router
from src.infrastructure.adapters.input.controllers.contacts_controller import router as contacts_router
from src.infrastructure.adapters.input.controllers.settings_controller import router as settings_router
# PMV2 — Telemetría IoT
from src.infrastructure.adapters.input.controllers.telemetry_controller import router as telemetry_router

app = FastAPI(
    title="Smart Overdose Detector API",
    description=(
        "Backend con Arquitectura Hexagonal para detección temprana de sobredosis. "
        "PMV1 — Simulación biométrica | PMV2 — Telemetría IoT con token de sesión."
    ),
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

import os
import logging
from sqlalchemy import create_engine, text
from src.infrastructure.configuration.settings import settings

logger = logging.getLogger("src.main")

def initialize_db_schema():
    if settings.STORAGE_BACKEND != "postgres":
        return
    try:
        logger.info("Verificando esquema de base de datos en %s...", settings.DATABASE_URL.split("@")[-1])
        engine = create_engine(settings.DATABASE_URL)
        with engine.connect() as conn:
            # Comprobar si existe la tabla 'users'
            result = conn.execute(text(
                "SELECT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'users');"
            ))
            exists = result.scalar()
            if not exists:
                logger.info("La tabla 'users' no existe. Inicializando esquema PMV2...")
                sql_file_path = os.path.join(
                    os.path.dirname(__file__), 
                    "infrastructure", "adapters", "output", "persistence", "init_pmv2.sql"
                )
                with open(sql_file_path, "r", encoding="utf-8") as f:
                    sql_content = f.read()
                
                # Ejecutar todo el script SQL
                conn.execute(text(sql_content))
                # Confirmar la transaccion
                conn.commit()
                logger.info("Esquema de base de datos inicializado exitosamente.")
            else:
                logger.info("La base de datos ya contiene la tabla 'users'. Saltando inicializacion.")
    except Exception as exc:
        logger.error("Error al inicializar el esquema de la base de datos: %s", exc)

@app.on_event("startup")
def on_startup():
    initialize_db_schema()


app.include_router(auth_router)
app.include_router(simulator_router)
app.include_router(risk_router)
app.include_router(contacts_router)
app.include_router(settings_router)
app.include_router(telemetry_router)   # PMV2


@app.get("/", tags=["Health"])
def health_check():
    return {
        "status": "ok",
        "version": "1.0.0",
        "message": "Smart Overdose Detector API — PMV1 activo",
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("src.main:app", host="0.0.0.0", port=8000, reload=True)
