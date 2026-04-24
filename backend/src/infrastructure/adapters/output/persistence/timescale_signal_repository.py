"""
timescale_signal_repository.py — Adaptador de persistencia real para PostgreSQL / TimescaleDB.

Implementa el puerto ISignalRepository.
Funciona con cualquier PostgreSQL (local, Supabase, Neon, Docker, etc.).
No requiere TimescaleDB activo — funciona también con PostgreSQL simple.
"""
from datetime import datetime
from typing import List
import logging

from sqlalchemy import create_engine, text, Column, Float, Integer, String, DateTime
from sqlalchemy.orm import declarative_base, Session, sessionmaker
from sqlalchemy.exc import OperationalError

from src.domain.entities.biometric_reading import BiometricReading
from src.domain.ports.i_signal_repository import ISignalRepository

logger = logging.getLogger(__name__)
Base = declarative_base()


class BiometricSignalORM(Base):
    """Modelo SQLAlchemy para la tabla biometric_signals."""
    __tablename__ = "biometric_signals_simple"

    id          = Column(Integer, primary_key=True, autoincrement=True)
    signal_time = Column(DateTime, nullable=False, default=datetime.now)
    patient_id  = Column(String(50), nullable=False, index=True)
    spo2        = Column(Float, nullable=False)
    bpm         = Column(Integer, nullable=False)
    activity    = Column(Integer, nullable=False)
    source      = Column(String(20), default="simulator")


class TimescaleSignalRepository(ISignalRepository):
    """
    Repositorio de persistencia para PostgreSQL.
    Para PMV2: se puede conectar a la hipertabla TimescaleDB 'biometric_signals'.
    Para PMV1: usa una tabla simple compatible con cualquier PostgreSQL.
    """

    def __init__(self, database_url: str):
        try:
            self._engine = create_engine(database_url, pool_pre_ping=True)
            Base.metadata.create_all(self._engine)  # Crea la tabla si no existe
            self._Session = sessionmaker(bind=self._engine)
            logger.info("✅ PostgreSQL conectado correctamente: %s", database_url.split("@")[-1])
        except OperationalError as e:
            logger.error("❌ No se pudo conectar a PostgreSQL: %s", e)
            raise RuntimeError(
                f"No se pudo conectar a la base de datos.\n"
                f"Verifica tu DATABASE_URL en el archivo .env\n"
                f"Error: {e}"
            )

    def save_reading(self, reading: BiometricReading) -> None:
        patient_id = getattr(reading, "patient_id", "unknown")
        with self._Session() as session:
            record = BiometricSignalORM(
                signal_time=reading.timestamp,
                patient_id=patient_id,
                spo2=reading.spo2,
                bpm=reading.bpm,
                activity=reading.activity,
                source="simulator",
            )
            session.add(record)
            session.commit()

    def get_history(self, patient_id: str, limit: int = 50) -> List[BiometricReading]:
        with self._Session() as session:
            rows = (
                session.query(BiometricSignalORM)
                .filter(BiometricSignalORM.patient_id == patient_id)
                .order_by(BiometricSignalORM.signal_time.desc())
                .limit(limit)
                .all()
            )
        return [
            BiometricReading(
                spo2=row.spo2,
                bpm=row.bpm,
                activity=row.activity,
                timestamp=row.signal_time,
            )
            for row in reversed(rows)
        ]

    def test_connection(self) -> dict:
        """Verifica la conexión y retorna info del servidor."""
        with self._Session() as session:
            result = session.execute(text("SELECT version()")).scalar()
        return {"db_version": result, "status": "connected"}
