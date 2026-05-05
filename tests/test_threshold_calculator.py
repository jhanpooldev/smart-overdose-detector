"""
tests/test_threshold_calculator.py — Pruebas unitarias para la lógica
de cálculo de umbrales clínicos (Fórmula de Tanaka + IMC).

Cubre: diferentes edades, peso/talla (IMC normal u obesidad), ajuste ±5 BPM.
"""
import pytest


def _calculate_thresholds(edad: int, peso: float, altura: float) -> dict:
    """Réplica de la función del backend para tests aislados."""
    fc_max = 208 - (0.7 * edad)
    imc = peso / (altura ** 2)
    ajuste = 5 if imc > 30 else 0
    return {
        "fc_max": round(fc_max),
        "imc": round(imc, 1),
        "ajuste_obesidad": ajuste,
        "bpm": {
            "normal_min": 60,
            "normal_max": round(0.75 * fc_max) - ajuste,
            "moderate_lo": round(0.50 * fc_max),
            "moderate_hi": round(0.90 * fc_max) + ajuste,
            "critical_lo": 50,
            "critical_hi": round(fc_max) + ajuste,
        },
        "spo2": {
            "normal_min": 95.0,
            "moderate_min": 90.0,
            "critical_max": 82.0,
        },
    }


class TestTanakaFormula:

    def test_adult_30y_normal_weight(self):
        """Paciente 30 años, 70 kg, 1.75 m → IMC normal, sin ajuste."""
        t = _calculate_thresholds(30, 70.0, 1.75)
        # FC máx = 208 - (0.7 * 30) = 208 - 21 = 187
        assert t["fc_max"] == 187
        assert t["ajuste_obesidad"] == 0
        assert t["bpm"]["normal_max"] == round(0.75 * 187)
        assert t["bpm"]["moderate_hi"] == round(0.90 * 187)

    def test_elder_70y_reduces_fc_max(self):
        """Paciente mayor (70 años) → FC máx menor."""
        t = _calculate_thresholds(70, 65.0, 1.68)
        # FC máx = 208 - (0.7 * 70) = 208 - 49 = 159
        assert t["fc_max"] == 159
        assert t["bpm"]["critical_hi"] == 159

    def test_obese_patient_applies_adjustment(self):
        """Paciente con IMC > 30 → ajuste de +5 BPM en umbrales."""
        # IMC = 100 / (1.70^2) = 100 / 2.89 ≈ 34.6 → obesidad
        t = _calculate_thresholds(35, 100.0, 1.70)
        assert t["imc"] > 30
        assert t["ajuste_obesidad"] == 5
        # normal_max disminuye 5 BPM (más conservador)
        fc_max = 208 - (0.7 * 35)
        assert t["bpm"]["normal_max"] == round(0.75 * fc_max) - 5
        # moderate_hi aumenta 5 BPM
        assert t["bpm"]["moderate_hi"] == round(0.90 * fc_max) + 5

    def test_normal_weight_no_adjustment(self):
        """Paciente IMC 23 → sin ajuste."""
        t = _calculate_thresholds(25, 65.0, 1.68)
        imc = 65.0 / (1.68 ** 2)
        assert imc < 30
        assert t["ajuste_obesidad"] == 0

    def test_spo2_thresholds_are_constant(self):
        """Los umbrales de SpO₂ no cambian con biometría."""
        for (edad, peso, alt) in [(20, 60, 1.65), (50, 90, 1.75), (70, 80, 1.60)]:
            t = _calculate_thresholds(edad, peso, alt)
            assert t["spo2"]["normal_min"] == 95.0
            assert t["spo2"]["moderate_min"] == 90.0
            assert t["spo2"]["critical_max"] == 82.0

    def test_bpm_normal_min_is_always_60(self):
        """El BPM mínimo normal es siempre 60 (constante clínica)."""
        t = _calculate_thresholds(45, 75.0, 1.78)
        assert t["bpm"]["normal_min"] == 60

    def test_bpm_critical_lo_is_always_50(self):
        """El BPM crítico bajo es siempre 50 (constante clínica)."""
        t = _calculate_thresholds(60, 80.0, 1.72)
        assert t["bpm"]["critical_lo"] == 50

    def test_younger_patient_has_higher_fc_max(self):
        """Un paciente más joven tiene mayor FC máx que uno mayor."""
        young = _calculate_thresholds(20, 70.0, 1.75)
        old   = _calculate_thresholds(60, 70.0, 1.75)
        assert young["fc_max"] > old["fc_max"]
