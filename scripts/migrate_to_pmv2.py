import psycopg2
import sys

print("=" * 60)
print("REINICIANDO Y MIGRANDO BASE DE DATOS A PMV2 DESDE CERO")
print("=" * 60)

import os
from dotenv import load_dotenv

# Cargar variables de entorno del backend si existe
backend_env = os.path.join(os.path.dirname(os.path.dirname(__file__)), "backend", ".env")
if os.path.exists(backend_env):
    load_dotenv(backend_env)
else:
    load_dotenv()

db_url = os.getenv("DATABASE_URL", "postgresql://postgres@localhost:5432/Overdose-detector")

try:
    conn = psycopg2.connect(db_url)
    conn.autocommit = True
    cur = conn.cursor()


    # 1. Dropear todas las tablas y vistas existentes de PMV1 para empezar de cero
    tables_to_drop = [
        "emergency_contacts",
        "risk_events",
        "thresholds",
        "biometric_signals",
        "users",
        "iot_sessions",
        "contacts",
        "patient_contacts",
        "export_logs"
    ]
    print("[INFO] Eliminando tablas y vistas antiguas...")
    for t in tables_to_drop:
        cur.execute(f"DROP TABLE IF EXISTS {t} CASCADE")
        cur.execute(f"DROP VIEW IF EXISTS {t} CASCADE")

    # 2. Leer y ejecutar el script init_pmv2.sql completo
    sql_file = "scripts/db/init_pmv2.sql"
    print(f"[INFO] Leyendo archivo SQL: {sql_file}...")
    with open(sql_file, "r", encoding="utf-8") as f:
        sql_content = f.read()

    # Ejecutar comandos del script
    print("[INFO] Creando esquema PMV2...")
    cur.execute(sql_content)
    print("[OK] Base de datos PMV2 inicializada exitosamente de cero en PostgreSQL.")

    cur.close()
    conn.conn = None  # Evitar warnings
    conn.close()

except Exception as e:
    print(f"\n[ERROR] Fallo en la inicialización: {e}")
    sys.exit(1)
