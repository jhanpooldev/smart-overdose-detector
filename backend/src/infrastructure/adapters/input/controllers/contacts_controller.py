"""
contacts_controller.py — Endpoints para contactos de emergencia.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from typing import List, Optional
import uuid

from src.domain.entities.user import User
from src.domain.entities.emergency_contact import EmergencyContact
from src.infrastructure.adapters.input.controllers.auth_controller import get_current_user
from src.infrastructure.configuration.container import contact_repository

router = APIRouter(prefix="/api/v1/contacts", tags=["Contacts"])

class ContactRequest(BaseModel):
    nombre: str
    telefono: str
    relacion: str
    es_principal: bool = False

class ContactResponse(BaseModel):
    contact_id: str
    nombre: str
    telefono: str
    relacion: str
    es_principal: bool

@router.get("/", response_model=List[ContactResponse])
async def get_contacts(current_user: User = Depends(get_current_user)):
    contacts = contact_repository.get_by_patient_id(current_user.id)
    return [
        ContactResponse(
            contact_id=c.contact_id,
            nombre=c.nombre,
            telefono=c.telefono,
            relacion=c.relacion,
            es_principal=c.es_principal
        ) for c in contacts
    ]

@router.post("/", response_model=ContactResponse)
async def create_contact(req: ContactRequest, current_user: User = Depends(get_current_user)):
    # Validaciones básicas
    if not req.nombre or not req.telefono:
        raise HTTPException(status_code=400, detail="complete los campos obligatorios")
    if len(req.telefono) < 6:
        raise HTTPException(status_code=400, detail="número inválido")

    # Prevenir duplicados
    existing = contact_repository.get_by_patient_id(current_user.id)
    for c in existing:
        if c.telefono == req.telefono:
            raise HTTPException(status_code=400, detail="contacto ya existente")

    new_contact = EmergencyContact(
        contact_id=str(uuid.uuid4()),
        patient_id=current_user.id,
        nombre=req.nombre,
        telefono=req.telefono,
        relacion=req.relacion,
        es_principal=req.es_principal
    )
    saved_contact = contact_repository.create(new_contact)
    
    return ContactResponse(
        contact_id=saved_contact.contact_id,
        nombre=saved_contact.nombre,
        telefono=saved_contact.telefono,
        relacion=saved_contact.relacion,
        es_principal=saved_contact.es_principal
    )
