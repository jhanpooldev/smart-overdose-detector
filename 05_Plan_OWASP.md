# 05 — PLAN DE REMEDIACIÓN OWASP TOP 10

## Smart Overdose Detector — Roadmap de Corrección de Vulnerabilidades

**Fecha de Planificación:** 2026-06-12  
**Versión:** 1.0  
**Estado del Plan:** ACTIVO  
**Clasificación:** CONFIDENCIAL  

---

## 📋 RESUMEN EJECUTIVO

### Situación Actual
- **Score Global:** 4.2/10 (CRÍTICO — No apto para producción)
- **Vulnerabilidades Críticas:** 15
- **Vulnerabilidades Altas:** 7
- **Vulnerabilidades Medias:** 2

### Objetivo del Plan
Implementar remediación progresiva de vulnerabilidades OWASP Top 10 **sin interrumpir funcionalidad existente** ni procesos de negocio.

### Timeline de Implementación
- **Fase 1 (Crítico):** 2-3 semanas
- **Fase 2 (Alto):** 3-4 semanas
- **Fase 3 (Medio):** 2-3 semanas
- **Validación Integral:** 1 semana
- **Producción:** +2-3 semanas post-validación

**Duración Total Estimada:** 10-14 semanas

---

## 🎯 PRIORIZACIÓN Y ROADMAP

### FASE 1: REMEDIACIÓN CRÍTICA (Semanas 1-3)

#### Prioridad: P0-CRÍTICO (Bloquea producción)

| # | Vulnerabilidad | Riesgo | Impacto | Componentes | Mitigación |
|---|---|---|---|---|---|
| **1** | **Broken Access Control** | CRÍTICO | Acceso cross-user a datos de salud | Risk Controller, Auth Service | Implementar RBAC + validación patient_id |
| **2** | **SECRET_KEY Hardcodeada** | CRÍTICO | Token forgery, identity spoofing | Auth Service | Mover a variables de entorno |
| **3** | **Hash SHA256 sin salt** | CRÍTICO | Password cracking (rainbow tables) | Auth Service | Implementar bcrypt/argon2 |
| **4** | **Token 7 días válido** | CRÍTICO | Token theft window grande | Auth Service | Reducir a 15-30 minutos |
| **5** | **CORS Abierto a TODO** | CRÍTICO | CSRF attacks desde cualquier origen | FastAPI Middleware | Restringir a dominios específicos |
| **6** | **Sin Rate Limiting** | CRÍTICO | Brute force ilimitado | FastAPI App | Implementar SlowAPI o middleware |

---

### FASE 2: REMEDIACIÓN ALTA (Semanas 4-7)

#### Prioridad: P1-ALTO (Afecta seguridad en producción)

| # | Vulnerabilidad | Riesgo | Impacto | Componentes | Mitigación |
|---|---|---|---|---|---|
| **7** | **Ausencia de Row-Level Security** | ALTO | Lectura cross-user | Risk Repository | Filtros automáticos por user_id |
| **8** | **Roles no aplicados (RBAC)** | ALTO | Authorization bypass | All Controllers | Middleware de autorización |
| **9** | **Sin validación de relación Supervisor-Paciente** | ALTO | Acceso a pacientes no vinculados | Risk Controller | Verificación en BD |
| **10** | **Sin account lockout** | ALTO | Brute force contraseña | Auth Service | Límite 5-10 intentos/15 min |
| **11** | **Sin validación contraseña fuerte** | ALTO | Passwords débiles | Auth Service | Regex + NIST 800-63B |
| **12** | **Sin MFA/2FA** | ALTO | Single point of failure | Auth Service | SMS 2FA via Twilio (ya integrado) |
| **13** | **Sin revocación de sesiones** | ALTO | Sessions no expirábles | Auth Service | Token blacklist + logout endpoint |
| **14** | **Errores detallados expuestos** | ALTO | User enumeration | Error Handlers | Mensajes genéricos |

---

### FASE 3: REMEDIACIÓN MEDIA (Semanas 8-10)

#### Prioridad: P2-MEDIO (Mejora defensiva)

| # | Vulnerabilidad | Riesgo | Impacto | Componentes | Mitigación |
|---|---|---|---|---|---|
| **15** | **Sin CI/CD Pipeline** | MEDIO | Deployments sin testing | GitHub Actions | Workflows para test/lint/deploy |
| **16** | **Sin Audit Logs** | MEDIO | No trazabilidad (HIPAA violation) | Database Schema | tabla audit_logs |
| **17** | **Sin Security Headers** | MEDIO | Múltiples ataque vectors | FastAPI Middleware | X-Content-Type-Options, CSP, etc |
| **18** | **Sin Certificate Pinning** | MEDIO | MITM si CA comprometida | API Client (Flutter) | Implementar OkHttp pinning |
| **19** | **PyJWT versión vieja** | MEDIO | Posibles CVEs | Requirements.txt | Actualizar a PyJWT >= 2.8.0 |
| **20** | **Debug mode en producción** | MEDIO | Stack traces expuestos | main.py | reload=False en prod |

---

