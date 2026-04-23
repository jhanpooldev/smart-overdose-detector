"""
tests/test_simulator_endpoint.py — Pruebas de integración del endpoint /api/v1/simulate/reading.

Usa TestClient de FastAPI para verificar la respuesta sin servidor real.
"""
import pytest
from fastapi.testclient import TestClient
from src.main import app

client = TestClient(app)


class TestSimulatorEndpoint:

    def test_health_check(self):
        """El endpoint raíz debe retornar status: ok."""
        response = client.get("/")
        assert response.status_code == 200
        assert response.json()["status"] == "ok"

    def test_simulate_normal_returns_200(self):
        """GET /api/v1/simulate/reading?scenario=normal → 200 OK."""
        response = client.get("/api/v1/simulate/reading?scenario=normal&patient_id=PAT-001")
        assert response.status_code == 200
        data = response.json()
        assert "spo2" in data
        assert "bpm" in data
        assert "activity" in data

    def test_simulate_critical_spo2_below_82(self):
        """Escenario crítico → SpO2 < 82%."""
        for _ in range(20):
            response = client.get("/api/v1/simulate/reading?scenario=critical&patient_id=PAT-TEST")
            assert response.status_code == 200
            assert response.json()["spo2"] < 82.0

    def test_simulate_critical_bpm_below_50(self):
        """Escenario crítico → BPM < 50."""
        for _ in range(20):
            response = client.get("/api/v1/simulate/reading?scenario=critical&patient_id=PAT-TEST")
            assert response.status_code == 200
            assert response.json()["bpm"] < 50

    def test_evaluate_critical_returns_critical_risk(self):
        """POST /api/v1/evaluate?scenario=critical → risk_level = CRITICAL."""
        response = client.post("/api/v1/evaluate?scenario=critical&patient_id=PAT-001")
        assert response.status_code == 200
        data = response.json()
        assert data["risk_level"] == "CRITICAL"
        assert data["probability"] >= 0.7

    def test_evaluate_normal_returns_normal_risk(self):
        """POST /api/v1/evaluate?scenario=normal → risk_level = NORMAL."""
        response = client.post("/api/v1/evaluate?scenario=normal&patient_id=PAT-001")
        assert response.status_code == 200
        assert response.json()["risk_level"] == "NORMAL"

    def test_invalid_scenario_returns_400(self):
        """Escenario inválido → 400 Bad Request o 422 Unprocessable."""
        response = client.get("/api/v1/simulate/reading?scenario=invalid")
        assert response.status_code in (400, 422)
