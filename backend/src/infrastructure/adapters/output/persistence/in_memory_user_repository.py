"""
in_memory_user_repository.py — Repositorio en memoria compatible con PMV1 (IUserRepository) y PMV2 (IPatientRepository).
"""
from typing import Optional, List
from src.domain.entities.user import User, Role
from src.domain.ports.i_user_repository import IUserRepository
from src.application.ports.output_ports import IPatientRepository
from src.domain.entities.emergency_contact import EmergencyContact
from datetime import datetime
import uuid

class InMemoryUserRepository(IUserRepository, IPatientRepository):
    def __init__(self):
        self._users: dict[str, User] = {}
        # Guardar asociaciones de contactos: patient_id -> lista de (contact, parentesco, prioridad)
        self._patient_contacts: dict[str, List[dict]] = {}

    # --- Métodos comunes y PMV1 ---
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

    # --- Métodos de IPatientRepository (PMV2) ---
    async def create(self, user: User) -> User:
        return self.create_user(user)

    async def update_bio_profile(self, patient_id: str, profile: dict) -> None:
        user = self.get_by_id(patient_id)
        if user:
            user.base_bio_profile = profile

    async def get_patients_by_supervisor(self, supervisor_email: str) -> List[User]:
        return [
            u for u in self._users.values()
            if u.role == Role.PACIENTE and u.supervisor_email == supervisor_email
        ]

    async def get_contacts(self, patient_id: str, ordered_by_priority: bool = True) -> List[EmergencyContact]:
        records = self._patient_contacts.get(patient_id, [])
        contacts = []
        for r in records:
            c = r["contact"]
            # Crear una copia de EmergencyContact con los datos relacionales específicos para este paciente
            contacts.append(
                EmergencyContact(
                    contact_id=c.contact_id,
                    patient_id=patient_id,
                    nombre=c.nombre,
                    telefono=c.telefono,
                    relacion=r["parentesco"],
                    es_principal=r["es_principal"],
                    prioridad_notificacion=r["prioridad_notificacion"],
                    created_at=c.created_at
                )
            )
        if ordered_by_priority:
            contacts.sort(key=lambda x: x.prioridad_notificacion)
        return contacts

    async def add_contact(
        self,
        patient_id:             str,
        contact:                EmergencyContact,
        parentesco:             str = "Familiar",
        prioridad_notificacion: int = 3,
    ) -> EmergencyContact:
        if not contact.contact_id:
            contact.contact_id = str(uuid.uuid4())
        if not contact.created_at:
            contact.created_at = datetime.now()

        if patient_id not in self._patient_contacts:
            self._patient_contacts[patient_id] = []

        # Determinar si es principal (si es el primero de prioridad 1 o si viene marcado)
        es_principal = getattr(contact, "es_principal", False) or len(self._patient_contacts[patient_id]) == 0

        # Eliminar si ya existe una asociación previa para este mismo contact_id
        self._patient_contacts[patient_id] = [
            r for r in self._patient_contacts[patient_id]
            if r["contact"].contact_id != contact.contact_id
        ]

        self._patient_contacts[patient_id].append({
            "contact": contact,
            "parentesco": parentesco,
            "prioridad_notificacion": prioridad_notificacion,
            "es_principal": es_principal
        })
        
        contact.patient_id = patient_id
        contact.relacion = parentesco
        contact.prioridad_notificacion = prioridad_notificacion
        contact.es_principal = es_principal
        return contact

    async def remove_contact(self, patient_id: str, contact_id: str) -> bool:
        if patient_id not in self._patient_contacts:
            return False
        initial_len = len(self._patient_contacts[patient_id])
        self._patient_contacts[patient_id] = [
            r for r in self._patient_contacts[patient_id]
            if r["contact"].contact_id != contact_id
        ]
        return len(self._patient_contacts[patient_id]) < initial_len