## 📐 ESTRATEGIAS DE MITIGACIÓN POR VULNERABILIDAD

### 1️⃣ BROKEN ACCESS CONTROL

#### Riesgo
- **CVSS 3.1:** 8.1 (High)
- **Probabilidad:** ALTA (trivial de explotar)
- **Impacto:** Acceso a datos médicos de otros pacientes

#### Componentes Afectados
- `backend/src/infrastructure/adapters/input/controllers/risk_controller.py`
- `backend/src/domain/entities/user.py`
- `backend/src/infrastructure/adapters/output/persistence/risk_repository.py`

#### Estrategia de Mitigación

**Paso 1: Crear middleware de autorización**
```python
# backend/src/infrastructure/middleware/authorization.py [NUEVO]

from fastapi import HTTPException, status
from enum import Enum

class AuthorizationMiddleware:
    """Valida RBAC + relaciones de datos en endpoints"""
    
    @staticmethod
    async def verify_patient_access(
        current_user: User,
        requested_patient_id: str,
        patient_repository: PatientRepository
    ) -> bool:
        """Verifica si user puede acceder a patient_id"""
        
        # PACIENTE solo ve sus propios datos
        if current_user.role == Role.PACIENTE:
            return current_user.id == requested_patient_id
        
        # SUPERVISOR solo ve pacientes asignados
        elif current_user.role == Role.SUPERVISOR:
            assigned = await patient_repository.get_assigned_to_supervisor(
                current_user.id
            )
            return requested_patient_id in assigned
        
        # ADMIN ve todo
        elif current_user.role == Role.ADMIN:
            return True
        
        return False
```

**Paso 2: Refactorizar endpoints con validación**
```python
# backend/src/infrastructure/adapters/input/controllers/risk_controller.py

@router.get("/alerts", tags=["Risk Detection"])
async def get_alerts(
    patient_id: str = Query("PAT-001"),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    auth_middleware: AuthorizationMiddleware = Depends()
):
    """✅ CORREGIDO: Valida autorización antes de retornar datos"""
    
    # ✅ NUEVA VALIDACIÓN
    is_authorized = await auth_middleware.verify_patient_access(
        current_user=current_user,
        requested_patient_id=patient_id,
        patient_repository=patient_repository
    )
    
    if not is_authorized:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No autorizado para acceder a este paciente"
        )
    
    # ✅ SEGURO: Solo retorna datos del paciente autorizado
    events = risk_repository.get_history(patient_id, limit)
    return [...]
```

**Paso 3: Agregar Row-Level Security en BD**
```python
# backend/src/infrastructure/adapters/output/persistence/risk_repository.py

class RiskRepository:
    async def get_history(self, patient_id: str, current_user_id: str, limit: int):
        """✅ SEGURO: Filtra automáticamente por patient_id"""
        
        # Obtener paciente y verificar acceso
        patient = await self.session.execute(
            select(PatientORM).where(PatientORM.id == patient_id)
        )
        patient = patient.scalar_one_or_none()
        
        if not patient:
            return []
        
        # Verificar relación en BD
        is_related = await self.session.execute(
            select(SupervisorPatient).where(
                (SupervisorPatient.patient_id == patient_id) &
                (SupervisorPatient.supervisor_id == current_user_id)
            )
        )
        
        if not is_related.scalar():
            raise PermissionError("Paciente no asignado")
        
        # ✅ Solo retorna datos del paciente autorizado
        events = await self.session.execute(
            select(RiskEventORM)
            .where(RiskEventORM.patient_id == patient_id)
            .order_by(RiskEventORM.created_at.desc())
            .limit(limit)
        )
        return events.scalars().all()
```

#### Estrategia de Validación

```bash
# Test 1: Paciente A intenta acceder a datos de Paciente B
# Resultado esperado: 403 Forbidden

POST /api/v1/auth/login
Body: {"email": "paciente-a@mail.com", "password": "..."}
Response: {"access_token": "token_a", ...}

GET /api/v1/risk/alerts?patient_id=PACIENTE-B
Headers: Authorization: Bearer token_a
Response: 403 Forbidden ✅

# Test 2: Supervisor intenta acceder a paciente no asignado
GET /api/v1/risk/alerts?patient_id=PACIENTE-NO-ASIGNADO
Response: 403 Forbidden ✅

# Test 3: Supervisor accede a paciente asignado
GET /api/v1/risk/alerts?patient_id=PACIENTE-ASIGNADO
Response: 200 OK [eventos...] ✅
```

#### Estrategia de Rollback

```bash
# Si hay problemas con middleware:
# 1. Desactivar validación temporalmente (feature flag)
# 2. Revertir commits
# 3. Mantener BD compatible (schema sin cambios)

# Reversión en 30 minutos máximo:
git revert HEAD~3..HEAD
# (middleware + auth_service + risk_controller)
```

---

### 2️⃣ CRYPTOGRAPHIC FAILURES (SECRET_KEY)

#### Riesgo
- **CVSS 3.1:** 9.8 (Critical)
- **Probabilidad:** CRÍTICA (SECRET_KEY en Git público)
- **Impacto:** Token forgery, acceso de 7 días

