"""
StubAlertService — Adaptador stub de alertas para PMV1.
En PMV2 será sustituido por Twilio_SMS_Adapter y FCM_Push_Adapter.
"""
import logging
from src.domain.entities.risk_event import RiskEvent
from src.domain.entities.emergency_contact import EmergencyContact
from src.domain.ports.i_alert_notification_port import IAlertNotificationPort

logger = logging.getLogger(__name__)


class StubAlertService(IAlertNotificationPort):
    """Stub — Registra alertas en log. Listo para conectar Twilio en PMV2."""

    def send_sms(self, contact: EmergencyContact, message: str) -> bool:
        logger.warning(
            "📲 [STUB SMS] → %s (%s): %s",
            contact.nombre,
            contact.telefono,
            message,
        )
        return True

    def send_push(self, patient_id: str, event: RiskEvent) -> bool:
        logger.warning(
            "🔔 [STUB PUSH] → Paciente %s | Riesgo: %s | Prob: %.2f",
            patient_id,
            event.risk_level,
            event.probability,
        )
        return True
