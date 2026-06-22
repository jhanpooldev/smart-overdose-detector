"""
telemetry_controller.py — Adaptador de entrada para ingesta de telemetría IoT (PMV2).

Endpoints:
    POST /api/v2/telemetry/stream        — Ingestar señal IoT (RF04)
    POST /api/v2/telemetry/sessions      — Crear sesión IoT con token (RF04)
    GET  /api/v2/telemetry/sessions/{t}  — Estado de sesión / heartbeat (RF08)
    GET  /api/v2/telemetry/status/{pid}  — Estado online del paciente para Supervisor
    GET  /api/v2/telemetry/history/{pid} — Historial con filtro de timestamp (RF13)
    GET  /api/v2/telemetry/export/{pid}  — Exportar PDF/Excel (RF14)
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field, field_validator

from src.application.useCases.monitorizar_signos_use_case import (
    MonitorizarSignosUseCase,
    TelemetryInput,
)
from src.domain.entities.iot_session import IoTSession, IoTStreamStatus
from src.infrastructure.adapters.input.controllers.auth_controller import get_current_user
from src.domain.entities.user import User, Role
from src.infrastructure.configuration.container_v2 import (
    monitorizar_signos_use_case,
    iot_session_repository,
    biometric_signal_repository,
    patient_repository_v2,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v2/telemetry", tags=["Telemetry PMV2"])


# ── DTOs de entrada/salida ────────────────────────────────────────────────────
class TelemetryStreamRequest(BaseModel):
    """Payload del Simulador IoT — RF04."""
    session_token:   str = Field(..., min_length=6, max_length=6, description="Token IoT de 6 chars")
    device_id:       str = Field(default_factory=lambda: str(uuid.uuid4()))
    heart_rate:      int = Field(..., ge=10, le=300, description="BPM")
    spo2:            int = Field(..., ge=0,  le=100, description="% Saturación")
    resp_rate:       Optional[int] = Field(None, ge=0, le=60, description="Resp/min (RF04)")
    status_movement: str = Field(default="UNKNOWN", description="STILL|WALKING|RUNNING|UNKNOWN")
    recorded_at:     Optional[datetime] = Field(None, description="Timestamp del dispositivo (ISO)")

    @field_validator("session_token")
    @classmethod
    def token_must_be_alphanumeric(cls, v: str) -> str:
        if not v.isalnum():
            raise ValueError("El token de sesion debe ser alfanumerico")
        return v.upper()


class TelemetryStreamResponse(BaseModel):
    patient_id:      str
    risk_level:      str
    heart_rate:      int
    spo2:            int
    resp_rate:       Optional[int]
    status_movement: str
    alert_triggered: bool
    stream_status:   str
    processed_at:    datetime


class CreateSessionRequest(BaseModel):
    """El paciente solicita un nuevo token IoT desde la app."""
    pass  # Solo necesita auth JWT — el patient_id viene del token


class SessionStatusResponse(BaseModel):
    session_token: str
    patient_id:    str
    stream_status: str
    last_heartbeat: Optional[datetime]
    expires_at:    Optional[datetime]
    is_active:     bool


class PatientOnlineStatus(BaseModel):
    """Respuesta de estado online para el Supervisor (RF — Sincronización)."""
    patient_id:   str
    status_online: bool
    stream_status: str
    last_seen:    Optional[datetime]


class SignalHistoryResponse(BaseModel):
    time:            datetime
    heart_rate:      int
    spo2:            int
    resp_rate:       Optional[int]
    status_movement: str


# ── Endpoints ─────────────────────────────────────────────────────────────────
@router.post(
    "/stream",
    response_model=TelemetryStreamResponse,
    status_code=status.HTTP_200_OK,
    summary="Ingesta de señal biométrica IoT (RF04)",
)
async def ingest_telemetry_stream(
    payload: TelemetryStreamRequest,
    current_user: User = Depends(get_current_user),
) -> TelemetryStreamResponse:
    """
    Endpoint principal de telemetría IoT.

    Recibe una lectura biométrica del Simulador IoT, valida el token de sesión
    de 6 caracteres, persiste la señal y evalúa el nivel de riesgo.
    En caso de riesgo CRÍTICO dispara notificaciones a contactos de emergencia.

    **Flujo:**
    1. Validar token de sesión IoT (6 chars alfanuméricos).
    2. Mapear payload → BiometricSignal (Value Object).
    3. Persistir en repositorio de series temporales (TimescaleDB).
    4. Clasificar riesgo: Normal / Moderado / Crítico.
    5. Si crítico → notificar contactos por SMS/llamada.
    6. Actualizar heartbeat de sesión.
    """
    try:
        result = await monitorizar_signos_use_case.execute(
            TelemetryInput(
                session_token=payload.session_token,
                device_id=payload.device_id,
                heart_rate=payload.heart_rate,
                spo2=payload.spo2,
                resp_rate=payload.resp_rate,
                status_movement=payload.status_movement,
                recorded_at=payload.recorded_at,
            )
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        )
    except Exception as exc:
        logger.exception("Error inesperado en ingesta de telemetría: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error interno al procesar la señal",
        )

    return TelemetryStreamResponse(**result.__dict__)


@router.post(
    "/sessions",
    response_model=SessionStatusResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear sesión IoT con token de 6 chars (RF04)",
)
async def create_iot_session(
    current_user: User = Depends(get_current_user),
) -> SessionStatusResponse:
    """
    El paciente solicita un nuevo token de emparejamiento IoT desde la app.
    Solo los pacientes pueden crear sesiones.
    """
    if current_user.role != Role.PACIENTE:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo los pacientes pueden crear sesiones IoT",
        )

    # Invalidar sesión anterior si existe
    existing = await iot_session_repository.get_active_session(current_user.id)
    if existing and existing.is_active():
        await iot_session_repository.update_status(
            existing.session_token, IoTStreamStatus.DISCONNECTED
        )

    session = IoTSession.create_new(patient_id=current_user.id)
    saved = await iot_session_repository.create_session(session)

    return SessionStatusResponse(
        session_token=saved.session_token,
        patient_id=saved.patient_id,
        stream_status=saved.stream_status.value,
        last_heartbeat=saved.last_heartbeat,
        expires_at=saved.expires_at,
        is_active=saved.is_active(),
    )


@router.get(
    "/sessions/{token}",
    response_model=SessionStatusResponse,
    summary="Estado de sesión IoT (RF08 — Heartbeat)",
)
async def get_session_status(
    token: str,
    current_user: User = Depends(get_current_user),
) -> SessionStatusResponse:
    """Consulta el estado actual del stream IoT por su token."""
    session = await iot_session_repository.get_by_token(token.upper())
    if session is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Sesión '{token}' no encontrada",
        )

    return SessionStatusResponse(
        session_token=session.session_token,
        patient_id=session.patient_id,
        stream_status=session.stream_status.value,
        last_heartbeat=session.last_heartbeat,
        expires_at=session.expires_at,
        is_active=session.is_active(),
    )


@router.get(
    "/status/{patient_id}",
    response_model=PatientOnlineStatus,
    summary="Estado online del paciente para Supervisor",
)
async def get_patient_online_status(
    patient_id: str,
    current_user: User = Depends(get_current_user),
) -> PatientOnlineStatus:
    """
    El Supervisor consulta si un paciente está transmitiendo telemetría activa.
    Polling de alta frecuencia desde la app del supervisor (RF — Sincronización).
    """
    if current_user.role not in (Role.SUPERVISOR, Role.PACIENTE):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="No autorizado")

    is_online = await iot_session_repository.is_patient_online(patient_id)
    session   = await iot_session_repository.get_active_session(patient_id)

    return PatientOnlineStatus(
        patient_id=patient_id,
        status_online=is_online,
        stream_status=session.stream_status.value if session else IoTStreamStatus.DISCONNECTED.value,
        last_seen=session.last_heartbeat if session else None,
    )


@router.get(
    "/history/{patient_id}",
    response_model=List[SignalHistoryResponse],
    summary="Historial biométrico con filtro ISO timestamp (RF13)",
)
async def get_signal_history(
    patient_id: str,
    limit:      int             = Query(100, ge=1, le=500),
    from_ts:    Optional[datetime] = Query(None, description="Desde (ISO 8601 UTC)"),
    to_ts:      Optional[datetime] = Query(None, description="Hasta (ISO 8601 UTC)"),
    current_user: User = Depends(get_current_user),
) -> List[SignalHistoryResponse]:
    """
    Retorna historial de señales filtrado por rango de timestamps (RF13).

    RBAC:
      - Paciente: solo puede consultar su propio historial.
      - Supervisor: solo puede consultar pacientes que le estén asignados.
    """
    # ── RBAC ─────────────────────────────────────────────────────────────────
    if current_user.role == Role.PACIENTE and current_user.id != patient_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para acceder al historial de otro paciente",
        )

    if current_user.role == Role.SUPERVISOR:
        # Verificar que el paciente solicitado pertenece a este supervisor
        target = await patient_repository_v2.get_by_id(patient_id)
        if target is None:
            raise HTTPException(status_code=404, detail="Paciente no encontrado")
        if getattr(target, "supervisor_email", None) != current_user.email:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Este paciente no está asignado a tu cuenta de supervisor",
            )
    # ─────────────────────────────────────────────────────────────────────────

    try:
        signals = await biometric_signal_repository.get_history(
            patient_id, limit=limit, from_ts=from_ts, to_ts=to_ts
        )
    except Exception as exc:
        logger.exception("Error al obtener historial del paciente %s: %s", patient_id, exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="No se pudo obtener el historial. Intente más tarde.",
        )

    return [
        SignalHistoryResponse(
            time=s.time,
            heart_rate=s.heart_rate,
            spo2=s.spo2,
            resp_rate=s.resp_rate,
            status_movement=s.status_movement.value,
        )
        for s in signals
    ]