#### Componentes Afectados
- `backend/src/application/services/auth_service.py` (línea 12)
- `backend/.env` (configuración)
- `backend/.gitignore` (control de archivos)

#### Estrategia de Mitigación

**Paso 1: Rotar SECRET_KEY inmediatamente**
```bash
# 1. Generar nueva clave de 256 bits
python -c "import secrets; print(secrets.token_hex(32))"
# Salida: a7f3c2b1d9e8f0g4h5i6j7k8l9m0n1o2p3q4r5s6t7u8v9w0x1y2z3a4b5c6

# 2. Guardar en variables de entorno SEGURAS
# .env.local (gitignored):
SECRET_KEY=a7f3c2b1d9e8f0g4h5i6j7k8l9m0n1o2p3q4r5s6t7u8v9w0x1y2z3a4b5c6

# 3. REVOCAR todas las sesiones activas
# (Reloguear todos los usuarios después de deploy)
```

**Paso 2: Actualizar código para usar variables de entorno**
```python
# backend/src/application/services/auth_service.py

import os
from dotenv import load_dotenv

load_dotenv()  # Carga .env.local

class AuthService:
    # ✅ SEGURO: Lee de variable de entorno
    SECRET_KEY = os.getenv(
        "SECRET_KEY",
        None  # Sin default en producción
    )
    ALGORITHM = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES = 30  # Reducido a 30 minutos
    
    def __init__(self):
        if not self.SECRET_KEY:
            raise ValueError(
                "SECRET_KEY no configurada. Consulta .env.local"
            )
```

**Paso 3: Proteger repositorio**
```bash
# backend/.gitignore

# ✅ NUEVO: Evitar commits accidentales
.env
.env.local
.env.*.local
secrets/
*.key
*.pem
```

#### Estrategia de Validación

```bash
# Test: SECRET_KEY no está en repositorio
git log -p --all -- "SECRET_KEY"
# Resultado: No encontrado ✅

# Test: Variable de entorno funciona
export SECRET_KEY="test-key-256-bits"
python -m pytest tests/auth_service_test.py
# Resultado: 100% tests pass ✅

# Test: Tokens viejos se invalidan
# (Todos los usuarios requieren reloguear después de deploy)
```

#### Estrategia de Rollback

```bash
# Si hay problema con nueva clave:
# 1. Revertir SECRET_KEY a la anterior temporalmente
# 2. Investigar issues de validación
# 3. Re-deploy con correción

git revert HEAD~1
# Mantener sesiones activas (sin re-login forzado)
```

---

### 3️⃣ CRYPTOGRAPHIC FAILURES (Password Hashing)

#### Riesgo
- **CVSS 3.1:** 9.1 (Critical)
- **Probabilidad:** ALTA (rainbow tables públicas)
- **Impacto:** Password cracking en minutos

#### Componentes Afectados
- `backend/src/application/services/auth_service.py` (línea 14-16)
- `backend/requirements.txt` (dependencias)

#### Estrategia de Mitigación

**Paso 1: Instalar bcrypt**
```bash
# backend/requirements.txt
bcrypt==4.1.1

# Install
pip install -r requirements.txt
```

**Paso 2: Refactorizar hash y verificación**
```python
# backend/src/application/services/auth_service.py

import bcrypt
import os

class AuthService:
    
    @staticmethod
    def get_password_hash(password: str) -> str:
        """✅ SEGURO: Usa bcrypt con salt aleatorio"""
        salt = bcrypt.gensalt(rounds=12)  # 12 rondas = ~100ms
        hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
        return hashed.decode('utf-8')
    
    @staticmethod
    def verify_password(plain_password: str, hashed_password: str) -> bool:
        """✅ SEGURO: Verificación time-constant"""
        return bcrypt.checkpw(
            plain_password.encode('utf-8'),
            hashed_password.encode('utf-8')
        )
```

**Comparativa:**
```
ANTES (SHA256 sin salt):
  "test1234" → e3b0c44298fc1c14 (predecible)
  Tiempo crack: 0.001s (diccionario)

DESPUÉS (bcrypt 12 rondas):
  "test1234" → $2b$12$R9h7cIPz0gi.URNN0sU8ne9FjL9m5c5FNqmR.BU9cA5xVGI7i8r2K
  Tiempo crack: 2 segundos (por intento)
  → 86,400 segundos = 1 día para 1 password en diccionario
  → Con rate limiting (5 intentos/15min): imposible
```

#### Estrategia de Validación

```bash
# Test 1: Contraseña hashea correctamente
python -m pytest tests/auth_service_test.py::test_password_hash -v
# Resultado: PASSED ✅

# Test 2: Verificación funciona
python -m pytest tests/auth_service_test.py::test_verify_password -v
# Resultado: PASSED ✅

# Test 3: Hashes diferentes cada vez
hash1 = bcrypt.hashpw(b"test", salt)
hash2 = bcrypt.hashpw(b"test", salt)
assert hash1 != hash2  # Salts diferentes
# Resultado: PASSED ✅
```

#### Estrategia de Rollback

