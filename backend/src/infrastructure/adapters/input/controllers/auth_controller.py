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
    supervisor_email: Optional[str] = None

class RegisterRequest(BaseModel):
    email: str
    password: str
    name: str
    role: str = "PACIENTE"
    supervisor_email: Optional[str] = None
    edad: Optional[int] = None       # años
    peso: Optional[float] = None     # kg
    altura: Optional[float] = None   # metros
    sexo: Optional[str] = None       # 'Masculino' | 'Femenino' | 'Otro'

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
    return TokenResponse(
        access_token=token, 
        role=user.role.value, 
        email=user.email, 
        supervisor_email=user.supervisor_email
    )

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
        created_at=datetime.now(),
        supervisor_email=req.supervisor_email,
        edad=req.edad,
        peso=req.peso,
        altura=req.altura,
        sexo=req.sexo,
    )
    user_repository.create_user(new_user)
    
    # Crear token e iniciar sesion
    token = auth_service.create_access_token(data={"sub": new_user.email, "role": str(new_user.role.value)})
    return TokenResponse(
        access_token=token, 
        role=new_user.role.value, 
        email=new_user.email, 
        supervisor_email=new_user.supervisor_email
    )

@router.get("/patients", tags=["Users"])
async def get_patients(current_user: User = Depends(get_current_user)):
    """Retorna la lista de pacientes asignados al supervisor actual."""
    if current_user.role != Role.SUPERVISOR:
        raise HTTPException(status_code=403, detail="Solo los supervisores pueden ver pacientes")
    
    all_users = user_repository.get_all()
    patients = [
        {
            "id": u.id,
            "email": u.email,
            "role": u.role.value,
        }
        for u in all_users
        if u.role == Role.PACIENTE and u.supervisor_email == current_user.email
    ]
    return patients

@router.get("/thresholds", tags=["Thresholds"])
async def get_my_thresholds(current_user: User = Depends(get_current_user)):
    """Retorna los umbrales calculados del paciente autenticado."""
    return _calculate_thresholds(current_user)

@router.get("/thresholds/{patient_id}", tags=["Thresholds"])
async def get_patient_thresholds(
    patient_id: str,
    current_user: User = Depends(get_current_user)
):
    """Supervisor: obtiene los umbrales del paciente especificado."""
    if current_user.role == Role.PACIENTE and current_user.id != patient_id:
        raise HTTPException(status_code=403, detail="Acceso denegado")
    patient = user_repository.get_by_id(patient_id)
    if not patient:
        raise HTTPException(status_code=404, detail="Paciente no encontrado")
    return _calculate_thresholds(patient)

def _calculate_thresholds(user: User) -> dict:
    """Calcula umbrales clinicos usando la formula de Tanaka."""
    edad = user.edad or 30
    peso = user.peso or 70.0
    altura = user.altura or 1.70

    # Frecuencia cardiaca maxima (Tanaka, 2001)
    fc_max = 208 - (0.7 * edad)

    # IMC y ajuste por obesidad
    imc = peso / (altura ** 2)
    ajuste = 5 if imc > 30 else 0

    return {
        "fc_max": round(fc_max),
        "imc": round(imc, 1),
        "bpm": {
            "normal_min": 60,
            "normal_max": round(0.75 * fc_max) - ajuste,
            "moderate_lo": round(0.50 * fc_max),
            "moderate_hi": round(0.90 * fc_max) + ajuste,
            "critical_lo": 50,
            "critical_hi": round(fc_max) + ajuste,
        },
        "spo2": {
            "normal_min": 95.0,
            "moderate_min": 90.0,
            "critical_max": 82.0,
        },
    }
