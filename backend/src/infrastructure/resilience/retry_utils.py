"""
retry_utils.py — Decoradores de resiliencia para llamadas externas.

Uso:
    from src.infrastructure.resilience.retry_utils import retry_db, retry_external

    @retry_db
    def mi_query():
        ...

    @retry_external
    async def llamar_servicio_sms():
        ...
"""
import logging
from tenacity import (
    retry,
    stop_after_attempt,
    wait_exponential,
    retry_if_exception_type,
    before_sleep_log,
    RetryError,
)

logger = logging.getLogger(__name__)

# ── Retry para operaciones de base de datos ───────────────────────────────────
retry_db = retry(
    reraise=True,
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=0.5, min=0.5, max=5),
    retry=retry_if_exception_type(Exception),
    before_sleep=before_sleep_log(logger, logging.WARNING),
)

# ── Retry para servicios externos (SMS, notificaciones) ───────────────────────
retry_external = retry(
    reraise=True,
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=1, max=10),
    retry=retry_if_exception_type(Exception),
    before_sleep=before_sleep_log(logger, logging.WARNING),
)

__all__ = ["retry_db", "retry_external", "RetryError"]