```bash
# Mantener ambas funciones durante 1 mes
def verify_password_legacy(plain, hashed):
    # Antigua (SHA256)
    ...

def verify_password(plain, hashed):
    # Nueva (bcrypt)
    ...

# En login: intentar nueva primero, si falla intentar antigua
# Esto permite transición sin forzar reset de passwords
```

---

### 4️⃣ CRYPTOGRAPHIC FAILURES (Token Duration)

#### Riesgo
- **CVSS 3.1:** 8.8 (High)
- **Probabilidad:** MEDIA (requiere token theft)
- **Impacto:** Ventana de explotación de 7 días

#### Componentes Afectados
- `backend/src/application/services/auth_service.py` (línea 176-178)

#### Estrategia de Mitigación

**Paso 1: Cambiar duración de token**
```python
# backend/src/application/services/auth_service.py

class AuthService:
    # ❌ ANTES: 7 DÍAS
    # ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7
    
    # ✅ DESPUÉS: 30 MINUTOS
    ACCESS_TOKEN_EXPIRE_MINUTES = 30
    
    # ✅ NUEVO: Refresh token (dura 7 días)
    REFRESH_TOKEN_EXPIRE_DAYS = 7
```

**Paso 2: Implementar refresh token mechanism**
```python
# backend/src/infrastructure/adapters/input/controllers/auth_controller.py

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int = 1800  # 30 minutos

@router.post("/token/refresh")
async def refresh_token(
    refresh_token: str,
    auth_service: AuthService = Depends()
) -> TokenResponse:
    """✅ NUEVO: Obtener nuevo access_token sin reloguear"""
    
    # Validar refresh_token
    payload = auth_service.verify_token(refresh_token)
    user_id = payload.get("sub")
    
    if not user_id:
        raise HTTPException(status_code=401, detail="Token inválido")
    
    # Generar nuevo access_token
    new_access_token = auth_service.create_access_token(
        data={"sub": user_id}
    )
    
    return TokenResponse(
        access_token=new_access_token,
        refresh_token=refresh_token,  # Reutilizar
        expires_in=1800
    )
```

**Paso 3: Actualizar cliente móvil**
```dart
// mobile/lib/infrastructure/auth/auth_service.dart

class AuthService {
  Future<void> refreshTokenIfNeeded() async {
    // Si token expira en < 5 minutos → refresh
    if (expiresAt.difference(DateTime.now()).inMinutes < 5) {
      final response = await apiClient.post(
        '/auth/token/refresh',
        body: {'refresh_token': refreshToken}
      );
      
      accessToken = response['access_token'];
      expiresAt = DateTime.now().add(Duration(minutes: 30));
    }
  }
}
```

#### Estrategia de Validación

```bash
# Test 1: Token expira después de 30 minutos
token = auth_service.create_access_token({"sub": "user-1"})
# sleep(1800)  # 30 minutos
auth_service.verify_token(token)  # ✅ Válido
# sleep(1)
auth_service.verify_token(token)  # ❌ Expirado

# Test 2: Refresh token funciona
new_token = auth_service.refresh_token(refresh_token)
# assert new_token is valid and expires in 30 minutes

# Test 3: Cliente móvil refreshea automáticamente
# (Espiar peticiones en Fiddler/Proxy)
```

#### Estrategia de Rollback

```bash
# Si app móvil no soporta refresh_tokens aún:
# 1. Aumentar duración a 2 horas (compromise)
# 2. Deploy y test en staging
# 3. Luego implementar refresh_tokens
# 4. Finalmente reducir a 30 minutos

# No es rollback completo, pero permite transición gradual
```

---

### 5️⃣ INSECURE DESIGN (CORS)

#### Riesgo
- **CVSS 3.1:** 8.5 (High)
- **Probabilidad:** MEDIA (requiere CSRF victim)
- **Impacto:** CSRF attacks, datos expuestos

#### Componentes Afectados
- `backend/src/main.py` (línea 421-426)

#### Estrategia de Mitigación

**Paso 1: Restringir CORS a dominios permitidos**
```python
# backend/src/main.py

from fastapi.middleware.cors import CORSMiddleware

# ✅ NUEVO: Lista blanca de dominios
ALLOWED_ORIGINS = [
    "https://smart-overdose-detector-production.up.railway.app",
    "https://api.smart-overdose-detector.com",  # Si hay custom domain
    "http://localhost:5173",  # Dev local (remover en prod)
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,  # ✅ Sin wildcard
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],  # ✅ Sin wildcard
    allow_headers=["Content-Type", "Authorization"],  # ✅ Específico
    max_age=3600,
)
```

**Paso 2: Usar variables de entorno para CORS**
```bash
# .env
ALLOWED_ORIGINS=https://smart-overdose-detector-production.up.railway.app,http://localhost:5173
```

```python
import os
origins = os.getenv("ALLOWED_ORIGINS", "").split(",")
# Parseado en startup
```

#### Estrategia de Validación

