"""
tests/test_evaluar_riesgo_use_case.py — Pruebas unitarias del EvaluarRiesgoUseCase.

Usa mocks del IAnomalyDetectionPort para garantizar aislamiento del dominio.
"""
import pytest
from datetime import datetime
from unittest.mock import MagicMock

from src.domain.entities.biometric_reading import BiometricReading
from src.domain.entities.risk_event import RiskLevel, RiskPredictionResult
from src.domain.valueObjects.biometric_features import BiometricFeatures
from src.application.services.calculadora_riesgo_service import CalculadoraRiesgoService
from src.application.useCases.evaluar_riesgo_use_case import EvaluarRiesgoUseCase


def make_reading(spo2: float, bpm: int, activity: int) -> BiometricReading:
    return BiometricReading(spo2=spo2, bpm=bpm, activity=activity, timestamp=datetime.now())


@pytest.fixture
def mock_ai_port():
    return MagicMock()


@pytest.fixture
def mock_repository():
    repo = MagicMock()
    repo.get_history.return_value = []
    return repo


@pytest.fixture
def use_case(mock_ai_port, mock_repository):
    calculadora = CalculadoraRiesgoService(anomaly_detection_port=mock_ai_port)
    return EvaluarRiesgoUseCase(calculadora=calculadora, signal_repository=mock_repository)


class TestEvaluarRiesgoUseCase:

    def test_critical_reading_without_ai(self, use_case, mock_repository):
        """SpO2 < 85 y BPM < 50 → Regla clínica forzada → CRÍTICO sin llamar a la IA."""
        reading = make_reading(spo2=78.0, bpm=45, activity=0)
        event = use_case.execute("PAT-001", reading)
        assert event.risk_level == RiskLevel.CRITICAL
        assert event.probability == 1.0
        mock_repository.save_reading.assert_called_once()

    def test_normal_reading_delegates_to_ai(self, use_case, mock_ai_port):
        """Lectura normal → delegada a la IA."""
        mock_ai_port.predict_risk.return_value = RiskPredictionResult(
            risk_level=RiskLevel.NORMAL, probability=0.05
        )
        reading = make_reading(spo2=97.5, bpm=75, activity=1)
        event = use_case.execute("PAT-001", reading)
        assert event.risk_level == RiskLevel.NORMAL
        mock_ai_port.predict_risk.assert_called_once()

    def test_moderate_reading_delegates_to_ai(self, use_case, mock_ai_port):
        """Lectura moderada → delegada a la IA."""
        mock_ai_port.predict_risk.return_value = RiskPredictionResult(
            risk_level=RiskLevel.MODERATE, probability=0.65
        )
        reading = make_reading(spo2=91.0, bpm=55, activity=0)
        event = use_case.execute("PAT-001", reading)
        assert event.risk_level == RiskLevel.MODERATE

    def test_critical_vector_exact_values(self, use_case):
        """Vector exacto [SpO2=78, FC=45, Actividad=0] → Estado_Riesgo = CRITICAL (PMV1)."""
        reading = make_reading(spo2=78.0, bpm=45, activity=0)
        event = use_case.execute("PAT-PoC", reading)
        # Verificar los valores del evento de riesgo
        assert event.spo2_at_event == 78.0
        assert event.bpm_at_event == 45
        assert event.activity_at_event == 0
        assert event.risk_level == RiskLevel.CRITICAL
        assert event.is_critical() is True
        assert event.requires_emergency_call() is True

    def test_event_has_patient_id(self, use_case, mock_ai_port):
        """El evento debe conservar el patient_id del call."""
        mock_ai_port.predict_risk.return_value = RiskPredictionResult(
            risk_level=RiskLevel.NORMAL, probability=0.05
        )
        reading = make_reading(spo2=96.0, bpm=72, activity=1)
        event = use_case.execute("DNI-9999", reading)
        assert event.patient_id == "DNI-9999"
