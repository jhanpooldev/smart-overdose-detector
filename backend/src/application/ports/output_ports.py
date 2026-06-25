"""
output_ports.py — Puertos de Salida (Output Ports / Interfaces) para PMV2.
Define los contratos que los adaptadores de infraestructura deben implementar.
Arquitectura Hexagonal — capa de dominio/aplicación, sin dependencias externas.
"""
from abc import ABC, abstractmethod
from datetime import datetime
from typing import List, Optional, Sequence, Tuple

from src.domain.entities.biometric_signal import BiometricSignal
from src.domain.entities.emergency_contact import EmergencyContact
from src.domain.entities.iot_session import IoTSession, IoTStreamStatus
from src.domain.entities.risk_event import RiskEvent
from src.domain.entities.user import User


# ── Puerto 1: Repositorio de Señales Biométricas (Series Temporales) ─────────
class IBiometricSignalRepository(ABC):
    """
    Output Port — Contrato para la persistencia de telemetría biométrica.
    El adaptador concreto puede ser TimescaleDB, InfluxDB, en-memoria, etc.
    """

    @abstractmethod
    async def ingest(self, signal: BiometricSignal) -> None:
        """Persiste una señal biométrica individual (ingesta en tiempo real)."""
        ...

    @abstractmethod
    async def ingest_batch(self, signals: Sequence[BiometricSignal]) -> int:
        """
        Ingesta masiva para reducir overhead de red.
        Retorna el número de registros insertados.
        """
        ...

    @abstractmethod
    async def get_latest(self, patient_id: str) -> Optional[BiometricSignal]:
        """Retorna la lectura más reciente de un paciente."""
        ...

    @abstractmethod
    async def get_history(
        self,
        patient_id: str,
        *,
        limit:    int = 100,
        from_ts:  Optional[datetime] = None,
        to_ts:    Optional[datetime] = None,
    ) -> List[BiometricSignal]:
        """
        Historial filtrado por rango de timestamps ISO (RF13).
        Ordenado por tiempo descendente.
        """
        ...

    @abstractmethod
    async def get_moving_average(
        self,
        patient_id: str,
        window_minutes: int = 5,
    ) -> Tuple[Optional[float], Optional[float]]:
        """
        Calcula la media móvil de SpO2 y BPM en una ventana temporal (RF13).
        Retorna (sma_spo2, sma_bpm).
        """
        ...


# ── Puerto 2: Repositorio de Pacientes y Contactos ────────────────────────────
class IPatientRepository(ABC):
    """
    Output Port — CRUD de usuarios (pacientes/supervisores) y contactos de emergencia.
    """

    @abstractmethod
    def get_by_id(self, patient_id: str) -> Optional[User]:
        """Obtiene un usuario por su UUID."""
        ...

    @abstractmethod
    def get_by_email(self, email: str) -> Optional[User]:
        """Obtiene un usuario por email (login)."""
        ...

    @abstractmethod
    async def create(self, user: User) -> User:
        """Persiste un nuevo usuario. Lanza ValueError si el email ya existe."""
        ...

    @abstractmethod
    async def update_bio_profile(self, patient_id: str, profile: dict) -> None:
        """Actualiza el perfil biométrico base (JSONB) del paciente."""
        ...

    @abstractmethod
    async def get_patients_by_supervisor(self, supervisor_email: str) -> List[User]:
        """Lista todos los pacientes asignados a un supervisor."""
        ...

    @abstractmethod
    async def get_contacts(
        self,
        patient_id: str,
        *,
        ordered_by_priority: bool = True,
    ) -> List[EmergencyContact]:
        """
        Retorna los contactos de emergencia del paciente ordenados por prioridad (RF03).
        """
        ...

    @abstractmethod
    async def add_contact(
        self,
        patient_id:             str,
        contact:                EmergencyContact,
        parentesco:             str = "Familiar",
        prioridad_notificacion: int = 3,
    ) -> EmergencyContact:
        """Asocia un contacto de emergencia al paciente con parentesco y prioridad."""
        ...

    @abstractmethod
    async def remove_contact(self, patient_id: str, contact_id: str) -> bool:
        """Desvincula un contacto de emergencia de un paciente. Retorna True si existía."""
        ...


# ── Puerto 3: Gateway de Notificaciones de Alerta ────────────────────────────
class IAlertaNotificationGateway(ABC):
    """
    Output Port — Contrato para disparo de SMS y llamadas de emergencia (RF06).
    El adaptador concreto puede ser Twilio, un mock de pruebas, etc.
    """

    @abstractmethod
    async def send_sms(
        self,
        to_number: str,
        message:   str,
        *,
        patient_name:  Optional[str] = None,
        risk_level:    Optional[str] = None,
    ) -> bool:
        """
        Envía SMS a un número destino.
        Retorna True si el mensaje fue aceptado por el proveedor.
        """
        ...

    @abstractmethod
    async def make_call(
        self,
        to_number:  str,
        twiml_url:  Optional[str] = None,
        *,
        message:    Optional[str] = None,
    ) -> bool:
        """
        Inicia una llamada de voz de emergencia.
        Retorna True si la llamada fue iniciada correctamente.
        """
        ...

    @abstractmethod
    async def notify_contacts(
        self,
        contacts:      List[EmergencyContact],
        event:         RiskEvent,
        patient_name:  Optional[str] = None,
    ) -> List[bool]:
        """
        Notifica a todos los contactos ordenados por prioridad.
        Retorna lista de resultados (True=éxito) en orden de ejecución.
        """
        ...


# ── Puerto 4: Repositorio de Sesiones IoT ─────────────────────────────────────
class IIoTSessionRepository(ABC):
    """
    Output Port — Gestión de sesiones de emparejamiento IoT (RF04/RF08).
    """

    @abstractmethod
    async def create_session(self, session: IoTSession) -> IoTSession:
        """Persiste una nueva sesión IoT."""
        ...

    @abstractmethod
    async def get_by_token(self, token: str) -> Optional[IoTSession]:
        """Busca una sesión por su token de 6 chars."""
        ...

    @abstractmethod
    async def get_active_session(self, patient_id: str) -> Optional[IoTSession]:
        """Retorna la sesión activa de un paciente, si existe."""
        ...

    @abstractmethod
    async def update_status(
        self, token: str, status: IoTStreamStatus, heartbeat: bool = False
    ) -> None:
        """Actualiza el estado del stream y opcionalmente registra un heartbeat."""
        ...

    @abstractmethod
    async def is_patient_online(self, patient_id: str) -> bool:
        """
        Retorna True si el paciente tiene una sesión CONNECTED activa (RF — Supervisor).
        """
        ...