```bash
# Test 1: Requester válido acepta CORS
curl -H "Origin: https://smart-overdose-detector-production.up.railway.app" \
     -H "Access-Control-Request-Method: POST" \
     -X OPTIONS http://localhost:8000/api/v1/auth/login -v
# Response headers: Access-Control-Allow-Origin: https://smart-overdose-detector-production.up.railway.app ✅

# Test 2: Requester malicioso rechazado
curl -H "Origin: https://evil.com" \
     -H "Access-Control-Request-Method: POST" \
     -X OPTIONS http://localhost:8000/api/v1/auth/login -v
# Response headers: (sin Access-Control-Allow-Origin) ✅
```

---

### 6️⃣ INSECURE DESIGN (Rate Limiting)

#### Riesgo
- **CVSS 3.1:** 8.0 (High)
- **Probabilidad:** ALTA (brute force trivial)
- **Impacto:** Brute force de contraseñas y DDoS

#### Componentes Afectados
- `backend/src/main.py` (FastAPI app)

#### Estrategia de Mitigación

**Paso 1: Instalar slowapi**
```bash
# backend/requirements.txt
slowapi==0.1.8
```

**Paso 2: Configurar rate limiting**
```python
# backend/src/infrastructure/middleware/rate_limiting.py [NUEVO]

from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address

limiter = Limiter(
    key_func=get_remote_address,
    default_limits=["200 per day", "50 per hour"],
)

# Límites específicos por endpoint
RATE_LIMITS = {
    "/auth/login": "5 per 15 minutes",  # Brute force protection
    "/auth/register": "10 per hour",    # Account enumeration
    "/alerts": "100 per minute",        # Normal traffic
    "/telemetry/stream": "1000 per minute",  # High frequency IoT
}
```

**Paso 3: Aplicar a endpoints críticos**
```python
# backend/src/infrastructure/adapters/input/controllers/auth_controller.py

from slowapi import Limiter

limiter = Limiter(key_func=get_remote_address)

@router.post("/login")
@limiter.limit("5 per 15 minutes")  # ✅ Max 5 intentos en 15 min
async def login(
    request: Request,
    form_data: LoginRequest,
    auth_service: AuthService = Depends()
):
    """Intenta login. Después de 5 fallos → esperar 15 min"""
    
    try:
        user = await auth_service.authenticate(form_data.email, form_data.password)
        token = auth_service.create_access_token({"sub": user.id})
        return TokenResponse(access_token=token)
    except InvalidCredentials:
        raise HTTPException(status_code=401, detail="Credenciales inválidas")
```

**Paso 4: Registrar intentos en base de datos**
```python
# backend/src/infrastructure/adapters/output/persistence/login_attempt_repository.py [NUEVO]

class LoginAttempt(Base):
    __tablename__ = "login_attempts"
    
    id = Column(String, primary_key=True)
    email = Column(String)
    ip_address = Column(String)
    success = Column(Boolean)
    timestamp = Column(DateTime, default=datetime.utcnow)

class LoginAttemptRepository:
    async def log_attempt(self, email: str, ip: str, success: bool):
        attempt = LoginAttempt(
            id=str(uuid.uuid4()),
            email=email,
            ip_address=ip,
            success=success,
            timestamp=datetime.utcnow()
        )
        self.session.add(attempt)
        await self.session.commit()
        
        # Si 5 intentos fallidos en 15 minutos → alertar
        recent_failures = await self.session.execute(
            select(func.count(LoginAttempt.id)).where(
                (LoginAttempt.email == email) &
                (LoginAttempt.success == False) &
                (LoginAttempt.timestamp > datetime.utcnow() - timedelta(minutes=15))
            )
        )
        
        if recent_failures.scalar() >= 5:
            # ✅ TODO: Enviar alerta por email/SMS
            await alert_service.send_brute_force_alert(email)
```

#### Estrategia de Validación

```bash
# Test 1: Rate limiting activo
for i in {1..6}; do
  curl -X POST http://localhost:8000/api/v1/auth/login \
       -H "Content-Type: application/json" \
       -d '{"email":"test@mail.com","password":"wrong"}'
done

# Resultado:
# 1-5: 401 Unauthorized ✅
# 6: 429 Too Many Requests ✅

# Test 2: Después de 15 minutos se resetea
# sleep(900)
# curl ... → 401 (nuevo contador) ✅
```

---

### 7️⃣ AUTHENTICATION FAILURES (Validación Contraseña)

#### Riesgo
- **CVSS 3.1:** 7.5 (High)
- **Probabilidad:** ALTA (contraseñas débiles)
- **Impacto:** Acceso con credenciales simples

#### Componentes Afectados
- `backend/src/infrastructure/adapters/input/controllers/auth_controller.py`
- `backend/src/application/services/auth_service.py`

#### Estrategia de Mitigación

