"""
in_memory_contact_repository.py — Repositorio en memoria para contactos de emergencia.
"""
from typing import List, Optional
from src.domain.entities.emergency_contact import EmergencyContact
import uuid

class InMemoryContactRepository:
    def __init__(self):
        self._contacts: List[EmergencyContact] = []
        
    def get_by_patient_id(self, patient_id: str) -> List[EmergencyContact]:
        return [c for c in self._contacts if c.patient_id == patient_id]

    def create(self, contact: EmergencyContact) -> EmergencyContact:
        if not contact.contact_id:
            contact.contact_id = str(uuid.uuid4())
        self._contacts.append(contact)
        return contact
