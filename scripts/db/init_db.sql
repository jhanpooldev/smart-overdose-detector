-- =============================================================================
-- init_db.sql — Inicialización de base de datos PostgreSQL + TimescaleDB
-- Proyecto: Smart Overdose Detector | UC-TSI-2026-001
-- =============================================================================

-- Extensión de series temporales (TimescaleDB)
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- =============================================================================
-- 1. TABLA: patients
-- =============================================================================
CREATE TABLE IF NOT EXISTS patients (
    patient_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dni             VARCHAR(20)  UNIQUE NOT NULL,
    nombre          VARCHAR(100) NOT NULL,
    apellido        VARCHAR(100) NOT NULL,
    edad            SMALLINT     NOT NULL CHECK (edad BETWEEN 0 AND 120),
    telefono        VARCHAR(20),
    fecha_registro  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- 2. TABLA: emergency_contacts
-- =============================================================================
CREATE TABLE IF NOT EXISTS emergency_contacts (
    contact_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre      VARCHAR(100) NOT NULL,
    telefono    VARCHAR(20)  NOT NULL,
    relacion    VARCHAR(50)  NOT NULL,  -- "Familiar", "Médico", "Tutor"
    es_principal BOOLEAN     NOT NULL DEFAULT FALSE
);

-- =============================================================================
-- 3. TABLA INTERMEDIA: patient_contacts (N:M Paciente ↔ Contacto)
-- =============================================================================
CREATE TABLE IF NOT EXISTS patient_contacts (
    patient_id  UUID NOT NULL REFERENCES patients(patient_id) ON DELETE CASCADE,
    contact_id  UUID NOT NULL REFERENCES emergency_contacts(contact_id) ON DELETE CASCADE,
    PRIMARY KEY (patient_id, contact_id)
);

-- =============================================================================
-- 4. TABLA: devices (smartwatch o simulador vinculado al paciente)
-- =============================================================================
CREATE TABLE IF NOT EXISTS devices (
    device_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id   UUID NOT NULL REFERENCES patients(patient_id) ON DELETE CASCADE,
    device_type  VARCHAR(50) NOT NULL DEFAULT 'simulator',  -- 'simulator' | 'ble_wearable'
    device_name  VARCHAR(100),
    mac_address  VARCHAR(17),  -- Para BLE en PMV2
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    linked_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- 5. HIPERTABLA: biometric_signals (TimescaleDB — series temporales)
-- =============================================================================
CREATE TABLE IF NOT EXISTS biometric_signals (
    signal_time     TIMESTAMPTZ  NOT NULL,
    patient_id      UUID         NOT NULL REFERENCES patients(patient_id),
    device_id       UUID         REFERENCES devices(device_id),
    spo2            NUMERIC(5,2) NOT NULL CHECK (spo2 BETWEEN 70 AND 100),
    bpm             SMALLINT     NOT NULL CHECK (bpm BETWEEN 30 AND 180),
    activity_level  SMALLINT     NOT NULL CHECK (activity_level IN (0, 1)),
    source          VARCHAR(20)  NOT NULL DEFAULT 'simulator'
);

-- Convertir a hipertabla particionada por tiempo (chunk cada 1 hora)
SELECT create_hypertable(
    'biometric_signals',
    'signal_time',
    chunk_time_interval => INTERVAL '1 hour',
    if_not_exists => TRUE
);

-- Índice para consultas por paciente en rango de tiempo
CREATE INDEX IF NOT EXISTS idx_biosig_patient_time
    ON biometric_signals (patient_id, signal_time DESC);

-- =============================================================================
-- 6. TABLA: risk_events (historial clínico de alertas de la IA)
-- =============================================================================
CREATE TABLE IF NOT EXISTS risk_events (
    event_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id      UUID NOT NULL REFERENCES patients(patient_id),
    risk_level      VARCHAR(10) NOT NULL CHECK (risk_level IN ('NORMAL', 'MODERATE', 'CRITICAL')),
    probability     NUMERIC(5,4) NOT NULL CHECK (probability BETWEEN 0 AND 1),
    spo2_at_event   NUMERIC(5,2) NOT NULL,
    bpm_at_event    SMALLINT     NOT NULL,
    activity_at_event SMALLINT   NOT NULL,
    detected_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    alert_sent      BOOLEAN      NOT NULL DEFAULT FALSE,
    explanation     TEXT
);

-- Índice para historial por paciente
CREATE INDEX IF NOT EXISTS idx_risk_events_patient
    ON risk_events (patient_id, detected_at DESC);

-- =============================================================================
-- 7. DATOS DE PRUEBA — Paciente y contacto de emergencia de ejemplo
-- =============================================================================
INSERT INTO patients (dni, nombre, apellido, edad, telefono)
VALUES ('12345678', 'Carlos', 'Mendoza', 34, '+51987654321')
ON CONFLICT (dni) DO NOTHING;

INSERT INTO emergency_contacts (nombre, telefono, relacion, es_principal)
VALUES ('María Mendoza', '+51912345678', 'Familiar', TRUE)
ON CONFLICT DO NOTHING;