**Paso 1: Crear validador de contraseña**
```python
# backend/src/domain/services/password_validator.py [NUEVO]

import re
from typing import Tuple

class PasswordValidator:
    """Valida contraseña según NIST 800-63B"""
    
    MIN_LENGTH = 8
    REQUIRE_UPPERCASE = True
    REQUIRE_LOWERCASE = True
    REQUIRE_DIGIT = True
    REQUIRE_SPECIAL = True
    
    # Diccionario de contraseñas comunes
    COMMON_PASSWORDS = {
        "password", "123456", "12345678", "qwerty",
        "abc123", "monkey", "1234567", "letmein",
        "trustno1", "dragon", "baseball", "iloveyou",
        # ... más palabras comunes
    }
    
    @classmethod
    def validate(cls, password: str) -> Tuple[bool, str]:
        """Valida contraseña. Retorna (válida, mensaje_error)"""
        
        # Verificar longitud
        if len(password) < cls.MIN_LENGTH:
            return False, f"Mínimo {cls.MIN_LENGTH} caracteres"
        
        # Verificar si está en diccionario común
        if password.lower() in cls.COMMON_PASSWORDS:
            return False, "Contraseña muy común. Intenta otra"
        
        # Verificar mayúscula
        if cls.REQUIRE_UPPERCASE and not re.search(r'[A-Z]', password):
            return False, "Requiere mayúscula (A-Z)"
        
        # Verificar minúscula
        if cls.REQUIRE_LOWERCASE and not re.search(r'[a-z]', password):
            return False, "Requiere minúscula (a-z)"
        
        # Verificar dígito
        if cls.REQUIRE_DIGIT and not re.search(r'\d', password):
            return False, "Requiere dígito (0-9)"
        
        # Verificar carácter especial
        if cls.REQUIRE_SPECIAL and not re.search(r'[!@#$%^&*]', password):
            return False, "Requiere símbolo especial (!@#$%^&*)"
        
        return True, "Contraseña válida"
```

**Paso 2: Validar en registro y cambio de contraseña**
```python
# backend/src/infrastructure/adapters/input/controllers/auth_controller.py

@router.post("/register", response_model=TokenResponse)
async def register(
    req: RegisterRequest,
    password_validator: PasswordValidator = Depends()
):
    """✅ CORREGIDO: Valida contraseña antes de crear usuario"""
    
    # Validar contraseña
    is_valid, error_msg = password_validator.validate(req.password)
    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=error_msg
        )
    
    # Validar email no existe
    existing_user = await user_repository.get_by_email(req.email)
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email ya registrado"
        )
    
    # Crear usuario
    hashed_password = auth_service.get_password_hash(req.password)
    user = User(
        id=str(uuid.uuid4()),
        email=req.email,
        hashed_password=hashed_password,
        role=Role.PACIENTE,
        created_at=datetime.now()
    )
    
    await user_repository.save(user)
    token = auth_service.create_access_token({"sub": user.id})
    
    return TokenResponse(access_token=token, refresh_token=refresh_token)
```

#### Estrategia de Validación

```python
# tests/password_validator_test.py

def test_password_too_short():
    valid, msg = PasswordValidator.validate("Short1!")
    assert not valid
    assert "Mínimo 8 caracteres" in msg

def test_password_no_uppercase():
    valid, msg = PasswordValidator.validate("password123!")
    assert not valid
    assert "mayúscula" in msg

def test_password_no_digit():
    valid, msg = PasswordValidator.validate("Password!")
    assert not valid
    assert "dígito" in msg

def test_password_no_special():
    valid, msg = PasswordValidator.validate("Password123")
    assert not valid
    assert "símbolo" in msg

def test_password_valid():
    valid, msg = PasswordValidator.validate("MyPass123!")
    assert valid
    assert "válida" in msg

def test_password_common():
    valid, msg = PasswordValidator.validate("Password123!")  # Aún si cumple requisitos
    # Si "password123!" está en diccionario → rechazada
```

---

### 8️⃣ AUTHENTICATION FAILURES (2FA/MFA)

#### Riesgo
- **CVSS 3.1:** 8.0 (High)
- **Probabilidad:** MEDIA (requiere credential breach)
- **Impacto:** Acceso con credenciales comprometidas

#### Componentes Afectados
- `backend/src/application/services/auth_service.py`
- `backend/src/infrastructure/adapters/input/controllers/auth_controller.py`
- Twilio (ya integrado)

#### Estrategia de Mitigación

**Paso 1: Crear modelo de 2FA en BD**
```python
# backend/src/infrastructure/adapters/output/persistence/init_pmv2.sql

CREATE TABLE two_fa_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(255) NOT NULL REFERENCES users(id),
    code VARCHAR(6) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    attempts INT DEFAULT 0,
    verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT code_format CHECK (code ~ '^\d{6}$')
);

CREATE INDEX idx_2fa_user_id ON two_fa_codes(user_id);
CREATE INDEX idx_2fa_expires_at ON two_fa_codes(expires_at);
```

