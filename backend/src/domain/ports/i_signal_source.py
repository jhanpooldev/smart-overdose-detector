from typing import Protocol, Literal
from src.domain.entities.biometric_reading import BiometricReading

class ISignalSource(Protocol):
    def generate_reading(
        self, patient_id: str, scenario: Literal["normal", "moderate", "critical"]
    ) -> BiometricReading:
        ...
