"""
RuleBasedAnomalyDetector — Motor de IA basado en reglas clínicas para PMV1.
En PMV2 será reemplazado por TFLiteModelAdapter con modelo LSTM.
"""
from src.domain.valueObjects.biometric_features import BiometricFeatures
from src.domain.entities.risk_event import RiskLevel, RiskPredictionResult
from src.domain.ports.i_anomaly_detection_port import IAnomalyDetectionPort


class RuleBasedAnomalyDetector(IAnomalyDetectionPort):
    """
    Clasificador deterministico basado en umbrales clínicos.
    Sustituible por TFLiteModelAdapter en PMV2 sin modificar el dominio.
    """

    def predict_risk(self, features: BiometricFeatures) -> RiskPredictionResult:
        spo2, bpm, activity = features.spo2, features.bpm, features.activity

        # --- Escenario CRÍTICO ---
        if spo2 < 82 or bpm < 50:
            prob = self._critical_probability(spo2, bpm)
            return RiskPredictionResult(
                risk_level=RiskLevel.CRITICAL,
                probability=prob,
                explanation=(
                    f"SpO2 crítico ({spo2}%) y/o bradicardia severa ({bpm} BPM). "
                    "Riesgo de sobredosis confirmado."
                ),
            )

        # --- Escenario MODERADO ---
        if spo2 < 90 or bpm < 60 or (activity == 0 and spo2 < 93):
            return RiskPredictionResult(
                risk_level=RiskLevel.MODERATE,
                probability=0.65,
                explanation=(
                    f"Hipoxemia leve ({spo2}%) y/o bradicardia ({bpm} BPM). "
                    "Monitoreo intensificado recomendado."
                ),
            )

        # --- Escenario NORMAL ---
        return RiskPredictionResult(
            risk_level=RiskLevel.NORMAL,
            probability=0.05,
            explanation="Signos vitales dentro de parámetros normales.",
        )

    def _critical_probability(self, spo2: float, bpm: int) -> float:
        """Calcula probabilidad lineal de criticidad según desviación de umbrales."""
        spo2_score = max(0.0, (82.0 - spo2) / 12.0)  # 82 → 0, 70 → 1
        bpm_score = max(0.0, (50.0 - bpm) / 20.0)    # 50 → 0, 30 → 1
        return min(1.0, 0.7 + 0.15 * spo2_score + 0.15 * bpm_score)