**Paso 2: Generar y enviar código SMS**
```python
# backend/src/application/services/two_fa_service.py [NUEVO]

import random
import os
from datetime import datetime, timedelta
from twilio.rest import Client

class TwoFAService:
    def __init__(self):
        self.twilio_client = Client(
            os.getenv("TWILIO_ACCOUNT_SID"),
            os.getenv("TWILIO_AUTH_TOKEN")
        )
    
    async def send_2fa_code(self, user: User) -> str:
        """Genera y envía código 2FA por SMS"""
        
        # Generar código aleatorio
        code = f"{random.randint(0, 999999):06d}"
        
        # Guardar en BD
        two_fa = TwoFACode(
            id=str(uuid.uuid4()),
            user_id=user.id,
            code=code,
            expires_at=datetime.utcnow() + timedelta(minutes=5),
            verified=False
        )
        await two_fa_repository.save(two_fa)
        
        # Enviar por SMS (Twilio ya integrado)
        try:
            self.twilio_client.messages.create(
                body=f"Tu código de verificación es: {code}",
                from_=os.getenv("TWILIO_PHONE_NUMBER"),
                to=user.phone_number  # Requiere número en User
            )
        except Exception as e:
            logger.error(f"Error enviando SMS: {e}")
            raise HTTPException(
                status_code=500,
                detail="Error enviando código. Intenta de nuevo"
            )
        
        # Retornar últimos 4 dígitos del número para feedback
        return "***" + user.phone_number[-4:]
    
    async def verify_2fa_code(
        self, user_id: str, code: str
    ) -> bool:
        """Verifica código 2FA"""
        
        two_fa = await two_fa_repository.get_latest_by_user(user_id)
        
        if not two_fa:
            return False
        
        # Verificar expiración
        if datetime.utcnow() > two_fa.expires_at:
            return False
        
        # Verificar código
        if two_fa.code != code:
            # Incrementar intentos (máximo 3)
            two_fa.attempts += 1
            if two_fa.attempts >= 3:
                await two_fa_repository.delete(two_fa.id)
                raise HTTPException(
                    status_code=429,
                    detail="Demasiados intentos. Solicita nuevo código"
                )
            await two_fa_repository.update(two_fa)
            return False
        
        # Marcar como verificado
        two_fa.verified = True
        await two_fa_repository.update(two_fa)
        return True
```

**Paso 3: Flujo de login con 2FA**
```python
# backend/src/infrastructure/adapters/input/controllers/auth_controller.py

class LoginStep1Request(BaseModel):
    email: str
    password: str

class LoginStep2Request(BaseModel):
    email: str
    two_fa_code: str

class LoginResponse(BaseModel):
    access_token: str
    refresh_token: str

@router.post("/login/step1")
async def login_step1(
    req: LoginStep1Request,
    auth_service: AuthService = Depends(),
    two_fa_service: TwoFAService = Depends()
):
    """Paso 1: Validar email + contraseña"""
    
    # Autenticar
    user = await auth_service.authenticate(req.email, req.password)
    if not user:
        raise HTTPException(status_code=401, detail="Credenciales inválidas")
    
    # Enviar código 2FA
    phone_masked = await two_fa_service.send_2fa_code(user)
    
    return {
        "status": "2fa_required",
        "message": f"Código enviado a {phone_masked}",
        "expires_in": 300  # 5 minutos
    }

@router.post("/login/step2", response_model=LoginResponse)
async def login_step2(
    req: LoginStep2Request,
    user_repository: UserRepository = Depends(),
    two_fa_service: TwoFAService = Depends(),
    auth_service: AuthService = Depends()
):
    """Paso 2: Verificar código 2FA"""
    
    # Obtener usuario
    user = await user_repository.get_by_email(req.email)
    if not user:
        raise HTTPException(status_code=401, detail="Usuario no encontrado")
    
    # Verificar código 2FA
    is_valid = await two_fa_service.verify_2fa_code(user.id, req.two_fa_code)
    if not is_valid:
        raise HTTPException(status_code=401, detail="Código inválido o expirado")
    
    # Generar tokens
    access_token = auth_service.create_access_token({"sub": user.id})
    refresh_token = auth_service.create_refresh_token({"sub": user.id})
    
    return LoginResponse(
        access_token=access_token,
        refresh_token=refresh_token
    )
```

**Paso 4: Actualizar cliente móvil**
```dart
// mobile/lib/screens/auth/login_screen.dart

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _step = "credentials";  // "credentials" → "2fa"
  
  void _handleLogin() async {
    if (_step == "credentials") {
      // Paso 1: Enviar credenciales
      final response = await apiClient.post(
        '/auth/login/step1',
        body: {'email': emailController.text, 'password': passwordController.text}
      );
      
      if (response['status'] == '2fa_required') {
        setState(() => _step = "2fa");
      }
    } else if (_step == "2fa") {
      // Paso 2: Enviar código 2FA
      final response = await apiClient.post(
        '/auth/login/step2',
        body: {
          'email': emailController.text,
          'two_fa_code': codeController.text
        }
      );
      
      if (response['access_token'] != null) {
        // Login exitoso
        await authService.saveToken(response['access_token']);
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_step == "credentials") {
      return _buildCredentialsForm();
    } else {
      return _build2FAForm();
    }
  }
}
```

#### Estrategia de Validación

