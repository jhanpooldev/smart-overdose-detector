from dataclasses import dataclass
from datetime import datetime

@dataclass
class BiometricReading:
    spo2: float
    bpm: int
    activity: int
    timestamp: datetime
