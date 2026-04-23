"""
poc_simulador.py — Prueba de Concepto: Generación de señales biométricas simuladas.

Ejecutar:
    cd backend
    python ../scripts/poc/poc_simulador.py

Demuestra los tres escenarios clínicos y exporta un CSV de muestra.
"""
import sys
import os
import csv
import random
from datetime import datetime, timedelta

# Permite importar el módulo del backend
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'backend'))

from src.infrastructure.adapters.input.simulators.simulated_data_generator import SimulatedDataGenerator

SCENARIOS = ["normal", "moderate", "critical"]
SAMPLES_PER_SCENARIO = 20
OUTPUT_CSV = os.path.join(os.path.dirname(__file__), "simulacion_poc.csv")


def main():
    generator = SimulatedDataGenerator()
    rows = []

    print("=" * 60)
    print("  Smart Overdose Detector — PoC Simulador de Señales")
    print("=" * 60)

    for scenario in SCENARIOS:
        print(f"\n📋 Escenario: {scenario.upper()} ({SAMPLES_PER_SCENARIO} muestras)")
        for i in range(SAMPLES_PER_SCENARIO):
            reading = generator.generate_reading("PAT-001", scenario)  # type: ignore
            estado = "CRITICO" if (reading.spo2 < 82 or reading.bpm < 50) else (
                "MODERADO" if (reading.spo2 < 90 or reading.bpm < 60) else "NORMAL"
            )
            rows.append({
                "dni": "12345678",
                "nombre": "Carlos Mendoza",
                "edad": 34,
                "SpO2_Oxigeno": reading.spo2,
                "Frecuencia_Cardiaca": reading.bpm,
                "Nivel_Actividad": reading.activity,
                "Estado_Riesgo": 1 if estado == "CRITICO" else 0,
                "Escenario": scenario,
                "Timestamp": reading.timestamp.isoformat(),
            })
            print(
                f"  [{i+1:02d}] SpO2={reading.spo2:5.1f}% | "
                f"FC={reading.bpm:3d} BPM | "
                f"Act={reading.activity} | "
                f"→ {estado}"
            )

    # Exportar CSV
    with open(OUTPUT_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    print(f"\n✅ CSV de simulación exportado → {OUTPUT_CSV}")
    print(f"   Total registros: {len(rows)}")
    critical = sum(1 for r in rows if r["Estado_Riesgo"] == 1)
    print(f"   Críticos: {critical} | No críticos: {len(rows) - critical}")


if __name__ == "__main__":
    main()
