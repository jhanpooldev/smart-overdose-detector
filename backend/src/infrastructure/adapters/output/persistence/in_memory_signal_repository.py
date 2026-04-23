"""
InMemorySignalRepository — Adaptador de persistencia en memoria para PMV1/testing.
Implementa el puerto ISignalRepository sin base de datos real.
"""
from collections import defaultdict
from typing import List
from src.domain.entities.biometric_reading import BiometricReading
from src.domain.ports.i_signal_repository import ISignalRepository


class InMemorySignalRepository(ISignalRepository):
    """Adaptador de persistencia temporal. Se sustituirá por TimescaleDB en PMV2."""

    def __init__(self):
        self._store: dict[str, list[BiometricReading]] = defaultdict(list)

    def save_reading(self, reading: BiometricReading) -> None:
        patient_id = getattr(reading, "patient_id", "unknown")
        self._store[patient_id].append(reading)
        # Mantener solo las últimas 1000 lecturas por paciente (ventana temporal)
        if len(self._store[patient_id]) > 1000:
            self._store[patient_id] = self._store[patient_id][-1000:]

    def get_history(self, patient_id: str, limit: int = 50) -> List[BiometricReading]:
        readings = self._store.get(patient_id, [])
        return readings[-limit:]
