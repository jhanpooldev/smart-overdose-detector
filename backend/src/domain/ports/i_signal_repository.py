from typing import Protocol, List, Any
from src.domain.entities.biometric_reading import BiometricReading


class ISignalRepository(Protocol):
    """Puerto de salida — Persistencia de lecturas biométricas."""

    def save_reading(self, reading: BiometricReading) -> None: ...

    def save(self, patient_id: str, reading: BiometricReading) -> None: ...

    async def get_history(self, patient_id: str, limit: int = 50) -> List[Any]: ...
