"""
poc_clasificador.py — Prueba de Concepto: Clasificador de riesgo con reglas clínicas.

Ejecutar:
    cd backend
    python ../scripts/poc/poc_clasificador.py

Valida que el motor de reglas clínicas cumple con el accuracy >= 85% del PMV1.
"""
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'backend'))

from src.infrastructure.adapters.input.simulators.simulated_data_generator import SimulatedDataGenerator
from src.infrastructure.adapters.output.external_services.rule_based_anomaly_detector import RuleBasedAnomalyDetector
from src.domain.valueObjects.biometric_features import BiometricFeatures
from src.domain.entities.risk_event import RiskLevel

SAMPLES = 100

def main():
    generator = SimulatedDataGenerator()
    detector = RuleBasedAnomalyDetector()

    print("=" * 65)
    print("  Smart Overdose Detector — PoC Clasificador de Riesgo")
    print("=" * 65)

    results = {"correct": 0, "total": 0}

    for scenario, expected_critical in [("normal", False), ("moderate", False), ("critical", True)]:
        correct = 0
        for _ in range(SAMPLES):
            reading = generator.generate_reading("PAT-PoC", scenario)  # type: ignore
            features = BiometricFeatures(spo2=reading.spo2, bpm=reading.bpm, activity=reading.activity)
            prediction = detector.predict_risk(features)
            is_critical_pred = prediction.risk_level == RiskLevel.CRITICAL
            if is_critical_pred == expected_critical:
                correct += 1
        accuracy = correct / SAMPLES * 100
        status = "✅" if accuracy >= 85 else "❌"
        print(f"\n{status} Escenario {scenario.upper():10} | Accuracy: {accuracy:.1f}% ({correct}/{SAMPLES})")
        results["correct"] += correct
        results["total"] += SAMPLES

    global_accuracy = results["correct"] / results["total"] * 100
    print("\n" + "=" * 65)
    print(f"  Accuracy Global: {global_accuracy:.1f}% (meta: ≥ 85%)")
    print("  " + ("✅ PMV1 APROBADO" if global_accuracy >= 85 else "❌ PMV1 NO APROBADO"))
    print("=" * 65)


if __name__ == "__main__":
    main()
