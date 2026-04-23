"""
trabajo_db_signal_repository.py — Adaptador de persistencia mapeado al esquema real
del archivo trabajo.sql (PostgreSQL 18.3 local del equipo).

Mapea los nombres de columna reales:
  - biometric_signals.heart_rate  → BiometricReading.bpm
  - biometric_signals.time        → BiometricReading.timestamp
  - biometric_signals.resp_rate   → ignorado (no en dominio aún)
  - patient_id via devices        → lookup por device_id
"""
from datetime import datetime
from typing import List
import logging

from sqlalchemy import create_engine, text, Column, Float, Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import declarative_base, sessionmaker

from src.domain.entities.biometric_reading import BiometricReading
from src.domain.ports.i_signal_repository import ISignalRepository

logger = logging.getLogger(__name__)
Base = declarative_base()


class BiometricSignalORM(Base):
    """Refleja la tabla biometric_signals del archivo trabajo.sql."""
    __tablename__ = "biometric_signals"
    __table_args__ = {"schema": "public"}

    signal_id  = Column(Integer, primary_key=True, autoincrement=True)
    device_id  = Column(Integer, ForeignKey("public.devices.device_id"), nullable=True)
    time       = Column(DateTime, nullable=False, default=datetime.now)
    heart_rate = Column(Integer, nullable=True)   # equivale a bpm
    spo2       = Column(Float, nullable=True)
    resp_rate  = Column(Integer, nullable=True)   # no usado en dominio aún


class TrabajoDBSignalRepository(ISignalRepository):
    """
    Repositorio que conecta con el esquema real de trabajo.sql.
    Compatible con PostgreSQL 18.x local del equipo.
    """

    # device_id por defecto = 1 (el Smartwatch Samsung del dump)
    DEFAULT_DEVICE_ID = 1

    def __init__(self, database_url: str):
        try:
            self._engine = create_engine(database_url, pool_pre_ping=True)
            self._Session = sessionmaker(bind=self._engine)
            logger.info("✅ Conectado a la BD del trabajo: %s", database_url.split("@")[-1])
        except Exception as e:
            logger.error("❌ Error conectando a PostgreSQL: %s", e)
            raise RuntimeError(str(e))

    def save_reading(self, reading: BiometricReading) -> None:
        """Guarda la lectura en biometric_signals usando la estructura real del dump."""
        with self._Session() as session:
            record = BiometricSignalORM(
                device_id=self.DEFAULT_DEVICE_ID,
                time=reading.timestamp,
                heart_rate=reading.bpm,         # bpm → heart_rate
                spo2=reading.spo2,
                resp_rate=None,                  # no tenemos tasa respiratoria aún
            )
            session.add(record)
            session.commit()

    def get_history(self, patient_id: str, limit: int = 50) -> List[BiometricReading]:
        """
        Retorna historial filtrando por device_id vinculado al paciente.
        Por ahora usa device_id=1 (el dispositivo del paciente Juan Perez).
        """
        with self._Session() as session:
            rows = (
                session.query(BiometricSignalORM)
                .filter(BiometricSignalORM.device_id == self.DEFAULT_DEVICE_ID)
                .order_by(BiometricSignalORM.time.desc())
                .limit(limit)
                .all()
            )
        return [
            BiometricReading(
                spo2=float(row.spo2 or 0),
                bpm=int(row.heart_rate or 0),   # heart_rate → bpm
                activity=1,                      # no hay campo en la tabla aún
                timestamp=row.time or datetime.now(),
            )
            for row in reversed(rows)
        ]

    def test_connection(self) -> dict:
        """Verifica la conexión y cuenta los registros existentes."""
        with self._Session() as session:
            version = session.execute(text("SELECT version()")).scalar()
            count = session.execute(
                text("SELECT COUNT(*) FROM public.biometric_signals")
            ).scalar()
        return {
            "db_version": version,
            "status": "connected",
            "biometric_records": count,
        }
