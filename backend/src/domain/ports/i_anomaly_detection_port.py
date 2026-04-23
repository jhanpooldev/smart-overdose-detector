from typing import Protocol
from src.domain.valueObjects.biometric_features import BiometricFeatures
from src.domain.entities.risk_event import RiskPredictionResult


class IAnomalyDetectionPort(Protocol):
    """Puerto de salida — Motor de IA para detección de riesgo."""

    def predict_risk(self, features: BiometricFeatures) -> RiskPredictionResult: ...
