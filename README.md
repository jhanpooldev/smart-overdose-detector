# smart-overdose-detector
# Smart Overdose Detector  (Dispositivo Inteligente para Detección Temprana de Sobredosis)

![Status](https://img.shields.io/badge/Status-Development-orange)
![Architecture](https://img.shields.io/badge/Architecture-Hexagonal-blue)
![IA](https://img.shields.io/badge/IA-LSTM%20/%20TFLite-green)

##  Descripción del Proyecto
[cite_start]Este proyecto consiste en un sistema inteligente de monitoreo biométrico diseñado para la detección temprana de sobredosis por opioides y otras sustancias[cite: 1]. [cite_start]Utiliza una combinación de hardware **Wearable (Smartwatch)**, una **App Móvil** y un **Backend robusto** para identificar patrones fisiológicos críticos mediante Inteligencia Artificial [cite: 15-16, 51].

[cite_start]El problema central que abordamos es la detección tardía de eventos críticos y la ausencia de monitoreo continuo fuera del entorno hospitalario, lo que resulta en muertes evitables cuando la persona se encuentra sola [cite: 5-8, 11].

##  Impacto Social
El proyecto está diseñado con un enfoque regional para:
* [cite_start]Mejorar la continuidad terapéutica en la región **Junín**[cite: 131].
* [cite_start]Reducir costos de rehabilitación y apoyar a los hospitales de **Huancayo**[cite: 132, 134].
* [cite_start]Facilitar la tele-rehabilitación rural en zonas de difícil acceso[cite: 133].

##  Stack Tecnológico
* [cite_start]**Frontend:** Flutter (Dart) para la plataforma móvil[cite: 44].
* [cite_start]**Backend:** FastAPI (Python) orientado a Arquitectura Hexagonal[cite: 19, 44].
* [cite_start]**IA:** Modelos LSTM (Deep Learning) ejecutados en el móvil vía TensorFlow Lite[cite: 38, 51].
* [cite_start]**Base de Datos:** PostgreSQL con extensión **TimescaleDB** para series temporales[cite: 44].
* [cite_start]**Hardware:** Smartwatch (Wear OS / WatchOS) para captura de señales (FC, $SpO_2$, Respiración) [cite: 15, 28, 31-34].

##  Arquitectura de Software
[cite_start]El sistema implementa una **Arquitectura Hexagonal**, desacoplando el dominio clínico de los dispositivos y servicios externos para garantizar escalabilidad y testeabilidad [cite: 61-63, 121-122].

### Estructura del Repositorio
```text
src/
├── domain/                  # Núcleo del Negocio (Core)
[cite_start]│   ├── entities/            # Paciente, EventoRiesgo, SenalBiometrica [cite: 98, 101, 105]
│   ├── valueobjects/        # BioMetria, CoordenadasGPS
[cite_start]│   └── services/            # Lógica de detección y reglas clínicas [cite: 36, 124]
│
├── application/             # Casos de Uso
[cite_start]│   ├── usecases/            # MonitorizarSignos, DispararAlerta [cite: 76-77]
│   └── ports/               # Interfaces de Entrada y Salida
│       ├── input/           # Puertos de Driver
│       └── output/          # Puertos de Driven
│
├── adapters/                # Implementaciones Técnicas
│   ├── in/                  # Adaptadores de Entrada
│   │   └── controllers/     # FastAPI Rest API / MQTT Handler
│   └── out/                 # Adaptadores de Salida
│       ├── persistence/     # TimescaleDB / PostgreSQL Adapter
[cite_start]│       ├── external/        # Twilio (SMS), Email Adapter [cite: 94]
[cite_start]│       └── ia_engine/       # Inferencia local con TFLite [cite: 51, 93]
│
└── infrastructure/          # Configuración Global
    ├── configuration/       # Inyección de Dependencias
    └── poc/                 # << Proof of Concept >> Prototipos de Simulación IoT

## 🗄️ Modelo de Base de Datos (SQL)

El siguiente script define la estructura relacional utilizada para almacenar la información de pacientes, dispositivos biométricos, señales en tiempo real y eventos de riesgo dentro del sistema.

```sql
-- =========================
-- TABLA PACIENTES
-- =========================
CREATE TABLE patients (
    patient_id SERIAL PRIMARY KEY,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    birth_date DATE,
    base_bkl_profile TEXT
);

-- =========================
-- TABLA DISPOSITIVOS
-- =========================
CREATE TABLE devices (
    device_id SERIAL PRIMARY KEY,
    patient_id INT REFERENCES patients(patient_id) ON DELETE CASCADE,
    device_type VARCHAR(100),
    status VARCHAR(50)
);

-- =========================
-- TABLA SEÑALES BIOMÉTRICAS
-- =========================
CREATE TABLE biometric_signals (
    signal_id SERIAL PRIMARY KEY,
    device_id INT REFERENCES devices(device_id) ON DELETE CASCADE,
    time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    heart_rate INT,
    spo2 NUMERIC(5,2),
    resp_rate INT
);

-- =========================
-- TABLA EVENTOS DE RIESGO
-- =========================
CREATE TABLE risk_events (
    event_id SERIAL PRIMARY KEY,
    patient_id INT REFERENCES patients(patient_id) ON DELETE CASCADE,
    risk_level VARCHAR(50),
    probability NUMERIC(5,2),
    location TEXT,
    event_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =========================
-- CONTACTOS DE EMERGENCIA
-- =========================
CREATE TABLE emergency_contacts (
    contact_id SERIAL PRIMARY KEY,
    full_name VARCHAR(150),
    phone_number VARCHAR(20),
    relationship VARCHAR(50)
);

-- =========================
-- TABLA INTERMEDIA
-- =========================
CREATE TABLE patient_contacts (
    patient_id INT REFERENCES patients(patient_id) ON DELETE CASCADE,
    contact_id INT REFERENCES emergency_contacts(contact_id) ON DELETE CASCADE,
    PRIMARY KEY (patient_id, contact_id)
);