```bash
# Test 1: Flujo 2FA completo
POST /api/v1/auth/login/step1
Body: {"email":"user@mail.com","password":"MyPass123!"}
Response: {"status":"2fa_required","message":"Código enviado a ***1234","expires_in":300} ✅

# Capturar código SMS (en test)
code=$(grep -o '\d{6}' sms_log.txt)

POST /api/v1/auth/login/step2
Body: {"email":"user@mail.com","two_fa_code":"$code"}
Response: {"access_token":"...","refresh_token":"..."} ✅

# Test 2: Código incorrecto
POST /api/v1/auth/login/step2
Body: {"email":"user@mail.com","two_fa_code":"000000"}
Response: 401 Unauthorized ✅

# Test 3: Código expirado (después de 5 minutos)
# sleep(300)
Response: 401 Unauthorized (expirado) ✅
```

---

## 🚀 IMPLEMENTACIÓN - MATRIZ DE EJECUCIÓN

### Timeline Semanal

#### Semana 1: RBAC + Autenticación Básica
- **Lunes-Martes:** Implementar middleware de autorización
- **Miércoles:** Rotar SECRET_KEY y mover a .env
- **Jueves:** Migrar a bcrypt
- **Viernes:** Testing y validación

#### Semana 2: Defensa en profundidad
- **Lunes-Martes:** Token expiration + refresh tokens
- **Miércoles:** Rate limiting
- **Jueves:** CORS restrictivo
- **Viernes:** Testing integración

#### Semana 3: Validación de entrada
- **Lunes-Martes:** Password strength validation
- **Miércoles-Jueves:** 2FA implementation
- **Viernes:** Testing end-to-end

---

## ⚠️ RIESGOS DE IMPLEMENTACIÓN

### Riesgo 1: Romper compatibilidad con cliente móvil
**Probabilidad:** MEDIA | **Impacto:** ALTO

**Mitigación:**
- Implementar nuevos endpoints sin remover antiguos
- Deploy de cliente móvil ANTES de cambios breaking
- Feature flags para activar/desactivar funcionalidad

### Riesgo 2: Downtime durante migración de contraseñas
**Probabilidad:** MEDIA | **Impacto:** ALTO

**Mitigación:**
- Migración gradual (verificar ambas funciones en login)
- No forzar reset de contraseña
- Período de transición de 1 mes

### Riesgo 3: Pérdida de acceso por CORS restrictivo
**Probabilidad:** BAJA | **Impacto:** CRÍTICO

**Mitigación:**
- Usar variables de entorno para dominios
- Testing exhaustivo en staging
- Rollback inmediato si hay problemas

### Riesgo 4: Performance degradada por rate limiting
**Probabilidad:** BAJA | **Impacto:** MEDIO

**Mitigación:**
- Usar Redis para rate limiting (mejor performance)
- Monitorear latencia después de deploy
- Ajustar límites según tráfico real

---

## ✅ VALIDACIÓN Y TESTING

### Testing Unitario
```bash
# Ejecutar tests de seguridad
pytest tests/ -v -k "auth or password or rbac"
```

### Testing de Integración
```bash
# Probar flujos completos
pytest tests/integration/ -v --tb=short
```

### Testing Manual en Staging
```bash
# 1. Login flow
# 2. Token expiration
# 3. Rate limiting
# 4. 2FA
# 5. CORS validation
# 6. Error messages (sin enumeration)
```

### Security Testing
```bash
# Scanning de vulnerabilidades
bandit -r backend/src/
pip-audit
```

---

## 📊 MÉTRICAS DE ÉXITO

| Métrica | Objetivo | Estado Actual |
|---|---|---|
| **Score OWASP** | 8.0/10 | 4.2/10 |
| **Vulnerabilidades Críticas** | 0 | 15 |
| **Vulnerabilidades Altas** | < 5 | 7 |
| **Test Coverage** | > 80% | TBD |
| **CVSS Promedio** | < 6.0 | 8.1 |
| **Tiempo de Token** | 30 min | 7 días |

---

## 📚 REFERENCIAS Y ESTÁNDARES

- **OWASP Top 10 2021:** https://owasp.org/Top10/
- **NIST 800-63B (Authentication):** https://pages.nist.gov/800-63-3/sp800-63b.html
- **HIPAA Security Rule:** https://www.hhs.gov/hipaa/
- **PCI DSS v3.2.1:** https://www.pcisecuritystandards.org/
- **CWE/CVSS Calculator:** https://www.first.org/cvss/calculator/3.1

---

## 📞 RESPONSABILIDADES

| Rol | Responsable | Horas Estimadas |
|---|---|---|
| **Architect de Seguridad** | @jhanpooldev | 40 horas |
| **Backend Engineer** | TBD | 60 horas |
| **Mobile Developer** | TBD | 20 horas |
| **QA/Security Tester** | TBD | 30 horas |
| **DevOps** | TBD | 10 horas |

**Total:** ~160 horas ≈ 4 semanas (1 FTE)

---

## 🔄 PRÓXIMOS PASOS

1. **Revisar** este plan con el equipo
2. **Asignar** recursos y responsabilidades
3. **Crear** issues en GitHub por cada vulnerabilidad
4. **Iniciar** Fase 1 (CRÍTICO)
5. **Programar** reuniones de checkpoint semanales

---

**Documento Generado:** 2026-06-12  
**Versión:** 1.0  
**Próxima Revisión:** Post-Fase 1 (2026-06-28)
