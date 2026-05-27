-- ==============================================================
-- init_pmv2.sql — Schema completo PMV2
-- Motor: PostgreSQL 15 + TimescaleDB
-- ==============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

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
    base_bio_profile JSONB        NULL DEFAULT '{}',
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email           ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_supervisor_email ON users (supervisor_email);
CREATE INDEX IF NOT EXISTS idx_users_bio_profile      ON users USING gin (base_bio_profile);

CREATE TABLE IF NOT EXISTS iot_sessions (
    session_token   CHAR(6)       PRIMARY KEY,
    patient_id      UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    stream_status   iot_stream_status NOT NULL DEFAULT 'DISCONNECTED',
    last_heartbeat  TIMESTAMPTZ   NULL,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ   NOT NULL DEFAULT (NOW() + INTERVAL '24 hours')
);

CREATE INDEX IF NOT EXISTS idx_iot_sessions_patient ON iot_sessions (patient_id);

CREATE TABLE IF NOT EXISTS biometric_signals (
    "time"          TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    device_id       UUID           NOT NULL,
    patient_id      UUID           NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_token   CHAR(6)        NULL REFERENCES iot_sessions(session_token) ON DELETE SET NULL,
    heart_rate      INTEGER        NOT NULL,
    spo2            INTEGER        NOT NULL,
    resp_rate       INTEGER        NULL,
    status_movement movement_status NOT NULL DEFAULT 'UNKNOWN',
    source          VARCHAR(20)    NOT NULL DEFAULT 'iot',
    PRIMARY KEY ("time", device_id)
);

SELECT create_hypertable(
    'biometric_signals',
    'time',
    if_not_exists => TRUE,
    chunk_time_interval => INTERVAL '1 day'
);

SELECT add_retention_policy('biometric_signals', INTERVAL '90 days', if_not_exists => TRUE);

CREATE INDEX IF NOT EXISTS idx_biometric_patient_time
    ON biometric_signals (patient_id, "time" DESC);
CREATE INDEX IF NOT EXISTS idx_biometric_session
    ON biometric_signals (session_token, "time" DESC);

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
    sma_spo2          DOUBLE PRECISION NULL,
    sma_bpm           DOUBLE PRECISION NULL
);

CREATE INDEX IF NOT EXISTS idx_risk_events_patient ON risk_events (patient_id, detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_risk_events_level   ON risk_events (risk_level, detected_at DESC);

CREATE TABLE IF NOT EXISTS contacts (
    contact_id  UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre      VARCHAR(150) NOT NULL,
    telefono    VARCHAR(25)  NOT NULL,
    email       VARCHAR(255) NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS patient_contacts (
    id                       UUID    PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id               UUID    NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    contact_id               UUID    NOT NULL REFERENCES contacts(contact_id) ON DELETE CASCADE,
    parentesco               VARCHAR(80) NOT NULL DEFAULT 'Familiar',
    prioridad_notificacion   SMALLINT   NOT NULL DEFAULT 1
        CHECK (prioridad_notificacion BETWEEN 1 AND 3),
    es_principal             BOOLEAN    NOT NULL DEFAULT FALSE,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (patient_id, contact_id)
);

CREATE INDEX IF NOT EXISTS idx_patient_contacts_patient   ON patient_contacts (patient_id, prioridad_notificacion);
CREATE INDEX IF NOT EXISTS idx_patient_contacts_principal ON patient_contacts (patient_id, es_principal);

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
