"""
iot_session.py — Entidad de dominio para sesiones de emparejamiento IoT (RF04/RF08).
El token de 6 chars es el mecanismo de binding entre app móvil y stream simulador.
"""
from dataclasses import dataclass
from datetime import datetime, timedelta
from enum import Enum
from typing import Optional
import random
import string


class IoTStreamStatus(str, Enum):
    """Estado del canal de telemetría (RF08)."""
    CONNECTED    = "CONNECTED"
    DISCONNECTED = "DISCONNECTED"
    STREAM_ERROR = "STREAM_ERROR"


@dataclass
class IoTSession:
    """
    Entidad de dominio — Sesión de emparejamiento entre dispositivo IoT y paciente.

    El token de 6 caracteres alfanuméricos actúa como canal de comunicación
    temporal. El paciente lo genera desde la app y el simulador IoT lo usa
    para direccionar las señales al paciente correcto.

    Attributes:
        session_token:  Token único 6 chars (e.g. "A3F9XZ").
        patient_id:     UUID del paciente dueño de la sesión.
        stream_status:  Estado actual del canal (RF08).
        last_heartbeat: Último timestamp de señal recibida.
        created_at:     Timestamp de creación de la sesión.
        expires_at:     Expiración automática (24h por defecto).
    """
    session_token:  str
    patient_id:     str
    stream_status:  IoTStreamStatus = IoTStreamStatus.DISCONNECTED
    last_heartbeat: Optional[datetime] = None
    created_at:     Optional[datetime] = None
    expires_at:     Optional[datetime] = None

    def __post_init__(self) -> None:
        if len(self.session_token) != 6:
            raise ValueError("El token de sesión IoT debe tener exactamente 6 caracteres")
        if self.created_at is None:
            self.created_at = datetime.utcnow()
        if self.expires_at is None:
            self.expires_at = self.created_at + timedelta(hours=24)

    def is_expired(self) -> bool:
        """Verifica si la sesión ha expirado."""
        now = datetime.utcnow()
        expires = self.expires_at
        if expires is not None:
            if expires.tzinfo is not None:
                expires = expires.replace(tzinfo=None)
            return now > expires
        return False

    def is_active(self) -> bool:
        """Sesión activa = conectada y no expirada."""
        return self.stream_status == IoTStreamStatus.CONNECTED and not self.is_expired()

    def mark_connected(self) -> None:
        self.stream_status = IoTStreamStatus.CONNECTED
        self.last_heartbeat = datetime.utcnow()

    def mark_disconnected(self) -> None:
        self.stream_status = IoTStreamStatus.DISCONNECTED

    def mark_error(self) -> None:
        self.stream_status = IoTStreamStatus.STREAM_ERROR

    def update_heartbeat(self) -> None:
        """Registra un latido de señal — mantiene viva la sesión."""
        self.last_heartbeat = datetime.utcnow()
        if self.stream_status != IoTStreamStatus.CONNECTED:
            self.stream_status = IoTStreamStatus.CONNECTED

    @staticmethod
    def generate_token() -> str:
        """Genera un token alfanumérico único de 6 caracteres en mayúsculas."""
        charset = string.ascii_uppercase + string.digits
        return "".join(random.choices(charset, k=6))

    @classmethod
    def create_new(cls, patient_id: str) -> "IoTSession":
        """Factory — crea una sesión nueva con token generado automáticamente."""
        token = cls.generate_token()
        return cls(
            session_token=token,
            patient_id=patient_id,
            stream_status=IoTStreamStatus.DISCONNECTED,
        )
