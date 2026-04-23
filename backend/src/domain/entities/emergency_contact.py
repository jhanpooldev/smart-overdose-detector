from dataclasses import dataclass


@dataclass
class EmergencyContact:
    """Entidad de dominio — Contacto de emergencia del paciente."""
    contact_id: str
    patient_id: str
    nombre: str
    telefono: str
    relacion: str  # e.g. "Familiar", "Médico", "Tutor"
    es_principal: bool = False
