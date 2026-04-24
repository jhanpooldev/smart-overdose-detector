"""
user.py — Entidad de usuario y roles del sistema.
"""
from dataclasses import dataclass
from enum import Enum
from datetime import datetime
from typing import Optional


class Role(str, Enum):
    ADMIN = "ADMIN"
    DOCTOR = "DOCTOR"
    PATIENT = "PATIENT"
    FAMILY = "FAMILY"


@dataclass
class User:
    id: str
    email: str
    role: Role
    hashed_password: str
    created_at: datetime
    
    def is_admin(self) -> bool:
        return self.role == Role.ADMIN
        
    def is_doctor(self) -> bool:
        return self.role == Role.DOCTOR
        
    def is_patient(self) -> bool:
        return self.role == Role.PATIENT
        
    def is_family(self) -> bool:
        return self.role == Role.FAMILY
