"""
in_memory_user_repository.py — Repositorio en memoria para desarrollo local sin postgres.
"""
from typing import Optional
from src.domain.entities.user import User, Role
from src.domain.ports.i_user_repository import IUserRepository
from datetime import datetime

class InMemoryUserRepository(IUserRepository):
    def __init__(self):
        # Hash fijo para "123456" generado por sha256
        hash_123456 = "8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92"
        self._users = {
            "doctor@sod.com": User(
                id="00000000-0000-0000-0000-100000000001",
                email="doctor@sod.com",
                role=Role.DOCTOR,
                hashed_password=hash_123456,
                created_at=datetime.now()
            ),
            "paciente@sod.com": User(
                id="00000000-0000-0000-0000-100000000002",
                email="paciente@sod.com",
                role=Role.PATIENT,
                hashed_password=hash_123456,
                created_at=datetime.now()
            ),
            "familiar@sod.com": User(
                id="00000000-0000-0000-0000-100000000003",
                email="familiar@sod.com",
                role=Role.FAMILY,
                hashed_password=hash_123456,
                created_at=datetime.now()
            )
        }
        
    def get_by_email(self, email: str) -> Optional[User]:
        return self._users.get(email)

    def get_by_id(self, user_id: str) -> Optional[User]:
        for u in self._users.values():
            if u.id == user_id:
                return u
        return None
