from typing import Protocol
from src.domain.entities.risk_event import RiskEvent
from src.domain.entities.emergency_contact import EmergencyContact


class IAlertNotificationPort(Protocol):
    """Puerto de salida — Notificaciones de alerta crítica."""

    def send_sms(self, contact: EmergencyContact, message: str) -> bool: ...

    def send_push(self, patient_id: str, event: RiskEvent) -> bool: ...
