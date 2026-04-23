"""
tests/test_simulated_generator.py — Pruebas unitarias del SimulatedDataGenerator.

Verifica que cada escenario genera valores dentro de los rangos clínicos correctos.
"""
import pytest
from src.infrastructure.adapters.input.simulators.simulated_data_generator import SimulatedDataGenerator

SAMPLES = 100


@pytest.fixture
def generator():
    return SimulatedDataGenerator()


class TestSimulatedDataGenerator:

    def test_normal_scenario_spo2_range(self, generator):
        """SpO2 siempre debe estar entre 95% y 100% en escenario normal."""
        for _ in range(SAMPLES):
            reading = generator.generate_reading("PAT-TEST", "normal")
            assert 95.0 <= reading.spo2 <= 100.0, f"SpO2 normal fuera de rango: {reading.spo2}"

    def test_normal_scenario_bpm_range(self, generator):
        """BPM debe estar entre 60 y 100 en escenario normal."""
        for _ in range(SAMPLES):
            reading = generator.generate_reading("PAT-TEST", "normal")
            assert 60 <= reading.bpm <= 100, f"BPM normal fuera de rango: {reading.bpm}"

    def test_normal_scenario_activity(self, generator):
        """Actividad debe ser siempre 1 en escenario normal."""
        for _ in range(SAMPLES):
            reading = generator.generate_reading("PAT-TEST", "normal")
            assert reading.activity == 1

    def test_critical_scenario_spo2_below_82(self, generator):
        """SpO2 SIEMPRE debe ser < 82% en escenario crítico (RNF-01)."""
        for _ in range(SAMPLES):
            reading = generator.generate_reading("PAT-TEST", "critical")
            assert reading.spo2 < 82.0, (
                f"SpO2 crítico debe ser < 82%: obtenido {reading.spo2}"
            )

    def test_critical_scenario_bpm_below_50(self, generator):
        """BPM SIEMPRE debe ser < 50 en escenario crítico (RNF-01)."""
        for _ in range(SAMPLES):
            reading = generator.generate_reading("PAT-TEST", "critical")
            assert reading.bpm < 50, (
                f"BPM crítico debe ser < 50: obtenido {reading.bpm}"
            )

    def test_critical_scenario_activity_zero(self, generator):
        """Actividad SIEMPRE debe ser 0 en escenario crítico."""
        for _ in range(SAMPLES):
            reading = generator.generate_reading("PAT-TEST", "critical")
            assert reading.activity == 0

    def test_moderate_scenario_spo2_range(self, generator):
        """SpO2 debe estar entre 90% y 94.9% en escenario moderado."""
        for _ in range(SAMPLES):
            reading = generator.generate_reading("PAT-TEST", "moderate")
            assert 90.0 <= reading.spo2 < 95.0, f"SpO2 moderado fuera de rango: {reading.spo2}"

    def test_invalid_scenario_raises(self, generator):
        """Un escenario desconocido debe lanzar ValueError."""
        with pytest.raises(ValueError):
            generator.generate_reading("PAT-TEST", "unknown_scenario")  # type: ignore

    def test_reading_has_timestamp(self, generator):
        """Todo reading debe tener un timestamp válido."""
        from datetime import datetime
        reading = generator.generate_reading("PAT-TEST", "normal")
        assert isinstance(reading.timestamp, datetime)
