from typing import List
from src.domain.entities.risk_event import RiskEvent
from src.domain.ports.i_risk_repository import IRiskRepository

class InMemoryRiskRepository(IRiskRepository):
    def __init__(self):
        self._events: List[RiskEvent] = []

    def save(self, event: RiskEvent) -> RiskEvent:
        self._events.insert(0, event)  # Guardar al inicio para que el historial sea descendente
        return event

    def get_history(self, patient_id: str, limit: int = 50) -> List[RiskEvent]:
        # Filtrar por paciente y limitar resultados
        filtered = [e for e in self._events if e.patient_id == patient_id]
        return filtered[:limit]
