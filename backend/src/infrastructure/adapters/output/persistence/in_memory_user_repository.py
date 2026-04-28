"""
in_memory_user_repository.py — Repositorio en memoria para desarrollo local sin postgres.
"""
from typing import Optional
from src.domain.entities.user import User, Role
from src.domain.ports.i_user_repository import IUserRepository
from datetime import datetime
import uuid

class InMemoryUserRepository(IUserRepository):
    def __init__(self):
        # Hash fijo para "123456" generado por sha256
        hash_123456 = "8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92"
        self._users = {
            "supervisor@sod.com": User(
                id="00000000-0000-0000-0000-100000000001",
                email="supervisor@sod.com",
                role=Role.SUPERVISOR,
                hashed_password=hash_123456,
                created_at=datetime.now()
            ),
            "paciente@sod.com": User(
                id="00000000-0000-0000-0000-100000000002",
                email="paciente@sod.com",
                role=Role.PACIENTE,
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

    def create_user(self, user: User) -> User:
        if not user.id:
            user.id = str(uuid.uuid4())
        self._users[user.email] = user
        return user
