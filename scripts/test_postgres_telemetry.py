"""
scripts/test_postgres_telemetry.py — Script de verificación para probar los repositorios Postgres reales.
"""
import os
import sys
import asyncio
from datetime import datetime
import uuid

# ── Fix Python path so `src.*` imports resolve to backend/src/ ──────────────
_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_BACKEND_DIR = os.path.join(_REPO_ROOT, "backend")
if _BACKEND_DIR not in sys.path:
    sys.path.insert(0, _BACKEND_DIR)

from dotenv import load_dotenv

# Cargar variables de entorno del backend si existe
backend_env = os.path.join(os.path.dirname(os.path.dirname(__file__)), "backend", ".env")
if os.path.exists(backend_env):
    load_dotenv(backend_env)
else:
    load_dotenv()

os.environ["STORAGE_BACKEND"] = "postgres"
if not os.environ.get("DATABASE_URL"):
    os.environ["DATABASE_URL"] = "postgresql://postgres@localhost:5432/Overdose-detector"


from src.infrastructure.adapters.output.persistence.postgres_repository import (
    PostgresUserRepository,
    PostgresSignalRepository,
    PostgresIoTSessionRepository,
    PostgresRiskRepository,
)
from src.domain.entities.user import User, Role
from src.domain.entities.biometric_signal import BiometricSignal, MovementStatus
from src.domain.entities.iot_session import IoTSession, IoTStreamStatus
from src.domain.entities.emergency_contact import EmergencyContact


async def main():
    print("=" * 60)
    print("PROBANDO CONEXIÓN Y OPERACIONES EN POSTGRES REAL (PMV2)")
    print("=" * 60)

    db_url = os.environ["DATABASE_URL"]
    user_repo = PostgresUserRepository(db_url)
    signal_repo = PostgresSignalRepository(db_url)
    session_repo = PostgresIoTSessionRepository(db_url)

    # 1. Crear Supervisor y Paciente
    sup_email = "postgres_supervisor@sod.com"
    pac_email = "postgres_paciente@sod.com"

    # Limpiar previos si existen
    with user_repo._Session() as session:
        from src.infrastructure.adapters.output.persistence.postgres_repository import UserORM, ContactORM, PatientContactORM, IoTSessionORM, BiometricSignalORM
        session.query(BiometricSignalORM).delete()
        session.query(IoTSessionORM).delete()
        session.query(PatientContactORM).delete()
        session.query(ContactORM).delete()
        session.query(UserORM).filter(UserORM.email.in_([sup_email, pac_email])).delete()
        session.commit()

    print("[INFO] Creando usuarios...")
    sup = User(
        id=str(uuid.uuid4()),
        email=sup_email,
        role=Role.SUPERVISOR,
        hashed_password="hash",
        created_at=datetime.utcnow(),
        telefono="+51999999999",
        nombre="Supervisor Postgres"
    )
    user_repo.create_user(sup)

    pac = User(
        id=str(uuid.uuid4()),
        email=pac_email,
        role=Role.PACIENTE,
        hashed_password="hash",
        created_at=datetime.utcnow(),
        supervisor_email=sup_email,
        nombre="Paciente Postgres"
    )
    user_repo.create_user(pac)
    print(f"[OK] Paciente creado con ID: {pac.id}")

    # 2. Agregar contacto de emergencia
    print("[INFO] Agregando contacto de emergencia...")
    contact = EmergencyContact(
        contact_id=str(uuid.uuid4()),
        patient_id=pac.id,
        nombre="Contacto Auxiliar",
        telefono="+51888888888",
        relacion="Amigo",
        es_principal=True
    )
    await user_repo.add_contact(pac.id, contact, parentesco="Amigo", prioridad_notificacion=1)
    
    contacts = await user_repo.get_contacts(pac.id)
    assert len(contacts) == 1
    assert contacts[0].nombre == "Contacto Auxiliar"
    print("[OK] Contacto de emergencia agregado y consultado de manera exitosa.")

    # 3. Crear sesión IoT
    print("[INFO] Creando sesión IoT...")
    session = IoTSession.create_new(patient_id=pac.id)
    saved_session = await session_repo.create_session(session)
    assert saved_session.session_token == session.session_token
    print(f"[OK] Sesión creada con Token: {session.session_token}")

    # 4. Ingestar señal biométrica
    print("[INFO] Ingestando señal biométrica...")
    signal = BiometricSignal.create(
        patient_id=pac.id,
        device_id=str(uuid.uuid4()),
        heart_rate=80,
        spo2=98,
        resp_rate=15,
        status_movement=MovementStatus.WALKING,
        session_token=session.session_token,
        source="iot"
    )
    await signal_repo.ingest(signal)
    
    # Actualizar heartbeat
    await session_repo.update_status(session.session_token, IoTStreamStatus.CONNECTED, heartbeat=True)
    
    # Verificar online status
    is_online = await session_repo.is_patient_online(pac.id)
    assert is_online is True
    print("[OK] Paciente figura ONLINE.")

    # 5. Obtener historial
    history = await signal_repo.get_history(pac.id)
    assert len(history) == 1
    assert history[0].heart_rate == 80
    assert history[0].spo2 == 98
    print("[OK] Historial biométrico recuperado correctamente.")
    print("\n[SUCCESS] TODAS LAS PRUEBAS DE POSTGRES COMPLETADAS CON EXITO.")



if __name__ == "__main__":
    asyncio.run(main())
