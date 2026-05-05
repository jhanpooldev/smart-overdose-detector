"""
postgres_repository.py — Repositorios PostgreSQL para todos los puertos del dominio.

Implementa:
  - IUserRepository
  - ISignalRepository
  - IRiskRepository
  - IContactRepository (referenciado por contacts_controller)

Usa SQLAlchemy con conexión directa a TimescaleDB/PostgreSQL.
"""
from datetime import datetime
from typing import List, Optional
import logging
import uuid

from sqlalchemy import (
    create_engine, text,
    Column, Float, Integer, String, DateTime, Boolean, Text
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import declarative_base, sessionmaker
from sqlalchemy.exc import OperationalError

from src.domain.entities.biometric_reading import BiometricReading
from src.domain.entities.user import User, Role
from src.domain.entities.risk_event import RiskEvent, RiskLevel
from src.domain.entities.emergency_contact import EmergencyContact
from src.domain.ports.i_signal_repository import ISignalRepository
from src.domain.ports.i_user_repository import IUserRepository
from src.domain.ports.i_risk_repository import IRiskRepository

logger = logging.getLogger(__name__)
Base = declarative_base()


# ──────────────────────────────────────────────
# ORM Models
# ──────────────────────────────────────────────

class UserORM(Base):
    __tablename__ = "users"

    id               = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email            = Column(String(255), nullable=False, unique=True)
    hashed_password  = Column(String(255), nullable=False)
    role             = Column(String(20), nullable=False)
    supervisor_email = Column(String(255), nullable=True)
    edad             = Column(Integer, nullable=True)
    peso             = Column(Float, nullable=True)
    altura           = Column(Float, nullable=True)
    sexo             = Column(String(20), nullable=True)
    telefono         = Column(String(50), nullable=True)
    created_at       = Column(DateTime, nullable=False, default=datetime.now)


class BiometricSignalORM(Base):
    __tablename__ = "biometric_signals"

    signal_time = Column(DateTime, nullable=False, primary_key=True, default=datetime.now)
    patient_id  = Column(PG_UUID(as_uuid=True), nullable=False, primary_key=True)
    spo2        = Column(Float, nullable=False)
    bpm         = Column(Integer, nullable=False)
    activity    = Column(Integer, nullable=False, default=0)
    source      = Column(String(20), default="sensor")


class RiskEventORM(Base):
    __tablename__ = "risk_events"

    event_id          = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    patient_id        = Column(PG_UUID(as_uuid=True), nullable=False)
    detected_at       = Column(DateTime, nullable=False, default=datetime.now)
    risk_level        = Column(String(20), nullable=False)
    probability       = Column(Float, nullable=False, default=0.0)
    spo2_at_event     = Column(Float, nullable=False)
    bpm_at_event      = Column(Integer, nullable=False)
    activity_at_event = Column(Integer, nullable=False, default=0)
    alert_sent        = Column(Boolean, nullable=False, default=False)


class EmergencyContactORM(Base):
    __tablename__ = "emergency_contacts"

    contact_id   = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    patient_id   = Column(PG_UUID(as_uuid=True), nullable=False)
    nombre       = Column(String(150), nullable=False)
    telefono     = Column(String(20), nullable=False)
    relacion     = Column(String(50), nullable=False, default="Familiar")
    es_principal = Column(Boolean, nullable=False, default=False)
    created_at   = Column(DateTime, nullable=False, default=datetime.now)


# ──────────────────────────────────────────────
# Engine Factory (shared)
# ──────────────────────────────────────────────

def _make_engine(database_url: str):
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
# User Repository
# ──────────────────────────────────────────────

class PostgresUserRepository(IUserRepository):
    def __init__(self, database_url: str):
        self._engine = _make_engine(database_url)
        self._Session = sessionmaker(bind=self._engine)

    def get_by_email(self, email: str) -> Optional[User]:
        with self._Session() as session:
            row = session.query(UserORM).filter(UserORM.email == email).first()
        return self._to_domain(row) if row else None

    def get_by_id(self, user_id: str) -> Optional[User]:
        with self._Session() as session:
            row = session.query(UserORM).filter(UserORM.id == uuid.UUID(user_id)).first()
        return self._to_domain(row) if row else None

    def get_all(self) -> list[User]:
        with self._Session() as session:
            rows = session.query(UserORM).all()
        return [self._to_domain(r) for r in rows]

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
            created_at=user.created_at,
        )
        with self._Session() as session:
            session.add(orm)
            session.commit()
            session.refresh(orm)
        user.id = str(orm.id)
        return user

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
        )


# ──────────────────────────────────────────────
# Signal (Biometric) Repository
# ──────────────────────────────────────────────

class PostgresSignalRepository(ISignalRepository):
    def __init__(self, database_url: str):
        self._engine = _make_engine(database_url)
        self._Session = sessionmaker(bind=self._engine)

    def save_reading(self, reading: BiometricReading) -> None:
        patient_id_raw = getattr(reading, "patient_id", None)
        if not patient_id_raw:
            logger.warning("save_reading: lectura sin patient_id, ignorada")
            return
        with self._Session() as session:
            record = BiometricSignalORM(
                signal_time=reading.timestamp,
                patient_id=uuid.UUID(patient_id_raw),
                spo2=reading.spo2,
                bpm=reading.bpm,
                activity=reading.activity,
                source="simulator",
            )
            session.add(record)
            session.commit()

    def save(self, patient_id: str, reading: BiometricReading) -> None:
        """Alias compatible con el endpoint POST /api/v1/readings."""
        reading.patient_id = patient_id  # type: ignore[attr-defined]
        self.save_reading(reading)

    def get_history(self, patient_id: str, limit: int = 50) -> List[BiometricReading]:
        with self._Session() as session:
            try:
                patient_uuid = uuid.UUID(patient_id)
            except ValueError:
                return []
            rows = (
                session.query(BiometricSignalORM)
                .filter(BiometricSignalORM.patient_id == patient_uuid)
                .order_by(BiometricSignalORM.signal_time.desc())
                .limit(limit)
                .all()
            )
        result = []
        for row in reversed(rows):
            r = BiometricReading(spo2=row.spo2, bpm=row.bpm, activity=row.activity, timestamp=row.signal_time)
            r.patient_id = str(row.patient_id)  # type: ignore[attr-defined]
            result.append(r)
        return result

    def test_connection(self) -> dict:
        with self._Session() as session:
            result = session.execute(text("SELECT version()")).scalar()
        return {"db_version": result, "status": "connected"}


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
                detected_at=event.detected_at,
                risk_level=event.risk_level.value,
                probability=event.probability,
                spo2_at_event=event.spo2_at_event,
                bpm_at_event=event.bpm_at_event,
                activity_at_event=event.activity_at_event,
                alert_sent=event.alert_sent,
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
        return [
            RiskEvent(
                event_id=str(row.event_id),
                patient_id=str(row.patient_id),
                detected_at=row.detected_at,
                risk_level=RiskLevel(row.risk_level),
                probability=row.probability,
                spo2_at_event=row.spo2_at_event,
                bpm_at_event=row.bpm_at_event,
                activity_at_event=row.activity_at_event,
                alert_sent=row.alert_sent,
            )
            for row in rows
        ]
