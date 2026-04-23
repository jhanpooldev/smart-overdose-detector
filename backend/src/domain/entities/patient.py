from dataclasses import dataclass, field
from typing import Optional
from datetime import datetime


@dataclass
class Patient:
    """Entidad de dominio — Paciente registrado en el sistema."""
    dni: str
    nombre: str
    apellido: str
    edad: int
    telefono: str
    patient_id: Optional[str] = None
    fecha_registro: Optional[datetime] = None

    def __post_init__(self):
        if self.edad < 0 or self.edad > 120:
            raise ValueError("Edad del paciente fuera de rango clínico válido.")
        if not self.dni:
            raise ValueError("El DNI del paciente es obligatorio.")
