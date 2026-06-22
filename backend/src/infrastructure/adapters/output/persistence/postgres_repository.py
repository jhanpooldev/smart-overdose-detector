"""
postgres_repository.py — Repositorios PostgreSQL para todos los puertos del dominio.

Implementa:
  - IUserRepository (PMV1)
  - IPatientRepository (PMV2)
  - ISignalRepository (PMV1)
  - IBiometricSignalRepository (PMV2)
  - IIoTSessionRepository (PMV2)
  - IRiskRepository (PMV1/PMV2)

Usa SQLAlchemy con conexión directa a TimescaleDB/PostgreSQL.
"""
from datetime import datetime, timedelta
from typing import List, Optional, Sequence, Tuple
import logging
import uuid

from sqlalchemy import (
    create_engine, text,
    Column, Float, Integer, String, DateTime, Boolean, Text, ForeignKey
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID, JSONB
from sqlalchemy.orm import declarative_base, sessionmaker
from sqlalchemy.exc import OperationalError

from src.domain.entities.biometric_reading import BiometricReading
from src.domain.entities.biometric_signal import BiometricSignal, MovementStatus
from src.domain.entities.iot_session import IoTSession, IoTStreamStatus
from src.domain.entities.user import User, Role
from src.domain.entities.risk_event import RiskEvent, RiskLevel
from src.domain.entities.emergency_contact import EmergencyContact
from src.domain.ports.i_signal_repository import ISignalRepository
from src.domain.ports.i_user_repository import IUserRepository
from src.domain.ports.i_risk_repository import IRiskRepository
from src.application.ports.output_ports import (
    IBiometricSignalRepository,
    IPatientRepository,
    IIoTSessionRepository,
)

logger = logging.getLogger(__name__)
Base = declarative_base()


# ──────────────────────────────────────────────
# ORM Models (matching init_pmv2.sql perfectly)
# ──────────────────────────────────────────────

class UserORM(Base):
    __tablename__ = "users"

    id               = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email            = Column(String(255), nullable=False, unique=True)
    hashed_password  = Column(String(255), nullable=False)
    role             = Column(String(20), nullable=False)
    supervisor_email = Column(String(255), nullable=True)
    nombre           = Column(String(150), nullable=True)
    edad             = Column(Integer, nullable=True)
    peso             = Column(Float, nullable=True)
    altura           = Column(Float, nullable=True)
    sexo             = Column(String(20), nullable=True)
    telefono         = Column(String(25), nullable=True)
    base_bio_profile = Column(JSONB, nullable=True, default={})
    created_at       = Column(DateTime, nullable=False, default=datetime.now)


class IoTSessionORM(Base):
    __tablename__ = "iot_sessions"

    session_token   = Column(String(6), primary_key=True)
    patient_id      = Column(PG_UUID(as_uuid=True), nullable=False)
    stream_status   = Column(String(20), nullable=False, default="DISCONNECTED")
    last_heartbeat  = Column(DateTime, nullable=True)
    created_at      = Column(DateTime, nullable=False, default=datetime.now)
    expires_at      = Column(DateTime, nullable=False)


class BiometricSignalORM(Base):
    __tablename__ = "biometric_signals"

    time            = Column(DateTime, primary_key=True, default=datetime.now)
    device_id       = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    patient_id      = Column(PG_UUID(as_uuid=True), nullable=False)
    session_token   = Column(String(6), nullable=True)
    heart_rate      = Column(Integer, nullable=False)
    spo2            = Column(Integer, nullable=False)
    resp_rate       = Column(Integer, nullable=True)
    status_movement = Column(String(20), nullable=False, default="UNKNOWN")
    source          = Column(String(20), default="iot")


class RiskEventORM(Base):
    __tablename__ = "risk_events"

    event_id          = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    patient_id        = Column(PG_UUID(as_uuid=True), nullable=False)
    detected_at       = Column(DateTime, nullable=False, default=datetime.now)
    risk_level        = Column(String(20), nullable=False)
    probability       = Column(Float, nullable=False, default=0.0)
    spo2_at_event     = Column(Integer, nullable=False)
    bpm_at_event      = Column(Integer, nullable=False)
    resp_rate_at_event = Column(Integer, nullable=True)
    movement_at_event = Column(String(20), nullable=False, default="UNKNOWN")
    alert_sent        = Column(Boolean, nullable=False, default=False)
    sma_spo2          = Column(Float, nullable=True)
    sma_bpm           = Column(Float, nullable=True)


class ContactORM(Base):
    __tablename__ = "contacts"

    contact_id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    nombre     = Column(String(150), nullable=False)
    telefono   = Column(String(25), nullable=False)
    email      = Column(String(255), nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.now)


class PatientContactORM(Base):
    __tablename__ = "patient_contacts"

    id                     = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    patient_id             = Column(PG_UUID(as_uuid=True), nullable=False)
    contact_id             = Column(PG_UUID(as_uuid=True), nullable=False)
    parentesco             = Column(String(80), nullable=False, default="Familiar")
    prioridad_notificacion = Column(Integer, nullable=False, default=3)
    es_principal           = Column(Boolean, nullable=False, default=False)
    created_at             = Column(DateTime, nullable=False, default=datetime.now)


class EmergencyContactORM(Base):
    """Mapea directamente la vista emergency_contacts para consultas de lectura en PMV2."""
    __tablename__ = "emergency_contacts"

    contact_id             = Column(PG_UUID(as_uuid=True), primary_key=True)
    patient_id             = Column(PG_UUID(as_uuid=True))
    nombre                 = Column(String(150))
    telefono               = Column(String(25))
    relacion               = Column(String(50))
    es_principal           = Column(Boolean)
    prioridad_notificacion = Column(Integer)
    created_at             = Column(DateTime)


class ThresholdORM(Base):
    __tablename__ = "thresholds"

    id                = Column(Integer, primary_key=True, autoincrement=True)
    patient_id        = Column(PG_UUID(as_uuid=True), nullable=False, unique=True)
    bpm_min_normal    = Column(Integer, nullable=False, default=60)
    bpm_max_normal    = Column(Integer, nullable=False, default=100)
    bpm_min_moderate  = Column(Integer, nullable=False, default=50)
    bpm_max_moderate  = Column(Integer, nullable=False, default=130)
    spo2_min_normal   = Column(Integer, nullable=False, default=95)
    spo2_min_moderate = Column(Integer, nullable=False, default=90)
    spo2_min_critical = Column(Integer, nullable=False, default=82)
    updated_at        = Column(DateTime, nullable=False, default=datetime.now)


# ──────────────────────────────────────────────
# Engine Factory
# ──────────────────────────────────────────────

def _make_engine(database_url: str):
    # SQLAlchemy 2.0 no soporta el dialecto "postgres://", requiere obligatoriamente "postgresql://"
    if database_url and database_url.startswith("postgres://"):
        database_url = database_url.replace("postgres://", "postgresql://", 1)

    try:
        engine = create_engine(database_url, pool_pre_ping=True, pool_size=5, max_overflow=10)
        logger.info("✅ PostgreSQL conectado: %s", database_url.split("@")[-1])
        return engine
    except OperationalError as e:
        logger.error("❌ No se pudo conectar a PostgreSQL: %s", e)
        raise RuntimeError(
            f"No se pudo conectar a la base de datos.\n"
            f"Verifica DATABASE_URL en el archivo .env\n"
            f"Error: {e}"
        )



# ──────────────────────────────────────────────
# User / Patient Repository (PMV1 + PMV2)
# ──────────────────────────────────────────────

class PostgresUserRepository(IUserRepository, IPatientRepository):
    def __init__(self, database_url: str):
        self._engine = _make_engine(database_url)
        self._Session = sessionmaker(bind=self._engine)

    # --- Métodos de IUserRepository (PMV1) ---
    def get_by_email(self, email: str) -> Optional[User]:
        with self._Session() as session:
            row = session.query(UserORM).filter(UserORM.email == email).first()
        return self._to_domain(row) if row else None

    def get_by_id(self, user_id: str) -> Optional[User]:
        try:
            user_uuid = uuid.UUID(user_id)
        except ValueError:
            return None
        with self._Session() as session:
            row = session.query(UserORM).filter(UserORM.id == user_uuid).first()
        return self._to_domain(row) if row else None

    def create_user(self, user: User) -> User:
        orm = UserORM(
            id=uuid.UUID(user.id) if user.id else uuid.uuid4(),
            email=user.email,
            hashed_password=user.hashed_password,
            role=user.role.value,
            supervisor_email=user.supervisor_email,
            edad=user.edad,
            peso=user.peso,
            altura=user.altura,
            sexo=user.sexo,
            telefono=user.telefono,
            nombre=user.nombre,
            base_bio_profile=user.base_bio_profile or {},
            created_at=user.created_at or datetime.now(),
        )
        with self._Session() as session:
            session.add(orm)
            session.commit()
            session.refresh(orm)
        user.id = str(orm.id)
        return user

    def get_all(self) -> list[User]:
        with self._Session() as session:
            rows = session.query(UserORM).all()
        return [self._to_domain(r) for r in rows]

    # --- Métodos de IPatientRepository (PMV2) ---
    async def create(self, user: User) -> User:
        return self.create_user(user)

    async def update_bio_profile(self, patient_id: str, profile: dict) -> None:
        try:
            pid = uuid.UUID(patient_id)
        except ValueError:
            return
        with self._Session() as session:
            orm = session.query(UserORM).filter(UserORM.id == pid).first()
            if orm:
                orm.base_bio_profile = profile
                session.commit()

    async def get_patients_by_supervisor(self, supervisor_email: str) -> List[User]:
        with self._Session() as session:
            rows = (
                session.query(UserORM)
                .filter(UserORM.role == "PACIENTE", UserORM.supervisor_email == supervisor_email)
                .all()
            )
        return [self._to_domain(r) for r in rows]

    async def get_contacts(self, patient_id: str, ordered_by_priority: bool = True) -> List[EmergencyContact]:
        try:
            pid = uuid.UUID(patient_id)
        except ValueError:
            return []
        with self._Session() as session:
            q = session.query(EmergencyContactORM).filter(EmergencyContactORM.patient_id == pid)
            if ordered_by_priority:
                q = q.order_by(EmergencyContactORM.prioridad_notificacion.asc())
            rows = q.all()
        return [
            EmergencyContact(
                contact_id=str(row.contact_id),
                patient_id=str(row.patient_id),
                nombre=row.nombre,
                telefono=row.telefono,
                relacion=row.relacion,
                es_principal=row.es_principal,
                prioridad_notificacion=row.prioridad_notificacion,
                created_at=row.created_at
            )
            for row in rows
        ]

    async def add_contact(
        self,
        patient_id:             str,
        contact:                EmergencyContact,
        parentesco:             str = "Familiar",
        prioridad_notificacion: int = 3,
    ) -> EmergencyContact:
        try:
            pid = uuid.UUID(patient_id)
        except ValueError:
            raise ValueError(f"patient_id inválido: {patient_id}")

        with self._Session() as session:
            # Buscar si el contacto ya existe por su teléfono
            c_orm = session.query(ContactORM).filter(ContactORM.telefono == contact.telefono).first()
            if not c_orm:
                c_orm = ContactORM(
                    contact_id=uuid.UUID(contact.contact_id) if contact.contact_id else uuid.uuid4(),
                    nombre=contact.nombre,
                    telefono=contact.telefono,
                    email=None,
                    created_at=contact.created_at or datetime.now()
                )
                session.add(c_orm)
                session.flush()

            contact_id = c_orm.contact_id

            # Determinar si ya es el principal
            existing_count = session.query(PatientContactORM).filter(PatientContactORM.patient_id == pid).count()
            es_principal = (existing_count == 0)

            # Insertar en la tabla asociativa patient_contacts
            pc_orm = session.query(PatientContactORM).filter(
                PatientContactORM.patient_id == pid,
                PatientContactORM.contact_id == contact_id
            ).first()

            if not pc_orm:
                pc_orm = PatientContactORM(
                    id=uuid.uuid4(),
                    patient_id=pid,
                    contact_id=contact_id,
                    parentesco=parentesco,
                    prioridad_notificacion=prioridad_notificacion,
                    es_principal=es_principal
                )
                session.add(pc_orm)
            else:
                pc_orm.parentesco = parentesco
                pc_orm.prioridad_notificacion = prioridad_notificacion
                pc_orm.es_principal = es_principal

            session.commit()

            contact.contact_id = str(contact_id)
            contact.patient_id = patient_id
            contact.relacion = parentesco
            contact.prioridad_notificacion = prioridad_notificacion
            contact.es_principal = es_principal
            return contact

    async def remove_contact(self, patient_id: str, contact_id: str) -> bool:
        try:
            pid = uuid.UUID(patient_id)
            cid = uuid.UUID(contact_id)
        except ValueError:
            return False
        with self._Session() as session:
            pc = session.query(PatientContactORM).filter(
                PatientContactORM.patient_id == pid,
                PatientContactORM.contact_id == cid
            ).first()
            if pc:
                session.delete(pc)
                session.commit()
                return True
        return False

    @staticmethod
    def _to_domain(row: UserORM) -> User:
        return User(
            id=str(row.id),
            email=row.email,
            hashed_password=row.hashed_password,
            role=Role(row.role),
            created_at=row.created_at,
            supervisor_email=row.supervisor_email,
            edad=row.edad,
            peso=row.peso,
            altura=row.altura,
            sexo=row.sexo,
            telefono=row.telefono,
            nombre=row.nombre,
            base_bio_profile=row.base_bio_profile
        )


# ──────────────────────────────────────────────
# Signal (Biometric) Repository (PMV1 + PMV2)
# ──────────────────────────────────────────────

class PostgresSignalRepository(ISignalRepository, IBiometricSignalRepository):
    def __init__(self, database_url: str):
        self._engine = _make_engine(database_url)
        self._Session = sessionmaker(bind=self._engine)

    def test_connection(self) -> dict:
        with self._Session() as session:
            result = session.execute(text("SELECT version();")).scalar()
            return {"db_version": str(result)}

    # --- Métodos de ISignalRepository (PMV1) ---
    def save_reading(self, reading: BiometricReading) -> None:
        patient_id_raw = getattr(reading, "patient_id", None)
        if not patient_id_raw:
            return
        with self._Session() as session:
            record = BiometricSignalORM(
                time=reading.timestamp or datetime.utcnow(),
                device_id=uuid.uuid4(),
                patient_id=uuid.UUID(patient_id_raw),
                session_token=None,
                heart_rate=reading.bpm,
                spo2=int(reading.spo2),
                resp_rate=None,
                status_movement="UNKNOWN",
                source="simulator"
            )
            session.add(record)
            session.commit()

    def save(self, patient_id: str, reading: BiometricReading) -> None:
        reading.patient_id = patient_id
        self.save_reading(reading)

    # --- Métodos de IBiometricSignalRepository (PMV2) ---
    async def ingest(self, signal: BiometricSignal) -> None:
        with self._Session() as session:
            record = BiometricSignalORM(
                time=signal.time,
                device_id=uuid.UUID(signal.device_id) if signal.device_id else uuid.uuid4(),
                patient_id=uuid.UUID(signal.patient_id),
                session_token=signal.session_token,
                heart_rate=signal.heart_rate,
                spo2=signal.spo2,
                resp_rate=signal.resp_rate,
                status_movement=signal.status_movement.value if hasattr(signal.status_movement, 'value') else str(signal.status_movement),
                source=signal.source
            )
            session.add(record)
            session.commit()

    async def ingest_batch(self, signals: Sequence[BiometricSignal]) -> int:
        with self._Session() as session:
            count = 0
            for signal in signals:
                record = BiometricSignalORM(
                    time=signal.time,
                    device_id=uuid.UUID(signal.device_id) if signal.device_id else uuid.uuid4(),
                    patient_id=uuid.UUID(signal.patient_id),
                    session_token=signal.session_token,
                    heart_rate=signal.heart_rate,
                    spo2=signal.spo2,
                    resp_rate=signal.resp_rate,
                    status_movement=signal.status_movement.value if hasattr(signal.status_movement, 'value') else str(signal.status_movement),
                    source=signal.source
                )
                session.add(record)
                count += 1
            session.commit()
            return count

    async def get_latest(self, patient_id: str) -> Optional[BiometricSignal]:
        try:
            pid = uuid.UUID(patient_id)
        except ValueError:
            return None
        with self._Session() as session:
            row = (
                session.query(BiometricSignalORM)
                .filter(BiometricSignalORM.patient_id == pid)
                .order_by(BiometricSignalORM.time.desc())
                .first()
            )
        return self._to_domain(row) if row else None

    async def get_history(
        self,
        patient_id: str,
        limit: int = 50,
        *,
        from_ts: Optional[datetime] = None,
        to_ts: Optional[datetime] = None,
    ) -> List[BiometricSignal]:
        try:
            pid = uuid.UUID(patient_id)
        except ValueError:
            return []
        with self._Session() as session:
            q = session.query(BiometricSignalORM).filter(BiometricSignalORM.patient_id == pid)
            if from_ts:
                q = q.filter(BiometricSignalORM.time >= from_ts)
            if to_ts:
                q = q.filter(BiometricSignalORM.time <= to_ts)
            rows = q.order_by(BiometricSignalORM.time.desc()).limit(limit).all()
        return [self._to_domain(r) for r in reversed(rows)]

    async def get_moving_average(
        self,
        patient_id: str,
        window_minutes: int = 5,
    ) -> Tuple[Optional[float], Optional[float]]:
        try:
            pid = uuid.UUID(patient_id)
        except ValueError:
            return None, None
        cutoff = datetime.utcnow() - timedelta(minutes=window_minutes)
        with self._Session() as session:
            rows = (
                session.query(BiometricSignalORM)
                .filter(BiometricSignalORM.patient_id == pid, BiometricSignalORM.time >= cutoff)
                .all()
            )
            if not rows:
                # Fallback al último registro
                last = (
                    session.query(BiometricSignalORM)
                    .filter(BiometricSignalORM.patient_id == pid)
                    .order_by(BiometricSignalORM.time.desc())
                    .first()
                )
                if last:
                    return float(last.spo2), float(last.heart_rate)
                return None, None

            spo2_avg = sum(r.spo2 for r in rows) / len(rows)
            bpm_avg = sum(r.heart_rate for r in rows) / len(rows)
            return spo2_avg, bpm_avg

    @staticmethod
    def _to_domain(row: BiometricSignalORM) -> BiometricSignal:
        return BiometricSignal(
            time=row.time,
            device_id=str(row.device_id),
            patient_id=str(row.patient_id),
            heart_rate=row.heart_rate,
            spo2=row.spo2,
            resp_rate=row.resp_rate,
            status_movement=MovementStatus(row.status_movement) if row.status_movement else MovementStatus.UNKNOWN,
            session_token=row.session_token,
            source=row.source or "iot"
        )


# ──────────────────────────────────────────────
# IoT Session Repository (PMV2)
# ──────────────────────────────────────────────

class PostgresIoTSessionRepository(IIoTSessionRepository):
    def __init__(self, database_url: str):
        self._engine = _make_engine(database_url)
        self._Session = sessionmaker(bind=self._engine)

    async def create_session(self, session: IoTSession) -> IoTSession:
        orm = IoTSessionORM(
            session_token=session.session_token,
            patient_id=uuid.UUID(session.patient_id),
            stream_status=session.stream_status.value,
            last_heartbeat=session.last_heartbeat,
            created_at=session.created_at or datetime.now(),
            expires_at=session.expires_at
        )
        with self._Session() as db_session:
            db_session.add(orm)
            db_session.commit()
            db_session.refresh(orm)
        return self._to_domain(orm)

    async def get_by_token(self, token: str) -> Optional[IoTSession]:
        with self._Session() as db_session:
            row = db_session.query(IoTSessionORM).filter(IoTSessionORM.session_token == token).first()
        return self._to_domain(row) if row else None

    async def get_active_session(self, patient_id: str) -> Optional[IoTSession]:
        try:
            pid = uuid.UUID(patient_id)
        except ValueError:
            return None
        now = datetime.utcnow()
        with self._Session() as db_session:
            row = (
                db_session.query(IoTSessionORM)
                .filter(
                    IoTSessionORM.patient_id == pid,
                    IoTSessionORM.expires_at > now,
                    IoTSessionORM.stream_status == "CONNECTED"
                )
                .order_by(IoTSessionORM.created_at.desc())
                .first()
            )
            if not row:
                # Si no hay conectado, buscar el más reciente no expirado
                row = (
                    db_session.query(IoTSessionORM)
                    .filter(
                        IoTSessionORM.patient_id == pid,
                        IoTSessionORM.expires_at > now
                    )
                    .order_by(IoTSessionORM.created_at.desc())
                    .first()
                )
        return self._to_domain(row) if row else None

    async def update_status(self, token: str, status: IoTStreamStatus, heartbeat: bool = False) -> None:
        with self._Session() as db_session:
            row = db_session.query(IoTSessionORM).filter(IoTSessionORM.session_token == token).first()
            if row:
                row.stream_status = status.value
                if heartbeat:
                    row.last_heartbeat = datetime.utcnow()
                db_session.commit()

    async def is_patient_online(self, patient_id: str) -> bool:
        try:
            pid = uuid.UUID(patient_id)
        except ValueError:
            return False
        now = datetime.utcnow()
        # Se considera online si tiene latidos en los últimos 30 segundos y la sesión no ha expirado
        cutoff = now - timedelta(seconds=30)
        with self._Session() as db_session:
            row = (
                db_session.query(IoTSessionORM)
                .filter(
                    IoTSessionORM.patient_id == pid,
                    IoTSessionORM.stream_status == "CONNECTED",
                    IoTSessionORM.expires_at > now,
                    IoTSessionORM.last_heartbeat >= cutoff
                )
                .first()
            )
        return row is not None

    @staticmethod
    def _to_domain(row: IoTSessionORM) -> IoTSession:
        return IoTSession(
            session_token=row.session_token,
            patient_id=str(row.patient_id),
            stream_status=IoTStreamStatus(row.stream_status),
            last_heartbeat=row.last_heartbeat,
            created_at=row.created_at,
            expires_at=row.expires_at
        )


# ──────────────────────────────────────────────
# Risk Event Repository
# ──────────────────────────────────────────────

class PostgresRiskRepository(IRiskRepository):
    def __init__(self, database_url: str):
        self._engine = _make_engine(database_url)
        self._Session = sessionmaker(bind=self._engine)

    def save(self, event: RiskEvent) -> RiskEvent:
        with self._Session() as session:
            orm = RiskEventORM(
                event_id=uuid.UUID(event.event_id) if event.event_id else uuid.uuid4(),
                patient_id=uuid.UUID(event.patient_id),
                detected_at=event.detected_at or datetime.utcnow(),
                risk_level=event.risk_level.value,
                probability=event.probability,
                spo2_at_event=int(event.spo2_at_event),
                bpm_at_event=int(event.bpm_at_event),
                resp_rate_at_event=getattr(event, 'resp_rate_at_event', None),
                movement_at_event=getattr(event, 'movement_at_event', 'UNKNOWN'),
                alert_sent=event.alert_sent,
                sma_spo2=getattr(event, 'sma_spo2', None),
                sma_bpm=getattr(event, 'sma_bpm', None)
            )
            session.add(orm)
            session.commit()
            session.refresh(orm)
            event.event_id = str(orm.event_id)
        return event

    def get_history(self, patient_id: str, limit: int = 50) -> List[RiskEvent]:
        with self._Session() as session:
            try:
                patient_uuid = uuid.UUID(patient_id)
            except ValueError:
                return []
            rows = (
                session.query(RiskEventORM)
                .filter(RiskEventORM.patient_id == patient_uuid)
                .order_by(RiskEventORM.detected_at.desc())
                .limit(limit)
                .all()
            )
        result = []
        for row in rows:
            ev = RiskEvent(
                event_id=str(row.event_id),
                patient_id=str(row.patient_id),
                detected_at=row.detected_at,
                risk_level=RiskLevel(row.risk_level),
                probability=row.probability,
                spo2_at_event=row.spo2_at_event,
                bpm_at_event=row.bpm_at_event,
                activity_at_event=0,
                alert_sent=row.alert_sent,
            )
            # Agregar atributos dinámicos de PMV2
            ev.resp_rate_at_event = row.resp_rate_at_event
            ev.movement_at_event = row.movement_at_event
            ev.sma_spo2 = row.sma_spo2
            ev.sma_bpm = row.sma_bpm
            result.append(ev)
        return result
