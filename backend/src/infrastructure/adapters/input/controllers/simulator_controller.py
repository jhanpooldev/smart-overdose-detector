from fastapi import APIRouter, HTTPException, Query
from typing import Literal
from pydantic import BaseModel
from datetime import datetime

from src.infrastructure.adapters.input.simulators.simulated_data_generator import SimulatedDataGenerator

router = APIRouter(prefix="/api/v1/simulate", tags=["Simulator"])
simulator = SimulatedDataGenerator()

class BiometricReadingResponse(BaseModel):
    spo2: float
    bpm: int
    activity: int
    timestamp: datetime
    patient_id: str

@router.get("/reading", response_model=BiometricReadingResponse)
def get_simulated_reading(
    patient_id: str = Query("PAT-001", description="ID del paciente"),
    scenario: Literal["normal", "moderate", "critical"] = Query("normal", description="Escenario clínico a simular")
):
    try:
        reading = simulator.generate_reading(patient_id, scenario)
        return BiometricReadingResponse(
            spo2=reading.spo2,
            bpm=reading.bpm,
            activity=reading.activity,
            timestamp=reading.timestamp,
            patient_id=patient_id
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
