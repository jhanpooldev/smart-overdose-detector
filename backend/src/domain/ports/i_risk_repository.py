from typing import Protocol, List
from src.domain.entities.risk_event import RiskEvent

class IRiskRepository(Protocol):
    """Puerto de salida — Persistencia de eventos de riesgo."""

    def save(self, event: RiskEvent) -> RiskEvent: ...

    def get_history(self, patient_id: str, limit: int = 50) -> List[RiskEvent]: ...
