"""
container_v2.py — Composition Root para PMV2.
Instancia y conecta los puertos con sus adaptadores concretos.
Extiende container.py existente sin romperlo.
"""
import logging

from src.infrastructure.configuration.settings import settings
from src.application.ports.output_ports import (
    IBiometricSignalRepository,
    IIoTSessionRepository,
    IPatientRepository,
)

logger = logging.getLogger(__name__)

# Anotaciones de tipo para Pyright/Pylance — la instancia real se asigna más abajo
iot_session_repository: IIoTSessionRepository
biometric_signal_repository: IBiometricSignalRepository
patient_repository_v2: IPatientRepository

# ── Repositorio de sesiones IoT ───────────────────────────────────────────────
if settings.STORAGE_BACKEND == "postgres":
    from src.infrastructure.adapters.output.persistence.postgres_repository import (
        PostgresIoTSessionRepository,
    )
    iot_session_repository = PostgresIoTSessionRepository(settings.DATABASE_URL)
else:
    from src.infrastructure.adapters.output.persistence.in_memory_iot_session_repository import (
        InMemoryIoTSessionRepository,
    )
    iot_session_repository = InMemoryIoTSessionRepository()


# ── Repositorio de señales biométricas (reutiliza el existente en PMV1) ────────
if settings.STORAGE_BACKEND == "postgres":
    from src.infrastructure.adapters.output.persistence.postgres_repository import (
        PostgresSignalRepository,
    )
    biometric_signal_repository = PostgresSignalRepository(settings.DATABASE_URL)
else:
    from src.infrastructure.configuration.container import signal_repository
    biometric_signal_repository = signal_repository  # type: ignore[assignment]

# ── Repositorio de pacientes V2 (reutiliza existente) ─────────────────────────
if settings.STORAGE_BACKEND == "postgres":
    from src.infrastructure.adapters.output.persistence.postgres_repository import (
        PostgresUserRepository,
    )
    patient_repository_v2 = PostgresUserRepository(settings.DATABASE_URL)
else:
    from src.infrastructure.configuration.container import user_repository
    patient_repository_v2 = user_repository  # type: ignore[assignment]


# ── Gateway de alertas (Mock/Stub en PMV2, reemplazar por Twilio en PMV3) ─────
from src.infrastructure.adapters.output.external_services.stub_alert_service import (
    StubAlertGatewayV2,
)

alert_gateway_v2 = StubAlertGatewayV2()

# ── Caso de uso principal ──────────────────────────────────────────────────────
from src.application.useCases.monitorizar_signos_use_case import MonitorizarSignosUseCase

monitorizar_signos_use_case = MonitorizarSignosUseCase(
    signal_repository=biometric_signal_repository,
    session_repository=iot_session_repository,
    patient_repository=patient_repository_v2,
    alert_gateway=alert_gateway_v2,
    notify_on_moderate=False,
)

logger.info("✅ Container PMV2 inicializado — backend: %s", settings.STORAGE_BACKEND)
