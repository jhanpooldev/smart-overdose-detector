"""
emergency_contact_v2.py — Entidad de dominio para contactos de emergencia (PMV2).
Soporta relación N:M con jerarquía de prioridad (RF03/11/12).
"""
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional


@dataclass
class ContactBase:
    """
    Entidad reutilizable — datos del contacto en sí.
    Independiente del paciente (permite contactos compartidos entre pacientes).
    """
    contact_id: str
    nombre:     str
    telefono:   str
    email:      Optional[str] = None
    created_at: Optional[datetime] = None

    def __post_init__(self) -> None:
        if not self.nombre.strip():
            raise ValueError("El nombre del contacto no puede estar vacío")
        if not self.telefono.strip():
            raise ValueError("El teléfono del contacto es obligatorio")


@dataclass
class PatientContact:
    """
    Entidad relacional N:M — Relación entre Paciente y Contacto.

    Campos relacionales RF03:
        parentesco:              Tipo de relación (Familiar, Médico, Amigo, etc.)
        prioridad_notificacion:  Jerarquía de alerta: 1 (primero) → 3 (último)
        es_principal:            Si es el contacto de emergencia primario
    """
    id:                      str
    patient_id:              str
    contact_id:              str
    parentesco:              str     = "Familiar"
    prioridad_notificacion:  int     = 1           # 1, 2 o 3
    es_principal:            bool    = False
    created_at:              Optional[datetime] = None

    def __post_init__(self) -> None:
        if self.prioridad_notificacion not in (1, 2, 3):
            raise ValueError(
                f"prioridad_notificacion debe ser 1, 2 o 3. Recibido: {self.prioridad_notificacion}"
            )

    def is_high_priority(self) -> bool:
        """Retorna True si este contacto debe ser notificado primero."""
        return self.prioridad_notificacion == 1 or self.es_principal


@dataclass
class EmergencyContact:
    """
    Vista compuesta — ContactBase + datos relacionales PatientContact.
    Usada en la capa de aplicación para simplificar el acceso.
    """
    contact_id:             str
    patient_id:             str
    nombre:                 str
    telefono:               str
    relacion:               str   = "Familiar"   # alias de parentesco
    es_principal:           bool  = False
    prioridad_notificacion: int   = 1
    email:                  Optional[str] = None
    created_at:             Optional[datetime] = None
