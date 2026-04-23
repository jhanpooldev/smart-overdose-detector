from dataclasses import dataclass


@dataclass(frozen=True)
class BiometricFeatures:
    """Value Object — Vector de entrada al modelo de IA."""
    spo2: float        # SpO2 en porcentaje (70.0 – 100.0)
    bpm: int           # Frecuencia cardíaca (30 – 180)
    activity: int      # 0 = inmovilidad, 1 = activo

    def __post_init__(self):
        if not (70.0 <= self.spo2 <= 100.0):
            raise ValueError(f"SpO2 fuera de rango clínico: {self.spo2}")
        if not (30 <= self.bpm <= 180):
            raise ValueError(f"BPM fuera de rango clínico: {self.bpm}")
        if self.activity not in (0, 1):
            raise ValueError(f"Nivel de actividad inválido: {self.activity}")

    def to_vector(self) -> list[float]:
        return [self.spo2, float(self.bpm), float(self.activity)]
