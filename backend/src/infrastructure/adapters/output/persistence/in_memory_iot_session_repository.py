"""
in_memory_iot_session_repository.py — Adaptador en memoria para sesiones IoT (PMV2).
Implementa IIoTSessionRepository usando un dict concurrente.
Reemplazar por PostgresIoTSessionRepository cuando se active STORAGE_BACKEND=postgres.
"""
import asyncio
import logging
from datetime import datetime
from typing import Dict, Optional

from src.application.ports.output_ports import IIoTSessionRepository
from src.domain.entities.iot_session import IoTSession, IoTStreamStatus

logger = logging.getLogger(__name__)


class InMemoryIoTSessionRepository(IIoTSessionRepository):
    """
    Repositorio en memoria thread-safe para sesiones IoT.
    Usa asyncio.Lock para operaciones concurrentes en el event loop de FastAPI.
    """

    def __init__(self) -> None:
        self._sessions: Dict[str, IoTSession] = {}   # token → IoTSession
        self._patient_index: Dict[str, str] = {}     # patient_id → token activo
        self._lock = asyncio.Lock()

    async def create_session(self, session: IoTSession) -> IoTSession:
        async with self._lock:
            # Limpiar sesión anterior del paciente si existe
            old_token = self._patient_index.get(session.patient_id)
            if old_token and old_token in self._sessions:
                del self._sessions[old_token]

            self._sessions[session.session_token] = session
            self._patient_index[session.patient_id] = session.session_token
            logger.info("🔗 Nueva sesión IoT: token=%s patient=%s", session.session_token, session.patient_id)
        return session

    async def get_by_token(self, token: str) -> Optional[IoTSession]:
        return self._sessions.get(token.upper())

    async def get_active_session(self, patient_id: str) -> Optional[IoTSession]:
        token = self._patient_index.get(patient_id)
        if not token:
            return None
        return self._sessions.get(token)

    async def update_status(
        self, token: str, status: IoTStreamStatus, heartbeat: bool = False
    ) -> None:
        async with self._lock:
            session = self._sessions.get(token.upper())
            if session is None:
                return
            session.stream_status = status
            if heartbeat:
                session.last_heartbeat = datetime.utcnow()

    async def is_patient_online(self, patient_id: str) -> bool:
        session = await self.get_active_session(patient_id)
        if session is None:
            return False
        return session.is_active()
