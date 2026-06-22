-- ==============================================================
-- init_pmv2.sql — Schema completo PMV2
-- Motor: PostgreSQL 15 + TimescaleDB (Manejo tolerante a fallos)
-- Aplicar sobre la BD: Overdose-detector
-- Uso: psql -U postgres -d "Overdose-detector" -f init_pmv2.sql
-- ==============================================================

-- ── Extensiones ──────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Intentar cargar TimescaleDB de forma segura, ignorando si no está disponible
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'La extensión timescaledb no está disponible en este servidor PostgreSQL.';
END $$;

-- ── ENUMs de dominio ─────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE risk_level_enum   AS ENUM ('NORMAL', 'MODERATE', 'CRITICAL');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE movement_status   AS ENUM ('STILL', 'WALKING', 'RUNNING', 'UNKNOWN');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE iot_stream_status AS ENUM ('CONNECTED', 'DISCONNECTED', 'STREAM_ERROR');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── 1. USUARIOS ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id               UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    email            VARCHAR(255) NOT NULL UNIQUE,
    hashed_password  VARCHAR(255) NOT NULL,
    role             VARCHAR(20)  NOT NULL CHECK (role IN ('PACIENTE', 'SUPERVISOR')),
    supervisor_email VARCHAR(255) NULL,
    nombre           VARCHAR(150) NULL,
    edad             INTEGER      NULL,
    peso             NUMERIC(5,2) NULL,
    altura           NUMERIC(4,2) NULL,
    sexo             VARCHAR(20)  NULL,
    telefono         VARCHAR(25)  NULL,
    -- JSONB para almacenar perfil biométrico base calculado
    base_bio_profile JSONB        NULL DEFAULT '{}',
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email           ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_supervisor_email ON users (supervisor_email);
CREATE INDEX IF NOT EXISTS idx_users_bio_profile      ON users USING gin (base_bio_profile);

-- ── 2. SESIONES IoT (token de emparejamiento 6 chars) ─────────
CREATE TABLE IF NOT EXISTS iot_sessions (
    session_token   CHAR(6)       PRIMARY KEY,
    patient_id      UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    stream_status   iot_stream_status NOT NULL DEFAULT 'DISCONNECTED',
    last_heartbeat  TIMESTAMPTZ   NULL,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ   NOT NULL DEFAULT (NOW() + INTERVAL '24 hours')
);

CREATE INDEX IF NOT EXISTS idx_iot_sessions_patient ON iot_sessions (patient_id);

-- ── 3. SEÑALES BIOMÉTRICAS — TimescaleDB Hypertable ──────────
-- PK compuesta: (time, device_id) según especificación RF04
CREATE TABLE IF NOT EXISTS biometric_signals (
    "time"          TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    device_id       UUID           NOT NULL,           -- ID del dispositivo IoT o sesión
    patient_id      UUID           NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_token   CHAR(6)        NULL REFERENCES iot_sessions(session_token) ON DELETE SET NULL,
    heart_rate      INTEGER        NOT NULL,            -- BPM
    spo2            INTEGER        NOT NULL,            -- % saturación (0-100)
    resp_rate       INTEGER        NULL,                -- respiraciones/min (RF04)
    status_movement movement_status NOT NULL DEFAULT 'UNKNOWN',
    source          VARCHAR(20)    NOT NULL DEFAULT 'iot',
    PRIMARY KEY ("time", device_id)
);

-- Intentar crear hypertable solo si la extensión TimescaleDB está cargada
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'timescaledb') THEN
        PERFORM create_hypertable(
            'biometric_signals',
            'time',
            if_not_exists => TRUE,
            chunk_time_interval => INTERVAL '1 day'
        );
    ELSE
        RAISE NOTICE 'Saltando create_hypertable porque la extensión timescaledb no está activa.';
    END IF;
END $$;

-- Intentar agregar política de retención de datos si la extensión está activa
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'timescaledb') THEN
        PERFORM add_retention_policy('biometric_signals', INTERVAL '90 days', if_not_exists => TRUE);
    ELSE
        RAISE NOTICE 'Saltando add_retention_policy porque la extensión timescaledb no está activa.';
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_biometric_patient_time
    ON biometric_signals (patient_id, "time" DESC);
