"""
auth_controller.py — Endpoints para login y seguridad.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel
from typing import Optional

from src.infrastructure.configuration.container import user_repository, auth_service
from src.domain.entities.user import User, Role

router = APIRouter(prefix="/api/v1/auth", tags=["Auth"])
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str
    email: str

def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    """Extrae y valida el JWT, devolviendo el User asociado."""
    payload = auth_service.decode_token(token)
    if not payload or "sub" not in payload:
        raise HTTPException(status_code=401, detail="Token inválido o expirado")
        
    email = payload.get("sub")
    user = user_repository.get_by_email(email)
    if not user:
        raise HTTPException(status_code=401, detail="Usuario no encontrado")
    return user

@router.post("/login", response_model=TokenResponse)
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    """Valida credenciales y genera un Token JWT."""
    user = user_repository.get_by_email(form_data.username)
    if not user or not auth_service.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email o contraseña incorrectos",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Crear token
    token = auth_service.create_access_token(data={"sub": user.email, "role": str(user.role.value)})
    return TokenResponse(access_token=token, role=user.role.value, email=user.email)
