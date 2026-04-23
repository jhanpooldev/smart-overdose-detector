"""
CalculadoraRiesgoService — Capa de seguridad clínica (UC-IA-06).

Esta clase implementa las reglas de negocio puras del dominio:
- Evalúa umbrales clínicos críticos.
- Delega la inferencia al IAnomalyDetectionPort.
- No importa ningún framework externo.
"""
from src.domain.entities.risk_event import RiskLevel, RiskPredictionResult
from src.domain.valueObjects.biometric_features import BiometricFeatures
from src.domain.ports.i_anomaly_detection_port import IAnomalyDetectionPort


class CalculadoraRiesgoService:
    """Servicio de dominio — Orquesta la clasificación de riesgo con reglas clínicas."""

    # Umbrales de alerta clínica forzada (UC-IA-06)
    CRITICAL_SPO2_THRESHOLD = 85.0
    CRITICAL_BPM_LOW = 50

    def __init__(self, anomaly_detection_port: IAnomalyDetectionPort):
        self._ai_port = anomaly_detection_port

    def evaluar(self, features: BiometricFeatures) -> RiskPredictionResult:
        # UC-IA-06: Regla clínica forzada — ignora el modelo si los umbrales son críticos
        if features.spo2 < self.CRITICAL_SPO2_THRESHOLD and features.bpm < self.CRITICAL_BPM_LOW:
            return RiskPredictionResult(
                risk_level=RiskLevel.CRITICAL,
                probability=1.0,
                explanation=(
                    f"Alerta Crítica Forzada: SpO2={features.spo2}% (< {self.CRITICAL_SPO2_THRESHOLD}%) "
                    f"y FC={features.bpm} BPM (< {self.CRITICAL_BPM_LOW} BPM). "
                    "Llamar a Emergencias (911) inmediatamente."
                ),
            )

        # Delegar al modelo de IA para clasificación probabilística
        return self._ai_port.predict_risk(features)
