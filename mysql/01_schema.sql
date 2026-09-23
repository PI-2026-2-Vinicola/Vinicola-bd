-- =============================================================================
-- OSAIS — Observação Agroambiental Sensorizada, Inteligente e Sustentável
-- Esquema relacional · MySQL 8.0.16+ (CHECK constraints ativas) / MariaDB 10.5+
--
-- Equivalente ao esquema PostgreSQL. Datas/horas armazenadas em UTC (DATETIME(6)).
-- =============================================================================

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS users (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(120) NOT NULL,
    email           VARCHAR(160) NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    role            VARCHAR(20)  NOT NULL,
    created_at      DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    UNIQUE KEY ix_users_email (email),
    CONSTRAINT ck_users_role CHECK (role IN ('admin','gestor','operador'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Usuários da plataforma OSAIS';

CREATE TABLE IF NOT EXISTS varieties (
    id                VARCHAR(40)  PRIMARY KEY,
    name              VARCHAR(80)  NOT NULL,
    type              VARCHAR(10)  NOT NULL,
    color             VARCHAR(80)  NOT NULL,
    maturation_cycle  VARCHAR(60)  NOT NULL,
    origin            VARCHAR(120) NOT NULL,
    CONSTRAINT ck_varieties_type CHECK (type IN ('Tinta','Branca'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Variedades de uva monitoradas';

CREATE TABLE IF NOT EXISTS sensors (
    id                    VARCHAR(10)  PRIMARY KEY,
    name                  VARCHAR(80)  NOT NULL,
    block                 VARCHAR(40)  NOT NULL,
    location              VARCHAR(120) NOT NULL,
    latitude              DOUBLE       NOT NULL,
    longitude             DOUBLE       NOT NULL,
    variety_id            VARCHAR(40)  NOT NULL,
    device                VARCHAR(60)  NOT NULL,
    firmware              VARCHAR(20)  NOT NULL,
    battery               INT          NOT NULL DEFAULT 100,
    signal_dbm            INT          NOT NULL DEFAULT -60,
    capture_interval_min  INT          NOT NULL DEFAULT 90,
    status                VARCHAR(10)  NOT NULL DEFAULT 'online',
    installed_at          DATE         NOT NULL,
    last_communication    DATETIME(6)  NULL,
    device_token_hash     VARCHAR(255) NULL,
    CONSTRAINT fk_sensors_variety FOREIGN KEY (variety_id) REFERENCES varieties (id),
    CONSTRAINT ck_sensors_status  CHECK (status IN ('online','atencao','offline')),
    CONSTRAINT ck_sensors_battery CHECK (battery BETWEEN 0 AND 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Dispositivos ESP32 + câmera';

CREATE TABLE IF NOT EXISTS readings (
    id                 INT AUTO_INCREMENT PRIMARY KEY,
    code               VARCHAR(16) NULL,
    sensor_id          VARCHAR(10) NOT NULL,
    captured_at        DATETIME(6) NOT NULL,
    variety_id         VARCHAR(40) NOT NULL,
    quality            VARCHAR(10) NOT NULL,
    confidence         DOUBLE      NOT NULL,
    maturation         VARCHAR(20) NOT NULL,
    visual_condition   VARCHAR(60) NOT NULL,
    classification     VARCHAR(30) NOT NULL,
    observations       TEXT        NOT NULL,
    clusters_detected  INT         NOT NULL DEFAULT 1,
    image_path         VARCHAR(255) NULL,
    image_seed         INT         NOT NULL DEFAULT 0,
    model_version      VARCHAR(60) NOT NULL,
    processing_ms      INT         NOT NULL DEFAULT 0,
    stage              VARCHAR(12) NOT NULL DEFAULT 'concluida',
    created_at         DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    UNIQUE KEY uq_readings_code (code),
    KEY ix_readings_captured_at (captured_at),
    KEY ix_readings_sensor_time (sensor_id, captured_at),
    KEY ix_readings_variety_time (variety_id, captured_at),
    KEY ix_readings_quality_time (quality, captured_at),
    CONSTRAINT fk_readings_sensor  FOREIGN KEY (sensor_id)  REFERENCES sensors (id),
    CONSTRAINT fk_readings_variety FOREIGN KEY (variety_id) REFERENCES varieties (id),
    CONSTRAINT ck_readings_quality    CHECK (quality IN ('boa','atencao','critica')),
    CONSTRAINT ck_readings_stage      CHECK (stage IN ('recebida','processando','analisando','concluida')),
    CONSTRAINT ck_readings_maturation CHECK (maturation IN ('desenvolvimento','pintor','maturacao','adequada','sobrematuracao')),
    CONSTRAINT ck_readings_confidence CHECK (confidence BETWEEN 0 AND 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Imagens processadas e resultado da IA';

CREATE TABLE IF NOT EXISTS detections (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    reading_id  INT          NOT NULL,
    kind        VARCHAR(10)  NOT NULL,
    label       VARCHAR(40)  NOT NULL,
    confidence  DOUBLE       NOT NULL,
    x           DOUBLE       NOT NULL,
    y           DOUBLE       NOT NULL,
    w           DOUBLE       NOT NULL,
    h           DOUBLE       NOT NULL,
    KEY ix_detections_reading_id (reading_id),
    CONSTRAINT fk_detections_reading FOREIGN KEY (reading_id) REFERENCES readings (id) ON DELETE CASCADE,
    CONSTRAINT ck_detections_kind CHECK (kind IN ('cacho','anomalia'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Caixas detectadas pelo YOLO (normalizadas 0–1)';

CREATE TABLE IF NOT EXISTS sensor_telemetry (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    sensor_id    VARCHAR(10) NOT NULL,
    received_at  DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    battery      INT NULL,
    signal_dbm   INT NULL,
    firmware     VARCHAR(20) NULL,
    KEY ix_sensor_telemetry_sensor_id (sensor_id),
    CONSTRAINT fk_telemetry_sensor FOREIGN KEY (sensor_id) REFERENCES sensors (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Bateria, sinal e firmware enviados pelos dispositivos';
