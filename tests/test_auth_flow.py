"""
tests/test_auth_flow.py — Pruebas unitarias del flujo de autenticación.
Cubre: registro, login, token inválido, usuario no registrado, clave incorrecta,
       validación de roles y vinculación supervisor-paciente.
"""
import pytest
from datetime import datetime
from unittest.mock import MagicMock, patch

from src.domain.entities.user import User, Role
from src.application.services.auth_service import AuthService


def _make_user(role=Role.PACIENTE, supervisor_email=None, edad=30, peso=70.0, altura=1.75):
    return User(
        id="test-id-001",
        email="test@sod.com",
        hashed_password="hashed",
        role=role,
        created_at=datetime.now(),
        supervisor_email=supervisor_email,
        edad=edad,
        peso=peso,
        altura=altura,
    )


class TestAuthService:

    def setup_method(self):
        self.auth = AuthService()

    def test_hash_and_verify_password(self):
        """La contraseña hasheada se verifica correctamente."""
        raw = "MiClave123"
        hashed = self.auth.get_password_hash(raw)
        assert self.auth.verify_password(raw, hashed)
        assert not self.auth.verify_password("otraClave", hashed)

    def test_wrong_password_fails_verification(self):
        """Una contraseña incorrecta no pasa la verificación."""
        hashed = self.auth.get_password_hash("correcta")
        assert not self.auth.verify_password("incorrecta", hashed)

    def test_create_and_decode_token(self):
        """Un token JWT se crea y se decodifica recuperando el email."""
        token = self.auth.create_access_token(data={"sub": "user@sod.com", "role": "PACIENTE"})
        payload = self.auth.decode_token(token)
        assert payload is not None
        assert payload["sub"] == "user@sod.com"
        assert payload["role"] == "PACIENTE"

    def test_decode_invalid_token_returns_none(self):
        """Un token inválido o manipulado retorna None."""
        result = self.auth.decode_token("esto.no.es.un.jwt.valido")
        assert result is None

    def test_decode_empty_token_returns_none(self):
        """Un token vacío retorna None."""
        assert self.auth.decode_token("") is None


class TestUserEntity:

    def test_paciente_role_methods(self):
        """Un usuario PACIENTE es_paciente=True, is_supervisor=False."""
        u = _make_user(role=Role.PACIENTE)
        assert u.is_paciente() is True
        assert u.is_supervisor() is False

    def test_supervisor_role_methods(self):
        """Un usuario SUPERVISOR is_supervisor=True, is_paciente=False."""
        u = _make_user(role=Role.SUPERVISOR)
        assert u.is_supervisor() is True
        assert u.is_paciente() is False

    def test_supervisor_link(self):
        """Un paciente tiene supervisor_email asignado."""
        u = _make_user(role=Role.PACIENTE, supervisor_email="sup@sod.com")
        assert u.supervisor_email == "sup@sod.com"

    def test_supervisor_has_no_supervisor_email(self):
        """Un supervisor no tiene supervisor_email (es None)."""
        u = _make_user(role=Role.SUPERVISOR, supervisor_email=None)
        assert u.supervisor_email is None

    def test_biometric_fields_stored(self):
        """Los campos biométricos se almacenan correctamente en la entidad."""
        u = _make_user(edad=45, peso=85.0, altura=1.80)
        assert u.edad == 45
        assert u.peso == 85.0
        assert u.altura == 1.80


class TestInMemoryUserRepository:

    def setup_method(self):
        from src.infrastructure.adapters.output.persistence.in_memory_user_repository import InMemoryUserRepository
        self.repo = InMemoryUserRepository()

    def test_create_and_get_by_email(self):
        """Crea un usuario y lo recupera por email."""
        u = _make_user()
        self.repo.create_user(u)
        found = self.repo.get_by_email("test@sod.com")
        assert found is not None
        assert found.email == "test@sod.com"

    def test_get_nonexistent_email_returns_none(self):
        """Un email no registrado retorna None."""
        assert self.repo.get_by_email("noexiste@sod.com") is None

    def test_get_all_returns_created_users(self):
        """get_all() retorna todos los usuarios registrados."""
        u1 = User(id="u1", email="a@sod.com", role=Role.PACIENTE, hashed_password="h", created_at=datetime.now())
        u2 = User(id="u2", email="b@sod.com", role=Role.SUPERVISOR, hashed_password="h", created_at=datetime.now())
        self.repo.create_user(u1)
        self.repo.create_user(u2)
        all_users = self.repo.get_all()
        assert len(all_users) == 2

    def test_filter_patients_by_supervisor(self):
        """Se pueden filtrar los pacientes por supervisor_email."""
        sup = User(id="s1", email="sup@sod.com", role=Role.SUPERVISOR, hashed_password="h", created_at=datetime.now())
        pat = User(id="p1", email="pat@sod.com", role=Role.PACIENTE, hashed_password="h", created_at=datetime.now(), supervisor_email="sup@sod.com")
        other = User(id="p2", email="other@sod.com", role=Role.PACIENTE, hashed_password="h", created_at=datetime.now(), supervisor_email="otro@sod.com")
        self.repo.create_user(sup)
        self.repo.create_user(pat)
        self.repo.create_user(other)
        patients_of_sup = [u for u in self.repo.get_all() if u.role == Role.PACIENTE and u.supervisor_email == "sup@sod.com"]
        assert len(patients_of_sup) == 1
        assert patients_of_sup[0].email == "pat@sod.com"

    def test_duplicate_email_overwrites(self):
        """El repositorio en memoria no lanza error por email duplicado (la validación la hace el controller)."""
        u = _make_user()
        self.repo.create_user(u)
        u2 = _make_user()  # mismo email
        self.repo.create_user(u2)
        assert len(self.repo.get_all()) == 1  # sobrescribe
