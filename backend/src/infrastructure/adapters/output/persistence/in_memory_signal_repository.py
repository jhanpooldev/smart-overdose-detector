"""
InMemorySignalRepository — Repositorio en memoria compatible con PMV1 (ISignalRepository) y PMV2 (IBiometricSignalRepository).
"""
from collections import defaultdict
from typing import List, Optional, Sequence, Tuple
from datetime import datetime, timedelta
from src.domain.entities.biometric_reading import BiometricReading
from src.domain.entities.biometric_signal import BiometricSignal, MovementStatus
from src.domain.ports.i_signal_repository import ISignalRepository
from src.application.ports.output_ports import IBiometricSignalRepository


class InMemorySignalRepository(ISignalRepository, IBiometricSignalRepository):
    """Adaptador de persistencia temporal en memoria para PMV1 y PMV2."""

    def __init__(self):
        self._readings: dict[str, list[BiometricReading]] = defaultdict(list)
        self._signals: dict[str, list[BiometricSignal]] = defaultdict(list)

    # --- Métodos de PMV1 (ISignalRepository) ---
    def save_reading(self, reading: BiometricReading) -> None:
        patient_id = getattr(reading, "patient_id", "unknown")
        self._readings[patient_id].append(reading)
        if len(self._readings[patient_id]) > 1000:
            self._readings[patient_id] = self._readings[patient_id][-1000:]

    def save(self, patient_id: str, reading: BiometricReading) -> None:
        self.save_reading(reading)

    # --- Métodos de PMV2 (IBiometricSignalRepository) ---
    async def ingest(self, signal: BiometricSignal) -> None:
        patient_id = signal.patient_id
        self._signals[patient_id].append(signal)
        if len(self._signals[patient_id]) > 1000:
            self._signals[patient_id] = self._signals[patient_id][-1000:]

    async def ingest_batch(self, signals: Sequence[BiometricSignal]) -> int:
        count = 0
        for s in signals:
            await self.ingest(s)
            count += 1
        return count

    async def get_latest(self, patient_id: str) -> Optional[BiometricSignal]:
        signals = self._signals.get(patient_id, [])
        if signals:
            return signals[-1]
        return None

    # --- Método unificado get_history ---
    async def get_history(
        self,
        patient_id: str,
        limit: int = 50,
        *,
        from_ts: Optional[datetime] = None,
        to_ts: Optional[datetime] = None,
    ) -> List[BiometricSignal]:
        # Para compatibilidad con PMV1/tests, si no se pide rango y hay lecturas de PMV1,
        # retornamos esas lecturas convertidas a BiometricSignal.
        signals = self._signals.get(patient_id, [])
        
        # Filtrar por rango si se especifica
        filtered = []
        for s in signals:
            if from_ts and s.time < from_ts:
                continue
            if to_ts and s.time > to_ts:
                continue
            filtered.append(s)

        # Si no hay señales PMV2 pero sí lecturas PMV1, las convertimos para mantener compatibilidad
        if not filtered and patient_id in self._readings:
            readings = self._readings[patient_id]
            for r in readings:
                filtered.append(
                    BiometricSignal(
                        time=r.timestamp,
                        device_id="sim-device",
                        patient_id=patient_id,
                        heart_rate=r.bpm,
                        spo2=int(r.spo2),
                        status_movement=MovementStatus.UNKNOWN,
                        resp_rate=None,
                        session_token=None,
                        source="simulator"
                    )
                )

        return filtered[-limit:]

    async def get_moving_average(
        self,
        patient_id: str,
        window_minutes: int = 5,
    ) -> Tuple[Optional[float], Optional[float]]:
        signals = self._signals.get(patient_id, [])
        if not signals:
            return None, None
        
        now = datetime.utcnow()
        cutoff = now - timedelta(minutes=window_minutes)
        window_signals = [s for s in signals if s.time >= cutoff]
        
        if not window_signals:
            # Fallback al último elemento si no hay en la ventana estricta
            last = signals[-1]
            return float(last.spo2), float(last.heart_rate)

        spo2_avg = sum(s.spo2 for s in window_signals) / len(window_signals)
        bpm_avg = sum(s.heart_rate for s in window_signals) / len(window_signals)
        return spo2_avg, bpm_avg
