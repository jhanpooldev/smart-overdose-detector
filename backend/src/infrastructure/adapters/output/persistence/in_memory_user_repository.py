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
        # Sin datos de prueba — los usuarios se crean desde la app
        self._users: dict[str, User] = {}
        
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

    def get_all(self) -> list[User]:
        return list(self._users.values())
