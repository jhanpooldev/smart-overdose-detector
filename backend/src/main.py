from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from src.infrastructure.adapters.input.controllers.simulator_controller import router as simulator_router
from src.infrastructure.adapters.input.controllers.risk_controller import router as risk_router

app = FastAPI(
    title="Smart Overdose Detector API",
    description=(
        "Backend con Arquitectura Hexagonal para detección temprana de sobredosis. "
        "PMV1 — Datos de simulación biométrica."
    ),
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(simulator_router)
app.include_router(risk_router)


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
