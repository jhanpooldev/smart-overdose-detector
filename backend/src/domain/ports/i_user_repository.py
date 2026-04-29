"""
i_user_repository.py — Puerto para persistencia de usuarios.
"""
from abc import ABC, abstractmethod
from typing import Optional
from src.domain.entities.user import User


class IUserRepository(ABC):
    @abstractmethod
    def get_by_email(self, email: str) -> Optional[User]:
        pass
        
    @abstractmethod
    def get_by_id(self, user_id: str) -> Optional[User]:
        pass

    @abstractmethod
    def get_all(self) -> list[User]:
        pass
