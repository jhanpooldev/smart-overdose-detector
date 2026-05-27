"""
tests/test_telemetry_pmv2.py — Pruebas de integración para endpoints de telemetría PMV2 (/api/v2/telemetry).
"""
import pytest
from httpx import AsyncClient, ASGITransport
from datetime import datetime, timedelta
import uuid

from src.main import app
from src.domain.entities.user import User, Role
from src.domain.entities.iot_session import IoTSession, IoTStreamStatus
from src.infrastructure.configuration.container_v2 import (
    iot_session_repository,
    patient_repository_v2,
    biometric_signal_repository,
)


@pytest.mark.anyio
class TestTelemetryPMV2:

    async def _get_auth_token(self, client: AsyncClient, email: str, role: Role) -> str:
        pwd = "TestPassword123"
        # Llamadas síncronas para el repositorio común
        existing = patient_repository_v2.get_by_email(email)
        if not existing:
            from src.application.services.auth_service import AuthService
            auth = AuthService()
            user = User(
                id=str(uuid.uuid4()),
                email=email,
                role=role,
                hashed_password=auth.get_password_hash(pwd),
                created_at=datetime.utcnow()
            )
            patient_repository_v2.create_user(user)

        r = await client.post("/api/v1/auth/login", data={"username": email, "password": pwd})
        assert r.status_code == 200, f"Login falló: {r.text}"
        return r.json()["access_token"]

    async def test_create_session_only_for_patients(self):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            sup_token = await self._get_auth_token(client, "supervisor_tel@sod.com", Role.SUPERVISOR)
            r = await client.post(
                "/api/v2/telemetry/sessions",
                headers={"Authorization": f"Bearer {sup_token}"}
            )
            assert r.status_code == 403

            pac_token = await self._get_auth_token(client, "paciente_tel@sod.com", Role.PACIENTE)
            r = await client.post(
                "/api/v2/telemetry/sessions",
                headers={"Authorization": f"Bearer {pac_token}"}
            )
            assert r.status_code == 201
            data = r.json()
            assert "session_token" in data
            assert data["stream_status"] == "DISCONNECTED"
            assert data["is_active"] is False

    async def test_telemetry_stream_ingestion(self):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            pac_token = await self._get_auth_token(client, "pac_stream@sod.com", Role.PACIENTE)
            
            r = await client.post(
                "/api/v2/telemetry/sessions",
                headers={"Authorization": f"Bearer {pac_token}"}
            )
            assert r.status_code == 201
            session_token = r.json()["session_token"]

            payload = {
                "session_token": session_token,
                "device_id": str(uuid.uuid4()),
                "heart_rate": 75,
                "spo2": 98,
                "status_movement": "STILL"
            }
            r = await client.post(
                "/api/v2/telemetry/stream",
                json=payload,
                headers={"Authorization": f"Bearer {pac_token}"}
            )
            assert r.status_code == 200
            data = r.json()
            assert data["risk_level"] == "NORMAL"
            assert data["alert_triggered"] is False
            assert data["stream_status"] == "CONNECTED"

            pac_user = patient_repository_v2.get_by_email("pac_stream@sod.com")
            signals = await biometric_signal_repository.get_history(pac_user.id)
            assert len(signals) >= 1
            assert signals[-1].heart_rate == 75
            assert signals[-1].spo2 == 98

    async def test_telemetry_stream_critical_triggers_alert(self):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            pac_token = await self._get_auth_token(client, "pac_alert@sod.com", Role.PACIENTE)
            
            r = await client.post(
                "/api/v2/telemetry/sessions",
                headers={"Authorization": f"Bearer {pac_token}"}
            )
            session_token = r.json()["session_token"]

            payload = {
                "session_token": session_token,
                "device_id": str(uuid.uuid4()),
                "heart_rate": 130,
                "spo2": 85,
                "status_movement": "RUNNING"
            }
            r = await client.post(
                "/api/v2/telemetry/stream",
                json=payload,
                headers={"Authorization": f"Bearer {pac_token}"}
            )
            assert r.status_code == 200
            data = r.json()
            assert data["risk_level"] == "CRITICAL"

    async def test_get_session_status(self):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            pac_token = await self._get_auth_token(client, "pac_status@sod.com", Role.PACIENTE)
            
            r = await client.post(
                "/api/v2/telemetry/sessions",
                headers={"Authorization": f"Bearer {pac_token}"}
            )
            session_token = r.json()["session_token"]

            r = await client.get(
                f"/api/v2/telemetry/sessions/{session_token}",
                headers={"Authorization": f"Bearer {pac_token}"}
            )
            assert r.status_code == 200
            assert r.json()["session_token"] == session_token

    async def test_get_patient_online_status_for_supervisor(self):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            sup_token = await self._get_auth_token(client, "sup_status@sod.com", Role.SUPERVISOR)
            pac_token = await self._get_auth_token(client, "pac_online@sod.com", Role.PACIENTE)
            
            pac_user = patient_repository_v2.get_by_email("pac_online@sod.com")
            
            r = await client.get(
                f"/api/v2/telemetry/status/{pac_user.id}",
                headers={"Authorization": f"Bearer {sup_token}"}
            )
            assert r.status_code == 200
            assert r.json()["status_online"] is False

            r = await client.post(
                "/api/v2/telemetry/sessions",
                headers={"Authorization": f"Bearer {pac_token}"}
            )
            session_token = r.json()["session_token"]

            await client.post(
                "/api/v2/telemetry/stream",
                json={
                    "session_token": session_token,
                    "device_id": str(uuid.uuid4()),
                    "heart_rate": 80,
                    "spo2": 97
                },
                headers={"Authorization": f"Bearer {pac_token}"}
            )

            r = await client.get(
                f"/api/v2/telemetry/status/{pac_user.id}",
                headers={"Authorization": f"Bearer {sup_token}"}
            )
            assert r.status_code == 200
            assert r.json()["status_online"] is True
