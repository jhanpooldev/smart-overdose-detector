"""
StubAlertService — Adaptador stub de alertas para PMV1.
StubAlertGatewayV2 — Adaptador stub para PMV2 (IAlertaNotificationGateway).
En PMV3 serán sustituidos por Twilio_SMS_Adapter y FCM_Push_Adapter.
"""
import logging
from typing import List, Optional

from src.domain.entities.risk_event import RiskEvent
from src.domain.entities.emergency_contact import EmergencyContact
from src.domain.ports.i_alert_notification_port import IAlertNotificationPort
from src.application.ports.output_ports import IAlertaNotificationGateway

logger = logging.getLogger(__name__)


class StubAlertService(IAlertNotificationPort):
    """Stub PMV1 — Registra alertas en log. Listo para conectar Twilio en PMV2."""

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


class StubAlertGatewayV2(IAlertaNotificationGateway):
    """Stub PMV2 — Implementa IAlertaNotificationGateway con métodos async para MonitorizarSignosUseCase."""

    async def send_sms(
        self,
        to_number: str,
        message: str,
        *,
        patient_name: Optional[str] = None,
        risk_level: Optional[str] = None,
    ) -> bool:
        logger.warning(
            "📲 [STUB SMS V2] → %s | Riesgo: %s | Mensaje: %s",
            to_number, risk_level or "N/A", message[:60],
        )
        return True

    async def make_call(
        self,
        to_number: str,
        twiml_url: Optional[str] = None,
        *,
        message: Optional[str] = None,
    ) -> bool:
        logger.warning("📞 [STUB CALL V2] → %s", to_number)
        return True

    async def notify_contacts(
        self,
        contacts: List[EmergencyContact],
        event: RiskEvent,
        patient_name: Optional[str] = None,
    ) -> List[bool]:
        results = []
        for contact in contacts:
            logger.warning(
                "🚨 [STUB NOTIFY V2] → %s (%s) | Nivel: %s",
                contact.nombre, contact.telefono, event.risk_level.value,
            )
            results.append(True)
        return results
