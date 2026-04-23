-- =============================================================================
-- trabajo.sql — Base de datos Smart Overdose Detector (Adaptado al diseño final)
-- =============================================================================

-- Si tienes TimescaleDB instalado, descomenta esta línea:
-- CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Limpiamos si ya existen
DROP TABLE IF EXISTS risk_events CASCADE;
DROP TABLE IF EXISTS biometric_signals CASCADE;
DROP TABLE IF EXISTS biometric_signals_simple CASCADE;
DROP TABLE IF EXISTS devices CASCADE;
DROP TABLE IF EXISTS patient_contacts CASCADE;
DROP TABLE IF EXISTS emergency_contacts CASCADE;
DROP TABLE IF EXISTS patients CASCADE;

-- =============================================================================
-- 1. TABLA: patients
-- =============================================================================
CREATE TABLE patients (
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
CREATE TABLE emergency_contacts (
    contact_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre      VARCHAR(100) NOT NULL,
    telefono    VARCHAR(20)  NOT NULL,
    relacion    VARCHAR(50)  NOT NULL,
    es_principal BOOLEAN     NOT NULL DEFAULT FALSE
);

-- =============================================================================
-- 3. TABLA INTERMEDIA: patient_contacts (N:M)
-- =============================================================================
CREATE TABLE patient_contacts (
    patient_id  UUID NOT NULL REFERENCES patients(patient_id) ON DELETE CASCADE,
    contact_id  UUID NOT NULL REFERENCES emergency_contacts(contact_id) ON DELETE CASCADE,
    PRIMARY KEY (patient_id, contact_id)
);

-- =============================================================================
-- 4. TABLA: devices
-- =============================================================================
CREATE TABLE devices (
    device_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id   UUID NOT NULL REFERENCES patients(patient_id) ON DELETE CASCADE,
    device_type  VARCHAR(50) NOT NULL DEFAULT 'ble_wearable',
    device_name  VARCHAR(100),
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    linked_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- 5. TABLA: biometric_signals_simple (usada por nuestro repositorio)
-- =============================================================================
CREATE TABLE biometric_signals_simple (
    id              SERIAL PRIMARY KEY,
    signal_time     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    patient_id      VARCHAR(50)  NOT NULL, 
    spo2            NUMERIC(5,2) NOT NULL CHECK (spo2 BETWEEN 70 AND 100),
    bpm             SMALLINT     NOT NULL CHECK (bpm BETWEEN 30 AND 200),
    activity        SMALLINT     NOT NULL CHECK (activity IN (0, 1)),
    source          VARCHAR(20)  NOT NULL DEFAULT 'simulator'
);
CREATE INDEX idx_biosig_patient ON biometric_signals_simple(patient_id);

-- =============================================================================
-- 6. TABLA: risk_events
-- =============================================================================
CREATE TABLE risk_events (
    event_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id      VARCHAR(50) NOT NULL,
    risk_level      VARCHAR(10) NOT NULL CHECK (risk_level IN ('NORMAL', 'MODERATE', 'CRITICAL')),
    probability     NUMERIC(5,4) NOT NULL CHECK (probability BETWEEN 0 AND 1),
    spo2_at_event   NUMERIC(5,2) NOT NULL,
    bpm_at_event    SMALLINT     NOT NULL,
    activity_at_event SMALLINT   NOT NULL,
    detected_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    alert_sent      BOOLEAN      NOT NULL DEFAULT FALSE,
    explanation     TEXT
);

-- =============================================================================
-- 7. DATOS DE EJEMPLO DE TU ARCHIVO ORIGINAL
-- =============================================================================

-- Paciente: Juan Perez (Edad calculada en base a 1950)
INSERT INTO patients (patient_id, dni, nombre, apellido, edad, telefono)
VALUES ('00000000-0000-0000-0000-000000000001', '12345678', 'Juan', 'Perez', 76, '+51987654320');

-- Contacto: Maria Perez
INSERT INTO emergency_contacts (contact_id, nombre, telefono, relacion, es_principal)
VALUES ('00000000-0000-0000-0000-000000000002', 'Maria Perez', '987654321', 'Hija', TRUE);

-- Vincular contacto
INSERT INTO patient_contacts (patient_id, contact_id)
VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002');

-- Dispositivo: Smartwatch Samsung
INSERT INTO devices (device_id, patient_id, device_type, device_name, is_active)
VALUES ('00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', 'wearable', 'Smartwatch Samsung', TRUE);

-- Simular la misma lectura que tenías: FC=75, SpO2=98.0
-- (Usamos 'PAT-001' como patient_id porque es el que usa el simulador en el código PMV1 por defecto)
INSERT INTO biometric_signals_simple (signal_time, patient_id, spo2, bpm, activity, source)
VALUES ('2026-04-21 23:05:32.904531', 'PAT-001', 98.00, 75, 1, 'wearable');

-- Evento de riesgo
INSERT INTO risk_events (patient_id, risk_level, probability, spo2_at_event, bpm_at_event, activity_at_event, detected_at)
VALUES ('PAT-001', 'CRITICAL', 0.9250, 98.00, 75, 1, '2026-04-21 23:05:32.904531');
