import random
import datetime
from typing import Literal
from src.domain.entities.biometric_reading import BiometricReading
from src.domain.ports.i_signal_source import ISignalSource

class SimulatedDataGenerator(ISignalSource):
    """Implementa el ISignalSource port para casos de simulación controlada."""
    
    def generate_reading(
        self, patient_id: str, scenario: Literal["normal", "moderate", "critical"]
    ) -> BiometricReading:
        now = datetime.datetime.now()
        
        if scenario == "normal":
            spo2 = random.uniform(95.0, 100.0)
            bpm = random.randint(60, 100)
            activity = 1
        elif scenario == "moderate":
            spo2 = random.uniform(90.0, 94.9)
            bpm = random.randint(50, 60)
            activity = random.choice([0, 1])
        elif scenario == "critical":
            spo2 = random.uniform(70.0, 81.9)
            bpm = random.randint(30, 49)
            activity = 0
        else:
            raise ValueError(f"Unknown scenario: {scenario}")
            
        return BiometricReading(
            spo2=round(spo2, 1),
            bpm=bpm,
            activity=activity,
            timestamp=now
        )
