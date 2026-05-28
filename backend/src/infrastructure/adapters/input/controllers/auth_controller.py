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
    id: str
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
    telefono: Optional[str] = None   # numero celular

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
        id=user.id,
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

    if user_role == Role.PACIENTE and req.supervisor_email:
        sup = user_repository.get_by_email(req.supervisor_email)
        if not sup or sup.role != Role.SUPERVISOR:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Supervisor no encontrado, verifica las credenciales"
            )

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
        telefono=req.telefono,
    )
    user_repository.create_user(new_user)
    
    # Si es paciente y tiene supervisor, crear contacto de emergencia automáticamente
    if user_role == Role.PACIENTE and req.supervisor_email:
        sup = user_repository.get_by_email(req.supervisor_email)
        if sup and sup.telefono:
            from src.infrastructure.configuration.container import contact_repository
            from src.domain.entities.emergency_contact import EmergencyContact
            new_contact = EmergencyContact(
                contact_id=str(uuid.uuid4()),
                patient_id=new_user.id,
                nombre="Supervisor",
                telefono=sup.telefono,
                relacion="Supervisor Medico",
                es_principal=True
            )
            contact_repository.create(new_contact)
    
    # Crear token e iniciar sesion
    token = auth_service.create_access_token(data={"sub": new_user.email, "role": str(new_user.role.value)})
    return TokenResponse(
        access_token=token, 
        role=new_user.role.value, 
        email=new_user.email, 
        id=new_user.id,
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

class UpdateBiometricsRequest(BaseModel):
    edad: int | None = None
    peso: float | None = None
    altura: float | None = None
    is_manual: bool | None = None
    bpm_min_normal: int | None = None
    bpm_max_normal: int | None = None
    bpm_min_moderate: int | None = None
    bpm_max_moderate: int | None = None
    spo2_min_normal: float | None = None
    spo2_min_moderate: float | None = None
    spo2_min_critical: float | None = None

@router.put("/thresholds/{patient_id}", tags=["Thresholds"])
async def update_patient_thresholds(
    patient_id: str,
    req: UpdateBiometricsRequest,
    current_user: User = Depends(get_current_user)
):
    """Actualiza datos biométricos y/o umbrales manuales del paciente."""
    if current_user.role != Role.SUPERVISOR and current_user.id != patient_id:
        raise HTTPException(status_code=403, detail="Solo supervisores o el propio paciente pueden modificar umbrales")
    patient = user_repository.get_by_id(patient_id)
    if not patient or patient.role != Role.PACIENTE:
        raise HTTPException(status_code=404, detail="Paciente no encontrado")
    
    if req.edad is not None: patient.edad = req.edad
    if req.peso is not None: patient.peso = req.peso
    if req.altura is not None: patient.altura = req.altura

    from src.infrastructure.adapters.output.persistence.postgres_repository import PostgresUserRepository
    from src.infrastructure.configuration.settings import settings

    if settings.STORAGE_BACKEND == "postgres":
        if isinstance(user_repository, PostgresUserRepository):
            with user_repository._Session() as session:
                from src.infrastructure.adapters.output.persistence.postgres_repository import UserORM, ThresholdORM
                import uuid
                user_row = session.query(UserORM).filter(UserORM.id == uuid.UUID(patient_id)).first()
                if user_row:
                    if req.edad is not None: user_row.edad = req.edad
                    if req.peso is not None: user_row.peso = req.peso
                    if req.altura is not None: user_row.altura = req.altura

                if req.is_manual is False:
                    session.query(ThresholdORM).filter(ThresholdORM.patient_id == uuid.UUID(patient_id)).delete()
                elif any(x is not None for x in [req.bpm_min_normal, req.bpm_max_normal, req.bpm_min_moderate, req.bpm_max_moderate, req.spo2_min_normal, req.spo2_min_moderate, req.spo2_min_critical]):
                    thresh_row = session.query(ThresholdORM).filter(ThresholdORM.patient_id == uuid.UUID(patient_id)).first()
                    if not thresh_row:
                        thresh_row = ThresholdORM(patient_id=uuid.UUID(patient_id))
                        session.add(thresh_row)
                    
                    tanaka = _calculate_thresholds(patient)
                    if req.bpm_min_normal is not None: thresh_row.bpm_min_normal = req.bpm_min_normal
                    else: thresh_row.bpm_min_normal = thresh_row.bpm_min_normal or tanaka["bpm"]["normal_min"]

                    if req.bpm_max_normal is not None: thresh_row.bpm_max_normal = req.bpm_max_normal
                    else: thresh_row.bpm_max_normal = thresh_row.bpm_max_normal or tanaka["bpm"]["normal_max"]

                    if req.bpm_min_moderate is not None: thresh_row.bpm_min_moderate = req.bpm_min_moderate
                    else: thresh_row.bpm_min_moderate = thresh_row.bpm_min_moderate or tanaka["bpm"]["moderate_lo"]

                    if req.bpm_max_moderate is not None: thresh_row.bpm_max_moderate = req.bpm_max_moderate
                    else: thresh_row.bpm_max_moderate = thresh_row.bpm_max_moderate or tanaka["bpm"]["moderate_hi"]

                    if req.spo2_min_normal is not None: thresh_row.spo2_min_normal = int(req.spo2_min_normal)
                    else: thresh_row.spo2_min_normal = thresh_row.spo2_min_normal or int(tanaka["spo2"]["normal_min"])

                    if req.spo2_min_moderate is not None: thresh_row.spo2_min_moderate = int(req.spo2_min_moderate)
                    else: thresh_row.spo2_min_moderate = thresh_row.spo2_min_moderate or int(tanaka["spo2"]["moderate_min"])

                    if req.spo2_min_critical is not None: thresh_row.spo2_min_critical = int(req.spo2_min_critical)
                    else: thresh_row.spo2_min_critical = thresh_row.spo2_min_critical or int(tanaka["spo2"]["critical_max"])

                session.commit()
    else:
        if not hasattr(user_repository, "_custom_thresholds"):
            user_repository._custom_thresholds = {}
        
        if req.is_manual is False:
            if patient_id in user_repository._custom_thresholds:
                del user_repository._custom_thresholds[patient_id]
        elif any(x is not None for x in [req.bpm_min_normal, req.bpm_max_normal, req.bpm_min_moderate, req.bpm_max_moderate, req.spo2_min_normal, req.spo2_min_moderate, req.spo2_min_critical]):
            tanaka = _calculate_thresholds(patient)
            existing = user_repository._custom_thresholds.get(patient_id, {})
            user_repository._custom_thresholds[patient_id] = {
                "bpm_min_normal": req.bpm_min_normal if req.bpm_min_normal is not None else existing.get("bpm_min_normal", tanaka["bpm"]["normal_min"]),
                "bpm_max_normal": req.bpm_max_normal if req.bpm_max_normal is not None else existing.get("bpm_max_normal", tanaka["bpm"]["normal_max"]),
                "bpm_min_moderate": req.bpm_min_moderate if req.bpm_min_moderate is not None else existing.get("bpm_min_moderate", tanaka["bpm"]["moderate_lo"]),
                "bpm_max_moderate": req.bpm_max_moderate if req.bpm_max_moderate is not None else existing.get("bpm_max_moderate", tanaka["bpm"]["moderate_hi"]),
                "spo2_min_normal": req.spo2_min_normal if req.spo2_min_normal is not None else existing.get("spo2_min_normal", tanaka["spo2"]["normal_min"]),
                "spo2_min_moderate": req.spo2_min_moderate if req.spo2_min_moderate is not None else existing.get("spo2_min_moderate", tanaka["spo2"]["moderate_min"]),
                "spo2_min_critical": req.spo2_min_critical if req.spo2_min_critical is not None else existing.get("spo2_min_critical", tanaka["spo2"]["critical_max"]),
            }

    return _calculate_thresholds(patient)

def _calculate_thresholds(user: User) -> dict:
    """Calcula umbrales clinicos usando la formula de Tanaka o retorna umbrales manuales si existen."""
    custom = None
    from src.infrastructure.configuration.settings import settings
    if settings.STORAGE_BACKEND == "postgres":
        from src.infrastructure.adapters.output.persistence.postgres_repository import PostgresUserRepository
        if isinstance(user_repository, PostgresUserRepository):
            with user_repository._Session() as session:
                from src.infrastructure.adapters.output.persistence.postgres_repository import ThresholdORM
                import uuid
                row = session.query(ThresholdORM).filter(ThresholdORM.patient_id == uuid.UUID(user.id)).first()
                if row:
                    custom = {
                        "bpm_min_normal": row.bpm_min_normal,
                        "bpm_max_normal": row.bpm_max_normal,
                        "bpm_min_moderate": row.bpm_min_moderate,
                        "bpm_max_moderate": row.bpm_max_moderate,
                        "spo2_min_normal": row.spo2_min_normal,
                        "spo2_min_moderate": row.spo2_min_moderate,
                        "spo2_min_critical": row.spo2_min_critical,
                    }
    else:
        if hasattr(user_repository, "_custom_thresholds") and user.id in user_repository._custom_thresholds:
            custom = user_repository._custom_thresholds[user.id]

    edad = user.edad or 30
    peso = user.peso or 70.0
    altura = user.altura or 1.70

    # Frecuencia cardiaca maxima (Tanaka, 2001)
    fc_max = 208 - (0.7 * edad)

    # IMC y ajuste por obesidad
    imc = peso / (altura ** 2)
    ajuste = 5 if imc > 30 else 0

    if custom:
        return {
            "fc_max": round(fc_max),
            "imc": round(imc, 1),
            "bpm": {
                "normal_min": custom["bpm_min_normal"],
                "normal_max": custom["bpm_max_normal"],
                "moderate_lo": custom["bpm_min_moderate"],
                "moderate_hi": custom["bpm_max_moderate"],
                "critical_lo": 50,
                "critical_hi": custom["bpm_max_moderate"] + 10,
            },
            "spo2": {
                "normal_min": float(custom["spo2_min_normal"]),
                "moderate_min": float(custom["spo2_min_moderate"]),
                "critical_max": float(custom["spo2_min_critical"]),
            },
            "is_manual": True
        }

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
        "is_manual": False
    }
