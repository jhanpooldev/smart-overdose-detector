from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from typing import Optional


class RiskLevel(str, Enum):
    NORMAL = "NORMAL"
    MODERATE = "MODERATE"
    CRITICAL = "CRITICAL"


@dataclass
class RiskEvent:
    """Entidad de dominio — Evento de riesgo detectado por la IA."""
    patient_id: str
    risk_level: RiskLevel
    probability: float
    spo2_at_event: float
    bpm_at_event: int
    activity_at_event: int
    detected_at: datetime
    alert_sent: bool = False
    event_id: str = ""

    def is_critical(self) -> bool:
        return self.risk_level == RiskLevel.CRITICAL

    def requires_emergency_call(self) -> bool:
        """UCn-IA-06: Regla clínica forzada independiente del modelo."""
        return self.spo2_at_event < 82 and self.bpm_at_event < 50


@dataclass
class RiskPredictionResult:
    """Resultado del puerto IAnomalyDetectionPort."""
    risk_level: RiskLevel
    probability: float
    explanation: str = ""
