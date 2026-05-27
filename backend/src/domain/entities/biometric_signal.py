"""
biometric_signal.py — Value Object de dominio para señales biométricas PMV2.
Sin dependencias de frameworks ni ORMs. Pure Python.
"""
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Optional
import uuid


class MovementStatus(str, Enum):
    """Estado de movimiento del paciente (RF04)."""
    STILL    = "STILL"
    WALKING  = "WALKING"
    RUNNING  = "RUNNING"
    UNKNOWN  = "UNKNOWN"


@dataclass(frozen=True)
class BiometricSignal:
    """
    Value Object — Señal biométrica inmutable capturada por el dispositivo IoT.

    Represents a single telemetry reading. Immutable by design to prevent
    accidental mutation after ingestion (DDD Value Object pattern).

    Attributes:
        time:            Timestamp de la lectura (UTC).
        device_id:       UUID del dispositivo IoT emisor.
        patient_id:      UUID del paciente vinculado.
        heart_rate:      Frecuencia cardíaca en BPM (RF04).
        spo2:            Saturación de oxígeno en % entero (RF04).
        resp_rate:       Frecuencia respiratoria en resp/min (RF04, opcional).
        status_movement: Estado de movimiento del sensor (RF04).
        session_token:   Token IoT de 6 chars de la sesión activa.
        source:          Origen de la señal ('iot', 'simulator', 'manual').
    """
    time:             datetime
    device_id:        str
    patient_id:       str
    heart_rate:       int
    spo2:             int
    status_movement:  MovementStatus = MovementStatus.UNKNOWN
    resp_rate:        Optional[int]  = None
    session_token:    Optional[str]  = None
    source:           str            = "iot"

    def __post_init__(self) -> None:
        """Invariantes del Value Object — validación al construir."""
        if not (0 <= self.spo2 <= 100):
            raise ValueError(f"SpO2 fuera de rango clínico: {self.spo2}%. Rango válido: 0-100%")
        if not (10 <= self.heart_rate <= 300):
            raise ValueError(f"Frecuencia cardíaca fuera de rango: {self.heart_rate} BPM")
        if self.resp_rate is not None and not (0 <= self.resp_rate <= 60):
            raise ValueError(f"Frecuencia respiratoria fuera de rango: {self.resp_rate}")
        if self.session_token and len(self.session_token) != 6:
            raise ValueError("El token de sesión IoT debe tener exactamente 6 caracteres")

    @property
    def bpm(self) -> int:
        return self.heart_rate

    @property
    def timestamp(self) -> datetime:
        return self.time

    @property
    def activity(self) -> int:
        # STILL/UNKNOWN -> 0, WALKING/RUNNING -> 1
        return 1 if self.status_movement in (MovementStatus.WALKING, MovementStatus.RUNNING) else 0

    @classmethod
    def create(
        cls,
        patient_id: str,
        device_id:  str,
        heart_rate: int,
        spo2:       int,
        *,
        resp_rate:       Optional[int]  = None,
        status_movement: MovementStatus = MovementStatus.UNKNOWN,
        session_token:   Optional[str]  = None,
        source:          str            = "iot",
        at:              Optional[datetime] = None,
    ) -> "BiometricSignal":
        """Factory method — crea una señal con timestamp UTC automático si no se provee."""
        return cls(
            time=at or datetime.utcnow(),
            device_id=device_id or str(uuid.uuid4()),
            patient_id=patient_id,
            heart_rate=heart_rate,
            spo2=spo2,
            resp_rate=resp_rate,
            status_movement=status_movement,
            session_token=session_token,
            source=source,
        )

