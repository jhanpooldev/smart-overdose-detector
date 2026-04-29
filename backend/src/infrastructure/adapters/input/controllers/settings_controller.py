"""
settings_controller.py — Endpoints para configurar umbrales de paciente.
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from src.domain.entities.user import User
from src.infrastructure.adapters.input.controllers.auth_controller import get_current_user
from src.infrastructure.configuration.container import settings_repository

router = APIRouter(prefix="/api/v1/settings", tags=["Settings"])

class SettingsRequest(BaseModel):
    min_bpm: int
    max_bpm: int

class SettingsResponse(BaseModel):
    min_bpm: int
    max_bpm: int

@router.get("/", response_model=SettingsResponse)
async def get_settings(current_user: User = Depends(get_current_user)):
    user_settings = settings_repository.get_by_user_id(current_user.id)
    return SettingsResponse(min_bpm=user_settings["min_bpm"], max_bpm=user_settings["max_bpm"])

@router.put("/", response_model=SettingsResponse)
async def update_settings(req: SettingsRequest, current_user: User = Depends(get_current_user)):
    if req.min_bpm <= 0 or req.max_bpm <= 0 or req.min_bpm >= req.max_bpm:
        raise HTTPException(status_code=400, detail="complete los campos obligatorios y asegurese que el rango sea válido")
    
    updated = settings_repository.update(current_user.id, req.min_bpm, req.max_bpm)
    return SettingsResponse(min_bpm=updated["min_bpm"], max_bpm=updated["max_bpm"])
