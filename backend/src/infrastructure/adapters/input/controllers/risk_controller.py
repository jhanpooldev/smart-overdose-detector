"""
risk_controller.py — Endpoints principales: evaluación de riesgo y alertas.
"""
from fastapi import APIRouter, Query
from pydantic import BaseModel
from datetime import datetime

from src.infrastructure.configuration.container import (
    simulated_data_generator,
    evaluar_riesgo_use_case,
    gestionar_alerta_use_case,
)
from src.domain.entities.risk_event import RiskLevel
from src.infrastructure.adapters.input.controllers.auth_controller import get_current_user
from src.domain.entities.user import User
from fastapi import APIRouter, Query, Depends, HTTPException

router = APIRouter(prefix="/api/v1", tags=["Risk Detection"])


class RiskEvaluationResponse(BaseModel):
    patient_id: str
    risk_level: RiskLevel
    probability: float
    spo2: float
    bpm: int
    activity: int
    explanation: str
    alert_sent: bool
    evaluated_at: datetime


@router.post("/evaluate", response_model=RiskEvaluationResponse)
async def evaluate_risk(
    patient_id: str = Query("PAT-001", description="ID del paciente"),
    scenario: str = Query("normal", description="Escenario: normal | moderate | critical"),
    current_user: User = Depends(get_current_user)
):
    """
    Genera una lectura simulada y la evalúa con el motor de riesgo completo.
    (Operativo para todos los usuarios autenticados para demostración PMV1).
    Extiende el endpoint /simulate/reading añadiendo clasificación de IA.
    """
    reading = simulated_data_generator.generate_reading(patient_id, scenario)  # type: ignore

    event = evaluar_riesgo_use_case.execute(patient_id, reading)

    alert_sent = False
    if event.is_critical():
        alert_sent = gestionar_alerta_use_case.execute(event)

    return RiskEvaluationResponse(
        patient_id=event.patient_id,
        risk_level=event.risk_level,
        probability=event.probability,
        spo2=event.spo2_at_event,
        bpm=event.bpm_at_event,
        activity=event.activity_at_event,
        explanation="",
        alert_sent=alert_sent,
        evaluated_at=event.detected_at,
    )


@router.get("/history/{patient_id}")
async def get_history(
    patient_id: str, 
    limit: int = Query(50, ge=1, le=200),
    current_user: User = Depends(get_current_user)
):
    """Retorna el historial de lecturas biométricas de un paciente."""
    from src.infrastructure.configuration.container import signal_repository
    readings = signal_repository.get_history(patient_id, limit)
    return [
        {
            "spo2": r.spo2,
            "bpm": r.bpm,
            "activity": r.activity,
            "timestamp": r.timestamp.isoformat(),
        }
        for r in readings
    ]


@router.get("/db-status", tags=["Health"])
async def db_status():
    """
    Verifica el tipo de repositorio activo y la conexión a la BD.
    Útil para confirmar que PostgreSQL está conectado correctamente.
    """
    from src.infrastructure.configuration.container import signal_repository
    from src.infrastructure.configuration.settings import settings

    repo_type = type(signal_repository).__name__

    if hasattr(signal_repository, "test_connection"):
        try:
            info = signal_repository.test_connection()
            return {
                "storage_backend": settings.STORAGE_BACKEND,
                "repository": repo_type,
                "status": "connected",
                "db_version": info.get("db_version", ""),
            }
        except Exception as e:
            return {"storage_backend": settings.STORAGE_BACKEND, "repository": repo_type, "status": "error", "detail": str(e)}

    return {
        "storage_backend": settings.STORAGE_BACKEND,
        "repository": repo_type,
        "status": "in-memory (no DB connection)",
        "note": "Cambia STORAGE_BACKEND=postgres en .env para usar PostgreSQL",
    }
