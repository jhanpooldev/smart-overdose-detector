-- =============================================================
-- Overdose-detector — Script de creación de base de datos
-- Motor: PostgreSQL + TimescaleDB
-- Base de datos: Overdose-detector
-- Puerto: 5432
--
-- INSTRUCCIONES:
--   1. Conectarte a PostgreSQL con psql o pgAdmin
--   2. Seleccionar la base de datos: \c "Overdose-detector"
--   3. Ejecutar este script completo
-- =============================================================

-- Habilitar extensión UUID y TimescaleDB
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

-- ---------------------------------------------------------------
-- 1. TABLA DE USUARIOS
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id               UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    email            VARCHAR(255) NOT NULL UNIQUE,
    hashed_password  VARCHAR(255) NOT NULL,
    role             VARCHAR(20)  NOT NULL CHECK (role IN ('PACIENTE', 'SUPERVISOR')),
    supervisor_email VARCHAR(255) NULL,
    edad             INTEGER      NULL,
    peso             NUMERIC(5,2) NULL,
    altura           NUMERIC(4,2) NULL,
    sexo             VARCHAR(20)  NULL,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_supervisor_email ON users (supervisor_email);

-- ---------------------------------------------------------------
-- 2. TABLA DE SEÑALES BIOMÉTRICAS (TimescaleDB Hypertable)
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS biometric_signals (
    signal_time  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    patient_id   UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    spo2         DOUBLE PRECISION NOT NULL,
    bpm          INTEGER       NOT NULL,
    activity     INTEGER       NOT NULL DEFAULT 0,
    source       VARCHAR(20)   NOT NULL DEFAULT 'sensor'
);

-- Convertir a hipertabla particionada por tiempo (TimescaleDB)
SELECT create_hypertable(
    'biometric_signals',
    'signal_time',
    if_not_exists => TRUE
);

CREATE INDEX IF NOT EXISTS idx_biometric_signals_patient ON biometric_signals (patient_id, signal_time DESC);

-- ---------------------------------------------------------------
-- 3. TABLA DE EVENTOS DE RIESGO
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS risk_events (
    event_id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id        UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    detected_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    risk_level        VARCHAR(20) NOT NULL CHECK (risk_level IN ('NORMAL', 'MODERATE', 'CRITICAL')),
    probability       DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    spo2_at_event     DOUBLE PRECISION NOT NULL,
    bpm_at_event      INTEGER     NOT NULL,
    activity_at_event INTEGER     NOT NULL DEFAULT 0,
    alert_sent        BOOLEAN     NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_risk_events_patient ON risk_events (patient_id, detected_at DESC);

-- ---------------------------------------------------------------
-- 4. TABLA DE CONTACTOS DE EMERGENCIA
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS emergency_contacts (
    contact_id   UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id   UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    nombre       VARCHAR(150) NOT NULL,
    telefono     VARCHAR(20)  NOT NULL,
    relacion     VARCHAR(50)  NOT NULL DEFAULT 'Familiar',
    es_principal BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_contacts_patient ON emergency_contacts (patient_id);

-- ---------------------------------------------------------------
-- 5. TABLA DE CONFIGURACIÓN DE UMBRALES
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS thresholds (
    id                   SERIAL PRIMARY KEY,
    patient_id           UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    bpm_min_normal       INTEGER     NOT NULL DEFAULT 60,
    bpm_max_normal       INTEGER     NOT NULL DEFAULT 100,
    bpm_min_moderate     INTEGER     NOT NULL DEFAULT 50,
    bpm_max_moderate     INTEGER     NOT NULL DEFAULT 130,
    spo2_min_normal      DOUBLE PRECISION NOT NULL DEFAULT 95.0,
    spo2_min_moderate    DOUBLE PRECISION NOT NULL DEFAULT 90.0,
    spo2_min_critical    DOUBLE PRECISION NOT NULL DEFAULT 82.0,
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (patient_id)
);

-- ---------------------------------------------------------------
-- FIN DEL SCRIPT
-- No se insertan datos de prueba.
-- Los usuarios se registran desde la aplicación móvil.
-- ---------------------------------------------------------------
