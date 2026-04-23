from typing import Protocol, List
from src.domain.entities.biometric_reading import BiometricReading


class ISignalRepository(Protocol):
    """Puerto de salida — Persistencia de lecturas biométricas."""

    def save_reading(self, reading: BiometricReading) -> None: ...

    def get_history(self, patient_id: str, limit: int = 50) -> List[BiometricReading]: ...
