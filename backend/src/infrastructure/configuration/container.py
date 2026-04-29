"""
container.py — Inyección de dependencias (Composition Root).

Selecciona automáticamente el repositorio según STORAGE_BACKEND en el .env:
  - STORAGE_BACKEND=memory   → InMemorySignalRepository (default, sin BD)
  - STORAGE_BACKEND=postgres → TimescaleSignalRepository (PostgreSQL real)
"""
import logging
from src.infrastructure.configuration.settings import settings

# --- Adaptadores de salida (driven) ---

# 1. Selección automática del repositorio según configuración
if settings.STORAGE_BACKEND == "postgres":
    if not settings.DATABASE_URL:
        raise RuntimeError(
            "STORAGE_BACKEND=postgres pero DATABASE_URL no está definida en .env"
        )
    from src.infrastructure.adapters.output.persistence.timescale_signal_repository import (
        TimescaleSignalRepository,
    )
    signal_repository = TimescaleSignalRepository(settings.DATABASE_URL)
    logging.getLogger(__name__).info("🗄️  Repositorio: PostgreSQL — %s", settings.DATABASE_URL.split("@")[-1])
else:
    from src.infrastructure.adapters.output.persistence.in_memory_signal_repository import (
        InMemorySignalRepository,
    )
    from src.infrastructure.adapters.output.persistence.in_memory_user_repository import (
        InMemoryUserRepository,
    )
    from src.infrastructure.adapters.output.persistence.in_memory_contact_repository import (
        InMemoryContactRepository,
    )
    from src.infrastructure.adapters.output.persistence.in_memory_settings_repository import (
        InMemorySettingsRepository,
    )
    from src.infrastructure.adapters.output.persistence.in_memory_risk_repository import (
        InMemoryRiskRepository,
    )
    signal_repository = InMemorySignalRepository()
    user_repository = InMemoryUserRepository()
    contact_repository = InMemoryContactRepository()
    settings_repository = InMemorySettingsRepository()
    risk_repository = InMemoryRiskRepository()
    logging.getLogger(__name__).info("🗄️  Repositorio: Memoria RAM (sin BD persistente)")

# 2. Resto de adaptadores
from src.infrastructure.adapters.output.external_services.stub_alert_service import StubAlertService
from src.infrastructure.adapters.output.external_services.rule_based_anomaly_detector import RuleBasedAnomalyDetector
from src.infrastructure.adapters.input.simulators.simulated_data_generator import SimulatedDataGenerator
from src.application.services.calculadora_riesgo_service import CalculadoraRiesgoService
from src.application.useCases.evaluar_riesgo_use_case import EvaluarRiesgoUseCase
from src.application.useCases.gestionar_alerta_use_case import GestionarAlertaUseCase
from src.application.services.auth_service import AuthService

alert_service = StubAlertService()
anomaly_detector = RuleBasedAnomalyDetector()
simulated_data_generator = SimulatedDataGenerator()
auth_service = AuthService()

# --- Servicios de dominio ---
calculadora_riesgo = CalculadoraRiesgoService(anomaly_detection_port=anomaly_detector)

# --- Casos de uso ---
evaluar_riesgo_use_case = EvaluarRiesgoUseCase(
    calculadora=calculadora_riesgo,
    signal_repository=signal_repository,
    risk_repository=risk_repository,
)

gestionar_alerta_use_case = GestionarAlertaUseCase(
    alert_port=alert_service,
    contacts=[],
    notify_on_moderate=False,
)
