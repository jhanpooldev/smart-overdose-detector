"""
GestionarAlertaUseCase — Caso de uso: orquestar notificaciones ante evento crítico.
"""
from src.domain.entities.risk_event import RiskEvent, RiskLevel
from src.domain.entities.emergency_contact import EmergencyContact
from src.domain.ports.i_alert_notification_port import IAlertNotificationPort
import time


class GestionarAlertaUseCase:
    """
    Orquesta el envío de notificaciones SMS y push cuando se detecta riesgo alto.
    Solo actúa si risk_level >= MODERATE según configuración.
    """

    def __init__(
        self,
        alert_port: IAlertNotificationPort,
        contacts: list[EmergencyContact],
        notify_on_moderate: bool = False,
    ):
        self._alert_port = alert_port
        self._contacts = contacts
        self._notify_on_moderate = notify_on_moderate
        self._last_alerts: dict[str, float] = {}

    def execute(self, event: RiskEvent) -> bool:
        if event.risk_level == RiskLevel.NORMAL:
            return False

        if event.risk_level == RiskLevel.MODERATE and not self._notify_on_moderate:
            return False

        current_time = time.time()
        last_time = self._last_alerts.get(event.patient_id, 0.0)
        if current_time - last_time < 5.0:
            return False  # Cooldown de 5 segundos

        self._last_alerts[event.patient_id] = current_time

        message = self._build_message(event)
        sent = False

        for contact in self._contacts:
            if event.risk_level == RiskLevel.CRITICAL or contact.es_principal:
                sms_ok = self._alert_port.send_sms(contact, message)
                push_ok = self._alert_port.send_push(event.patient_id, event)
                if sms_ok or push_ok:
                    sent = True

        return sent

    def _build_message(self, event: RiskEvent) -> str:
        if event.risk_level == RiskLevel.CRITICAL:
            return (
                f"🚨 ALERTA CRÍTICA — Paciente ID: {event.patient_id}\n"
                f"SpO2: {event.spo2_at_event}% | FC: {event.bpm_at_event} BPM\n"
                f"Probabilidad riesgo: {event.probability * 100:.1f}%\n"
                "Llamar a Emergencias (911) INMEDIATAMENTE."
            )
        return (
            f"⚠️ Alerta Moderada — Paciente ID: {event.patient_id}\n"
            f"SpO2: {event.spo2_at_event}% | FC: {event.bpm_at_event} BPM\n"
            "Monitorear de cerca."
        )
