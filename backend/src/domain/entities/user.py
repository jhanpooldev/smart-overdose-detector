"""
user.py — Entidad de usuario y roles del sistema.
"""
from dataclasses import dataclass
from enum import Enum
from datetime import datetime
from typing import Optional


class Role(str, Enum):
    SUPERVISOR = "SUPERVISOR"
    PACIENTE = "PACIENTE"

@dataclass
class User:
    id: str
    email: str
    role: Role
    hashed_password: str
    created_at: datetime
    supervisor_email: Optional[str] = None
    edad: Optional[int] = None
    peso: Optional[float] = None
    altura: Optional[float] = None
    sexo: Optional[str] = None
    telefono: Optional[str] = None
    
    def is_supervisor(self) -> bool:
        return self.role == Role.SUPERVISOR
        
    def is_paciente(self) -> bool:
        return self.role == Role.PACIENTE
