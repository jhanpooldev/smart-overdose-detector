"""
EvaluarRiesgoUseCase — Caso de uso de entrada: procesar lectura biométrica y clasificarla.
"""
import uuid
from datetime import datetime
from src.domain.entities.biometric_reading import BiometricReading
from src.domain.entities.risk_event import RiskEvent, RiskLevel, RiskPredictionResult
from src.domain.valueObjects.biometric_features import BiometricFeatures
from src.application.services.calculadora_riesgo_service import CalculadoraRiesgoService
from src.domain.ports.i_signal_repository import ISignalRepository
from src.domain.ports.i_risk_repository import IRiskRepository


class EvaluarRiesgoUseCase:
    """
    Caso de uso principal del PMV1.
    Recibe una lectura del simulador → guarda → clasifica → retorna el evento de riesgo.
    """

    def __init__(
        self,
        calculadora: CalculadoraRiesgoService,
        signal_repository: ISignalRepository,
        risk_repository: IRiskRepository,
    ):
        self._calculadora = calculadora
        self._signal_repo = signal_repository
        self._risk_repo = risk_repository

    def execute(self, patient_id: str, reading: BiometricReading) -> RiskEvent:
        # 1. Guardar la lectura en el repositorio
        self._signal_repo.save_reading(reading)

        # 2. Construir el vector de features (value object inmutable)
        features = BiometricFeatures(
            spo2=reading.spo2,
            bpm=reading.bpm,
            activity=reading.activity,
        )

        # 3. Delegar al servicio de dominio para evaluación de riesgo
        prediction: RiskPredictionResult = self._calculadora.evaluar(features)

        # 4. Construir el evento de riesgo del dominio
        event = RiskEvent(
            event_id=str(uuid.uuid4()),
            patient_id=patient_id,
            risk_level=prediction.risk_level,
            probability=prediction.probability,
            spo2_at_event=reading.spo2,
            bpm_at_event=reading.bpm,
            activity_at_event=reading.activity,
            detected_at=datetime.now(),
            alert_sent=False,
        )

        # 5. Guardar evento si es significativo (MODERATE o CRITICAL)
        if event.risk_level != RiskLevel.NORMAL:
            self._risk_repo.save(event)

        return event
