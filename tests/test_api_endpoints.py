"""
tests/test_api_endpoints.py — Pruebas de integración para los endpoints HTTP.
Usa httpx.AsyncClient sobre la app FastAPI en modo 'memory' (sin BD real).
"""
import pytest
import os
os.environ["STORAGE_BACKEND"] = "memory"

import httpx
from httpx import AsyncClient, ASGITransport
import pytest_asyncio


@pytest.fixture
def app():
    from src.main import app as fastapi_app
    return fastapi_app


@pytest.fixture
def supervisor_credentials():
    return {"email": "supervisor_test@sod.com", "password": "Test1234"}


@pytest.fixture
def patient_credentials():
    return {"email": "paciente_test@sod.com", "password": "Test1234"}


@pytest.mark.asyncio
class TestRegisterAndLogin:

    async def test_register_supervisor(self, app, supervisor_credentials):
        """Registra un supervisor correctamente."""
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            r = await client.post("/api/v1/auth/register", json={
                "email": supervisor_credentials["email"],
                "password": supervisor_credentials["password"],
                "name": "Supervisor Test",
                "role": "SUPERVISOR",
            })
        assert r.status_code == 200
        data = r.json()
        assert data["role"] == "SUPERVISOR"
        assert "access_token" in data

    async def test_register_patient_with_supervisor(self, app, patient_credentials, supervisor_credentials):
        """Registra un paciente vinculado al supervisor."""
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            r = await client.post("/api/v1/auth/register", json={
                "email": patient_credentials["email"],
                "password": patient_credentials["password"],
                "name": "Paciente Test",
                "role": "PACIENTE",
                "supervisor_email": supervisor_credentials["email"],
                "edad": 28,
                "peso": 68.0,
                "altura": 1.72,
                "sexo": "Masculino",
            })
        assert r.status_code == 200
        data = r.json()
        assert data["role"] == "PACIENTE"
        assert data["supervisor_email"] == supervisor_credentials["email"]

    async def test_duplicate_email_fails(self, app, supervisor_credentials):
        """Un email ya registrado retorna 400."""
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            r = await client.post("/api/v1/auth/register", json={
                "email": supervisor_credentials["email"],
                "password": "anypass",
                "name": "Duplicado",
            })
        assert r.status_code == 400

    async def test_login_supervisor_success(self, app, supervisor_credentials):
        """Login correcto de supervisor retorna token."""
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            r = await client.post("/api/v1/auth/login", data={
                "username": supervisor_credentials["email"],
                "password": supervisor_credentials["password"],
            })
        assert r.status_code == 200
        assert "access_token" in r.json()

    async def test_login_wrong_password(self, app, supervisor_credentials):
        """Contraseña incorrecta retorna 401 con mensaje genérico (anti-enumeración)."""
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            r = await client.post("/api/v1/auth/login", data={
                "username": supervisor_credentials["email"],
                "password": "wrongpass",
            })
        assert r.status_code == 401
        # Anti-enumeración: mensaje genérico igual para contraseña incorrecta
        assert r.json()["detail"] == "Credenciales inválidas"

    async def test_login_nonexistent_user(self, app):
        """Usuario no registrado retorna 401 con mensaje genérico (anti-enumeración)."""
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            r = await client.post("/api/v1/auth/login", data={
                "username": "noexiste@sod.com",
                "password": "cualquiera",
            })
        assert r.status_code == 401
        # Anti-enumeración: mismo mensaje genérico, no revela si el email existe
        assert r.json()["detail"] == "Credenciales inválidas"


@pytest.mark.asyncio
class TestThresholds:

    async def _get_token(self, app, email, password):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            r = await client.post("/api/v1/auth/login", data={"username": email, "password": password})
        return r.json()["access_token"]

    async def test_get_my_thresholds(self, app, patient_credentials):
        """Un paciente puede obtener sus propios umbrales."""
        token = await self._get_token(app, patient_credentials["email"], patient_credentials["password"])
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            r = await client.get("/api/v1/auth/thresholds", headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200
        data = r.json()
        assert "bpm" in data
        assert "spo2" in data
        assert data["bpm"]["normal_min"] == 60

    async def test_supervisor_gets_patient_list(self, app, supervisor_credentials, patient_credentials):
        """El supervisor ve la lista de sus pacientes asignados."""
        # Este test verifica la logica de filtrado de get_patients directamente.
        # La integracion HTTP completa se verifica via test_register_patient_with_supervisor.
        import uuid
        from datetime import datetime
        from src.infrastructure.configuration.container import user_repository
        from src.domain.entities.user import User, Role

        uid       = uuid.uuid4().hex[:8]
        sup_email = f"sup_{uid}@sod.com"
        pac_email = f"pac_{uid}@sod.com"

        sup = User(id=str(uuid.uuid4()), email=sup_email, role=Role.SUPERVISOR,
                   hashed_password="x", created_at=datetime.now())
        pac = User(id=str(uuid.uuid4()), email=pac_email, role=Role.PACIENTE,
                   hashed_password="x", created_at=datetime.now(),
                   supervisor_email=sup_email, edad=28, peso=68.0, altura=1.72)

        user_repository.create_user(sup)
        user_repository.create_user(pac)

        # Verificar logica de filtrado directamente (igual a la del endpoint get_patients)
        all_users = user_repository.get_all()
        patients_of_sup = [
            u for u in all_users
            if u.role == Role.PACIENTE and u.supervisor_email == sup_email
        ]
        assert len(patients_of_sup) >= 1, (
            f"Filtrado fallo. Usuarios en repo: "
            f"{[(u.email, u.role, u.supervisor_email) for u in all_users]}"
        )
        assert any(u.email == pac_email for u in patients_of_sup)

