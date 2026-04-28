"""
auth_controller.py — Endpoints para login y seguridad.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel
from typing import Optional

from datetime import datetime
import uuid

from src.infrastructure.configuration.container import user_repository, auth_service
from src.domain.entities.user import User, Role

router = APIRouter(prefix="/api/v1/auth", tags=["Auth"])
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str
    email: str

class RegisterRequest(BaseModel):
    email: str
    password: str
    name: str
    role: str = "PACIENTE"

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
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no registrado",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if not auth_service.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Contraseña incorrecta",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Crear token
    token = auth_service.create_access_token(data={"sub": user.email, "role": str(user.role.value)})
    return TokenResponse(access_token=token, role=user.role.value, email=user.email)

@router.post("/register", response_model=TokenResponse)
async def register(req: RegisterRequest):
    """Crea una nueva cuenta de usuario."""
    if user_repository.get_by_email(req.email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="correo ya registrado",
        )
    
    # Intentar parsear el role
    try:
        user_role = Role(req.role.upper())
    except ValueError:
        user_role = Role.PACIENTE

    new_user = User(
        id=str(uuid.uuid4()),
        email=req.email,
        role=user_role,
        hashed_password=auth_service.get_password_hash(req.password),
        created_at=datetime.now()
    )
    user_repository.create_user(new_user)
    
    # Crear token e iniciar sesion
    token = auth_service.create_access_token(data={"sub": new_user.email, "role": str(new_user.role.value)})
    return TokenResponse(access_token=token, role=new_user.role.value, email=new_user.email)
