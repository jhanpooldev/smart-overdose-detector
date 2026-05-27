"""
monitorizar_signos_use_case.py — Caso de uso principal PMV2 (RF04/05/06).

Orquesta:
1. Validar token de sesión IoT.
2. Mapear DTO → BiometricSignal (Value Object).
3. Persistir la señal en el repositorio de series temporales.
4. Clasificar el nivel de riesgo en tiempo real.
5. Si es CRÍTICO/MODERADO → guardar RiskEvent + notificar contactos.
6. Actualizar heartbeat de la sesión IoT.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime
from typing import Optional

from src.application.ports.output_ports import (
    IBiometricSignalRepository,
    IAlertaNotificationGateway,
    IIoTSessionRepository,
    IPatientRepository,
)
from src.domain.entities.biometric_signal import BiometricSignal, MovementStatus
from src.domain.entities.iot_session import IoTStreamStatus
from src.domain.entities.risk_event import RiskEvent, RiskLevel

logger = logging.getLogger(__name__)


# ── DTOs del caso de uso ──────────────────────────────────────────────────────
@dataclass
class TelemetryInput:
    """DTO de entrada — payload del simulador IoT (RF04)."""
    session_token:   str                    # 6 chars
    device_id:       str
    heart_rate:      int
    spo2:            int
    resp_rate:       Optional[int]          = None
    status_movement: str                    = "UNKNOWN"
    recorded_at:     Optional[datetime]     = None


@dataclass
class TelemetryOutput:
    """DTO de salida — resultado procesado devuelto al controlador."""
    patient_id:      str
    risk_level:      str
    heart_rate:      int
    spo2:            int
    resp_rate:       Optional[int]
    status_movement: str
    alert_triggered: bool
    stream_status:   str
    processed_at:    datetime


# ── Clasificador de riesgo (reglas RF05) ─────────────────────────────────────
def classify_risk(heart_rate: int, spo2: int) -> RiskLevel:
    """
    Clasifica el riesgo según las reglas RF05:
        Normal/Leve: SpO2 >= 95% y HR 60-100 BPM.
        Moderado:    SpO2 90-94% o HR 50-59 / 101-120 BPM.
        Crítico:     SpO2 < 90% o HR < 50 / > 120 BPM.
    """
    if spo2 < 90 or heart_rate < 50 or heart_rate > 120:
        return RiskLevel.CRITICAL
    if spo2 < 95 or heart_rate < 60 or heart_rate > 100:
        return RiskLevel.MODERATE
    return RiskLevel.NORMAL


# ── Caso de uso ────────────────────────────────────────────────────────────────
class MonitorizarSignosUseCase:
    """
    UC-01 — Monitorizar Signos Vitales.
    Punto de entrada para telemetría IoT en tiempo real.
    """

    def __init__(
        self,
        signal_repository:  IBiometricSignalRepository,
        session_repository: IIoTSessionRepository,
        patient_repository: IPatientRepository,
        alert_gateway:      IAlertaNotificationGateway,
        *,
        notify_on_moderate: bool = False,
    ) -> None:
        self._signals  = signal_repository
        self._sessions = session_repository
        self._patients = patient_repository
        self._alerts   = alert_gateway
        self._notify_on_moderate = notify_on_moderate

    async def execute(self, payload: TelemetryInput) -> TelemetryOutput:
        """
        Ejecuta el flujo principal de ingesta de telemetría.

        Raises:
            ValueError: Token inválido, expirado o paciente no encontrado.
        """
        # ── Paso 1: Validar sesión IoT ───────────────────────────────────────
        session = await self._sessions.get_by_token(payload.session_token)
        if session is None:
            raise ValueError(f"Token de sesión IoT no válido: '{payload.session_token}'")
        if session.is_expired():
            raise ValueError(f"Sesión IoT '{payload.session_token}' ha expirado")

        patient_id = session.patient_id

        # ── Paso 2: Mapear DTO → Value Object ───────────────────────────────
        try:
            movement = MovementStatus(payload.status_movement.upper())
        except ValueError:
            movement = MovementStatus.UNKNOWN

        signal = BiometricSignal.create(
            patient_id=patient_id,
            device_id=payload.device_id,
            heart_rate=payload.heart_rate,
            spo2=payload.spo2,
            resp_rate=payload.resp_rate,
            status_movement=movement,
            session_token=payload.session_token,
            at=payload.recorded_at,
        )

        # ── Paso 3: Persistir señal ──────────────────────────────────────────
        await self._signals.ingest(signal)

        # ── Paso 4: Clasificar riesgo ────────────────────────────────────────
        risk_level = classify_risk(signal.heart_rate, signal.spo2)
        alert_triggered = False

        # ── Paso 5: Generar evento y notificar si aplica ─────────────────────
        should_alert = risk_level == RiskLevel.CRITICAL or (
            self._notify_on_moderate and risk_level == RiskLevel.MODERATE
        )

        if should_alert:
            # Calcular media móvil para enriquecer el evento
            sma_spo2, sma_bpm = await self._signals.get_moving_average(patient_id)

            event = RiskEvent(
                event_id="",  # El repositorio asigna UUID
                patient_id=patient_id,
                detected_at=signal.time,
                risk_level=risk_level,
                probability=1.0,
                spo2_at_event=signal.spo2,
                bpm_at_event=signal.heart_rate,
                activity_at_event=0,
            )

            # Notificar a contactos en orden de prioridad
            contacts = await self._patients.get_contacts(patient_id, ordered_by_priority=True)
            if contacts:
                results = await self._alerts.notify_contacts(contacts, event)
                alert_triggered = any(results)
                logger.info(
                    "🚨 Alerta %s para paciente %s — notificados %d/%d contactos",
                    risk_level.value, patient_id, sum(results), len(results)
                )

        # ── Paso 6: Actualizar heartbeat de sesión ───────────────────────────
        await self._sessions.update_status(
            payload.session_token,
            IoTStreamStatus.CONNECTED,
            heartbeat=True,
        )

        return TelemetryOutput(
            patient_id=patient_id,
            risk_level=risk_level.value,
            heart_rate=signal.heart_rate,
            spo2=signal.spo2,
            resp_rate=signal.resp_rate,
            status_movement=signal.status_movement.value,
            alert_triggered=alert_triggered,
            stream_status=IoTStreamStatus.CONNECTED.value,
            processed_at=signal.time,
        )
