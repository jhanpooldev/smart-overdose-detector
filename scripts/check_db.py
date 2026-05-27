import sys
import os

os.environ["PYTHONIOENCODING"] = "utf-8"

print("=" * 60)
print("DIAGNOSTICO DE BASE DE DATOS - Smart Overdose Detector")
print("=" * 60)

from dotenv import load_dotenv

# Cargar variables de entorno del backend si existe
backend_env = os.path.join(os.path.dirname(os.path.dirname(__file__)), "backend", ".env")
if os.path.exists(backend_env):
    load_dotenv(backend_env)
else:
    load_dotenv()

db_url = os.getenv("DATABASE_URL", "postgresql://postgres@localhost:5432/Overdose-detector")

try:
    import psycopg2
    conn = psycopg2.connect(db_url)
    cur = conn.cursor()


    cur.execute("SELECT version()")
    version = cur.fetchone()[0]
    print(f"\n[OK] CONEXION EXITOSA")
    print(f"     DB: {version[:80]}")

    # TimescaleDB
    cur.execute("SELECT extname, extversion FROM pg_extension WHERE extname = 'timescaledb'")
    ts = cur.fetchone()
    if ts:
        print(f"[OK] TimescaleDB activo: v{ts[1]}")
    else:
        print("[WARN] TimescaleDB NO instalado")

    # Tablas existentes
    cur.execute("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        ORDER BY table_name
    """)
    tables = [r[0] for r in cur.fetchall()]
    print(f"\nTABLAS EXISTENTES ({len(tables)}):")
    for t in tables:
        print(f"   - {t}")

    # Tablas requeridas
    required = ["users", "biometric_signals", "risk_events", "emergency_contacts", "thresholds"]
    print(f"\nVERIFICACION TABLAS REQUERIDAS:")
    all_ok = True
    for t in required:
        ok = t in tables
        status = "[OK]" if ok else "[FALTA]"
        print(f"   {status}  {t}")
        if not ok:
            all_ok = False

    # Columna telefono
    cur.execute("""
        SELECT column_name FROM information_schema.columns
        WHERE table_name = 'users' AND column_name = 'telefono'
    """)
    has_telefono = cur.fetchone() is not None
    print(f"\nCOLUMNAS CRITICAS:")
    print(f"   {'[OK]' if has_telefono else '[FALTA]'} users.telefono")

    # Hypertable
    try:
        cur.execute("""
            SELECT hypertable_name FROM timescaledb_information.hypertables
            WHERE hypertable_name = 'biometric_signals'
        """)
        is_hyper = cur.fetchone() is not None
        print(f"   {'[OK]' if is_hyper else '[NO]'} biometric_signals es hypertable TimescaleDB")
    except Exception:
        print("   [WARN] No se pudo verificar hypertable (TimescaleDB no disponible)")

    # Conteos
    cur.execute("SELECT role, COUNT(*) FROM users GROUP BY role")
    user_counts = cur.fetchall()
    print(f"\nUSUARIOS REGISTRADOS:")
    if user_counts:
        for role, count in user_counts:
            print(f"   {role}: {count}")
    else:
        print("   (sin usuarios - BD limpia, listo para usar)")

    cur.execute("SELECT COUNT(*) FROM biometric_signals")
    print(f"\nSENALES BIOMETRICAS: {cur.fetchone()[0]} registros")
    cur.execute("SELECT COUNT(*) FROM risk_events")
    print(f"EVENTOS DE RIESGO:   {cur.fetchone()[0]} registros")

    print(f"\n{'='*60}")
    if all_ok and has_telefono:
        print("RESULTADO: BD LISTA PARA PRODUCCION (STORAGE_BACKEND=postgres)")
    else:
        print("RESULTADO: BD INCOMPLETA - revisar tablas faltantes arriba")
    print(f"{'='*60}")

    cur.close()
    conn.close()

except ImportError:
    print("[ERROR] psycopg2 no instalado. Ejecuta: pip install psycopg2-binary")
    sys.exit(1)
except Exception as e:
    print(f"\n[ERROR] FALLO DE CONEXION: {e}")
    print("\nPosibles causas:")
    print("  1. PostgreSQL no esta corriendo en localhost:5432")
    print("  2. La BD 'Overdose-detector' no existe")
    print("  3. Credenciales incorrectas")
    sys.exit(1)