CREATE INDEX IF NOT EXISTS idx_biometric_session
    ON biometric_signals (session_token, "time" DESC);

-- ── 4. EVENTOS DE RIESGO ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS risk_events (
    event_id          UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id        UUID            NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    detected_at       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    risk_level        risk_level_enum NOT NULL,
    probability       DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    spo2_at_event     INTEGER         NOT NULL,
    bpm_at_event      INTEGER         NOT NULL,
    resp_rate_at_event INTEGER        NULL,
    movement_at_event movement_status NOT NULL DEFAULT 'UNKNOWN',
    alert_sent        BOOLEAN         NOT NULL DEFAULT FALSE,
    sma_spo2          DOUBLE PRECISION NULL,  -- Moving average SpO2 en el momento
    sma_bpm           DOUBLE PRECISION NULL   -- Moving average BPM en el momento
);

CREATE INDEX IF NOT EXISTS idx_risk_events_patient ON risk_events (patient_id, detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_risk_events_level   ON risk_events (risk_level, detected_at DESC);

-- ── 5. CONTACTOS DE EMERGENCIA (N:M con prioridad) ───────────
-- Tabla de contactos base (reutilizables)
CREATE TABLE IF NOT EXISTS contacts (
    contact_id  UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre      VARCHAR(150) NOT NULL,
    telefono    VARCHAR(25)  NOT NULL,
    email       VARCHAR(255) NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Tabla relacional N:M Paciente ↔ Contacto con campos relacionales
CREATE TABLE IF NOT EXISTS patient_contacts (
    id                       UUID    PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id               UUID    NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    contact_id               UUID    NOT NULL REFERENCES contacts(contact_id) ON DELETE CASCADE,
    parentesco               VARCHAR(80) NOT NULL DEFAULT 'Familiar',   -- RF03
    prioridad_notificacion   SMALLINT   NOT NULL DEFAULT 1              -- RF03: jerarquía 1,2,3
        CHECK (prioridad_notificacion BETWEEN 1 AND 3),
    es_principal             BOOLEAN    NOT NULL DEFAULT FALSE,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (patient_id, contact_id)
);

CREATE INDEX IF NOT EXISTS idx_patient_contacts_patient   ON patient_contacts (patient_id, prioridad_notificacion);
CREATE INDEX IF NOT EXISTS idx_patient_contacts_principal ON patient_contacts (patient_id, es_principal);

-- Mantener compatibilidad con la tabla original (vista)
CREATE OR REPLACE VIEW emergency_contacts AS
    SELECT
        pc.id           AS contact_id,
        pc.patient_id,
        c.nombre,
        c.telefono,
        pc.parentesco   AS relacion,
        pc.es_principal,
        pc.prioridad_notificacion,
        pc.created_at
    FROM patient_contacts pc
    JOIN contacts c ON c.contact_id = pc.contact_id;

-- ── 6. CONFIGURACIÓN DE UMBRALES ─────────────────────────────
CREATE TABLE IF NOT EXISTS thresholds (
    id                   SERIAL   PRIMARY KEY,
    patient_id           UUID     NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    bpm_min_normal       INTEGER  NOT NULL DEFAULT 60,
    bpm_max_normal       INTEGER  NOT NULL DEFAULT 100,
    bpm_min_moderate     INTEGER  NOT NULL DEFAULT 50,
    bpm_max_moderate     INTEGER  NOT NULL DEFAULT 130,
    spo2_min_normal      INTEGER  NOT NULL DEFAULT 95,
    spo2_min_moderate    INTEGER  NOT NULL DEFAULT 90,
    spo2_min_critical    INTEGER  NOT NULL DEFAULT 82,
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 7. EXPORTACIONES (registro de PDFs/Excel generados) ───────
CREATE TABLE IF NOT EXISTS export_logs (
    export_id    UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id   UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    requested_by UUID        NOT NULL REFERENCES users(id),
    format       VARCHAR(10) NOT NULL CHECK (format IN ('PDF', 'EXCEL')),
    date_from    TIMESTAMPTZ NOT NULL,
    date_to      TIMESTAMPTZ NOT NULL,
    file_size_kb INTEGER     NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── FIN ───────────────────────────────────────────────────────
