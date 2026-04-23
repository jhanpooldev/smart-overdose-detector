"""
container.py — Inyección de dependencias (Composition Root).

Este es el ÚNICO lugar donde los puertos se conectan con adaptadores concretos.
El dominio y la aplicación NUNCA importan desde aquí.
"""
from src.infrastructure.adapters.output.persistence.in_memory_signal_repository import InMemorySignalRepository
from src.infrastructure.adapters.output.external_services.stub_alert_service import StubAlertService
from src.infrastructure.adapters.output.external_services.rule_based_anomaly_detector import RuleBasedAnomalyDetector
from src.infrastructure.adapters.input.simulators.simulated_data_generator import SimulatedDataGenerator
from src.application.services.calculadora_riesgo_service import CalculadoraRiesgoService
from src.application.useCases.evaluar_riesgo_use_case import EvaluarRiesgoUseCase
from src.application.useCases.gestionar_alerta_use_case import GestionarAlertaUseCase


# --- Adaptadores de salida (driven) ---
signal_repository = InMemorySignalRepository()
alert_service = StubAlertService()
anomaly_detector = RuleBasedAnomalyDetector()

# --- Adaptador de entrada — Simulador ---
simulated_data_generator = SimulatedDataGenerator()

# --- Servicios de dominio ---
calculadora_riesgo = CalculadoraRiesgoService(anomaly_detection_port=anomaly_detector)

# --- Casos de uso ---
evaluar_riesgo_use_case = EvaluarRiesgoUseCase(
    calculadora=calculadora_riesgo,
    signal_repository=signal_repository,
)

gestionar_alerta_use_case = GestionarAlertaUseCase(
    alert_port=alert_service,
    contacts=[],  # Se poblará desde la BD en PMV2
    notify_on_moderate=False,
)
