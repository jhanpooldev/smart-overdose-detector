"""
auth_service.py — Lógica de generación y validación de tokens JWT.

Cambios de seguridad aplicados:
  - SECRET_KEY cargada desde .env (nunca hardcodeada).
  - Hashing de contraseñas con bcrypt + salt (reemplaza SHA-256 sin salt).
  - JWT con vigencia configurable (por defecto 24 horas, no 7 días).
"""
from datetime import datetime, timedelta, timezone

import jwt
from passlib.context import CryptContext

from src.infrastructure.configuration.settings import settings

ALGORITHM = "HS256"

# Contexto bcrypt: incluye salt automático, depreca esquemas antiguos
_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


class AuthService:
    # ── Contraseñas ───────────────────────────────────────────────────────────

    def verify_password(self, plain_password: str, hashed_password: str) -> bool:
        """Verifica la contraseña usando bcrypt (timing-safe)."""
        try:
            return _pwd_context.verify(plain_password, hashed_password)
        except Exception:
            return False

    def get_password_hash(self, password: str) -> str:
        """Genera hash bcrypt con salt aleatorio."""
        return _pwd_context.hash(password)

    def needs_rehash(self, hashed_password: str) -> bool:
        """True si el hash fue creado con un esquema obsoleto (migración gradual)."""
        return _pwd_context.needs_update(hashed_password)

    # ── JWT ───────────────────────────────────────────────────────────────────

    def create_access_token(
        self, data: dict, expires_delta: timedelta | None = None
    ) -> str:
        """
        Genera un JWT firmado con la SECRET_KEY del entorno.
        Vigencia por defecto: ACCESS_TOKEN_EXPIRE_MINUTES (24 h).
        """
        to_encode = data.copy()
        expire = datetime.now(timezone.utc) + (
            expires_delta
            or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
        )
        to_encode.update({"exp": expire, "iat": datetime.now(timezone.utc)})
        return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=ALGORITHM)

    def decode_token(self, token: str) -> dict | None:
        """
        Decodifica y valida el JWT.
        Retorna el payload o None si el token es inválido/expirado.
        """
        try:
            return jwt.decode(
                token, settings.SECRET_KEY, algorithms=[ALGORITHM]
            )
        except jwt.ExpiredSignatureError:
            return None
        except jwt.InvalidTokenError:
            return None
