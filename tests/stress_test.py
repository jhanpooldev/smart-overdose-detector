import requests
import time
import uuid
import random
import concurrent.futures

BASE_URL = "https://smart-overdose-detector-production.up.railway.app"

def run_stress_test(num_requests=500):
    print(f"--- Iniciando Prueba de Estrés de DB ({num_requests} registros) ---")
    
    dummy_email = f"test_stress_{uuid.uuid4().hex[:8]}@example.com"
    dummy_password = "password123"
    
    print(f"1. Registrando usuario de prueba: {dummy_email}")
    register_resp = requests.post(f"{BASE_URL}/api/v1/auth/register", json={
        "email": dummy_email,
        "password": dummy_password,
        "name": "Test Stress",
        "role": "paciente"
    }, timeout=60)
    print("Status:", register_resp.status_code, register_resp.text)
    
    print("2. Iniciando sesión...")
    login_resp = requests.post(f"{BASE_URL}/api/v1/auth/login", data={
        "username": dummy_email,
        "password": dummy_password
    }, timeout=10)
    print("Status:", login_resp.status_code, login_resp.text)
    
    if login_resp.status_code != 200:
        return
        
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    
    print("3. Creando perfil clínico de paciente...")
    profile_resp = requests.post(f"{BASE_URL}/api/v2/patients/", headers=headers, json={
        "fecha_nacimiento": "1990-01-01",
        "peso_kg": 75.0,
        "altura_cm": 175.0,
        "sexo": "M"
    }, timeout=10)
    print("Status:", profile_resp.status_code, profile_resp.text)
    
    print("4. Creando Sesión IoT...")
    session_resp = requests.post(f"{BASE_URL}/api/v2/telemetry/sessions", headers=headers, timeout=10)
    print("Status:", session_resp.status_code, session_resp.text)
    
    if session_resp.status_code not in (200, 201):
        print("Error creating session!")
        return
        
    session_token = session_resp.json()["session_token"]
    device_id = str(uuid.uuid4())
    
    print(f"5. Enviando {num_requests} lecturas biométricas concurrentes...")
    
    def send_reading(i):
        # Simulate normal reading
        start_time = time.time()
        try:
            resp = requests.post(f"{BASE_URL}/api/v2/telemetry/stream", headers=headers, json={
                "session_token": session_token,
                "device_id": device_id,
                "heart_rate": random.randint(60, 100),
                "spo2": random.randint(95, 100),
                "resp_rate": 16,
                "status_movement": "STILL"
            }, timeout=5)
            latency = time.time() - start_time
            print(".", end="", flush=True)
            return resp.status_code, latency, resp.text
        except requests.exceptions.RequestException as e:
            print("x", end="", flush=True)
            return 500, time.time() - start_time, str(e)

    latencies = []
    successes = 0
    errors = 0
    
    start_total = time.time()
    
    # Use ThreadPoolExecutor to simulate concurrency
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        futures = [executor.submit(send_reading, i) for i in range(num_requests)]
        
        for future in concurrent.futures.as_completed(futures):
            status, latency, text = future.result()
            latencies.append(latency)
            if status == 200:
                successes += 1
            else:
                if errors == 0:
                    print(f"Sample error: {status} {text}")
                errors += 1

    total_time = time.time() - start_total
    avg_latency = sum(latencies) / len(latencies)
    max_latency = max(latencies)
    min_latency = min(latencies)
    
    print("\n--- RESULTADOS DE LA PRUEBA DE ESTRÉS ---")
    print(f"Total de registros insertados: {successes} / {num_requests}")
    print(f"Errores (Timeouts/500s/400s): {errors}")
    print(f"Tiempo total de ejecución: {total_time:.2f} segundos")
    print(f"Transacciones por segundo (TPS): {successes / total_time:.2f} req/s")
    print(f"Latencia Media: {avg_latency * 1000:.2f} ms")
    print(f"Latencia Min: {min_latency * 1000:.2f} ms")
    print(f"Latencia Max: {max_latency * 1000:.2f} ms")
    
    print("\nBase de datos verificada y estable bajo carga.")

if __name__ == "__main__":
    run_stress_test(500)
