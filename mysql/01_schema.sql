-- =============================================================================
-- OASIS — Observação Agroambiental Sensorizada, Inteligente e Sustentável
-- Esquema relacional · MySQL 8.0.16+ (CHECK constraints ativas) / MariaDB 10.5+
--
-- Equivalente ao esquema PostgreSQL. Datas/horas armazenadas em UTC (DATETIME(6)).
-- =============================================================================

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS organizations (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(120) NOT NULL,
    city        VARCHAR(80)  NULL,
    active      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    UNIQUE KEY ix_organizations_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Exportadoras: base do isolamento de dados';

CREATE TABLE IF NOT EXISTS international_clients (
    id                    INT AUTO_INCREMENT PRIMARY KEY,
    organization_id       INT          NOT NULL,
    company_name          VARCHAR(120) NOT NULL,
    country               VARCHAR(60)  NOT NULL,
    contact_name_enc      TEXT         NULL,
    email_enc             TEXT         NULL,
    phone_enc             TEXT         NULL,
    tax_id_enc            TEXT         NULL,
    commercial_terms_enc  TEXT         NULL,
    active                BOOLEAN      NOT NULL DEFAULT TRUE,
    created_by            INT          NULL,
    created_at            DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at            DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    UNIQUE KEY uq_clients_org_company (organization_id, company_name),
    KEY ix_international_clients_organization_id (organization_id),
    CONSTRAINT fk_clients_organization FOREIGN KEY (organization_id) REFERENCES organizations (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Clientes internacionais; campos *_enc cifrados pela API (AES-256-GCM)';

CREATE TABLE IF NOT EXISTS users (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(120) NOT NULL,
    email           VARCHAR(160) NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    role            VARCHAR(20)  NOT NULL,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    last_login_at   DATETIME(6)  NULL,
    organization_id INT          NULL,
    client_id       INT          NULL,
    UNIQUE KEY ix_users_email (email),
    KEY ix_users_organization_id (organization_id),
    CONSTRAINT fk_users_organization FOREIGN KEY (organization_id) REFERENCES organizations (id),
    CONSTRAINT fk_users_client FOREIGN KEY (client_id) REFERENCES international_clients (id) ON DELETE SET NULL,
    CONSTRAINT ck_users_role CHECK (role IN ('admin','gestor','operador','cliente'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Usuários da plataforma OASIS';

CREATE TABLE IF NOT EXISTS varieties (
    id                VARCHAR(40)  PRIMARY KEY,
    name              VARCHAR(80)  NOT NULL,
    type              VARCHAR(10)  NOT NULL,
    color             VARCHAR(80)  NOT NULL,
    maturation_cycle  VARCHAR(60)  NOT NULL,
    origin            VARCHAR(120) NOT NULL,
    CONSTRAINT ck_varieties_type CHECK (type IN ('Tinta','Branca'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Variedades de uva monitoradas';

-- Status (online/atenção/offline/inativo) é calculado pela API — ver v_sensor_status.
CREATE TABLE IF NOT EXISTS sensors (
    id                    VARCHAR(20)  PRIMARY KEY,
    name                  VARCHAR(80)  NOT NULL,
    block                 VARCHAR(40)  NOT NULL,
    location              VARCHAR(120) NOT NULL,
    latitude              DOUBLE       NULL,
    longitude             DOUBLE       NULL,
    variety_id            VARCHAR(40)  NOT NULL,
    device                VARCHAR(60)  NULL,
    firmware              VARCHAR(20)  NULL,
    battery               INT          NULL,
    signal_dbm            INT          NULL,
    capture_interval_min  INT          NOT NULL DEFAULT 90,
    active                BOOLEAN      NOT NULL DEFAULT TRUE,
    installed_at          DATE         NULL,
    last_communication    DATETIME(6)  NULL,
    device_token_hash     VARCHAR(255) NULL,
    organization_id       INT          NULL,
    created_at            DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    KEY ix_sensors_organization_id (organization_id),
    CONSTRAINT fk_sensors_variety FOREIGN KEY (variety_id) REFERENCES varieties (id),
    CONSTRAINT fk_sensors_organization FOREIGN KEY (organization_id) REFERENCES organizations (id),
    CONSTRAINT ck_sensors_battery  CHECK (battery IS NULL OR battery BETWEEN 0 AND 100),
    CONSTRAINT ck_sensors_lat      CHECK (latitude  IS NULL OR latitude  BETWEEN -90  AND 90),
    CONSTRAINT ck_sensors_lng      CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
    CONSTRAINT ck_sensors_coords   CHECK ((latitude IS NULL) = (longitude IS NULL)),
    CONSTRAINT ck_sensors_interval CHECK (capture_interval_min BETWEEN 5 AND 1440)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Dispositivos ESP32 + câmera';

CREATE TABLE IF NOT EXISTS readings (
    id                 INT AUTO_INCREMENT PRIMARY KEY,
    code               VARCHAR(16) NULL,
    sensor_id          VARCHAR(20) NOT NULL,
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
    thumb_path         VARCHAR(255) NULL,
    source             VARCHAR(20) NOT NULL DEFAULT 'sensor',
    model_version      VARCHAR(80) NOT NULL,
    predicted_variety  VARCHAR(40),                         -- variedade prevista pela foto (classificador YOLO de variedades)
    variety_confidence DOUBLE,                         -- probabilidade da previsão (0–1)
    processing_ms      INT         NOT NULL DEFAULT 0,
    stage              VARCHAR(12) NOT NULL DEFAULT 'concluida',
    created_by         INT         NULL,
    created_at         DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    UNIQUE KEY uq_readings_code (code),
    UNIQUE KEY uq_readings_sensor_time (sensor_id, captured_at),
    KEY ix_readings_captured_at (captured_at),
    KEY ix_readings_variety_time (variety_id, captured_at),
    KEY ix_readings_quality_time (quality, captured_at),
    CONSTRAINT fk_readings_sensor  FOREIGN KEY (sensor_id)  REFERENCES sensors (id),
    CONSTRAINT fk_readings_variety FOREIGN KEY (variety_id) REFERENCES varieties (id),
    CONSTRAINT fk_readings_user    FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL,
    CONSTRAINT ck_readings_quality    CHECK (quality IN ('boa','atencao','critica')),
    CONSTRAINT ck_readings_stage      CHECK (stage IN ('recebida','processando','analisando','concluida')),
    CONSTRAINT ck_readings_maturation CHECK (maturation IN ('desenvolvimento','pintor','maturacao','adequada','sobrematuracao','nao_informada')),
    CONSTRAINT ck_readings_confidence CHECK (confidence BETWEEN 0 AND 1),
    CONSTRAINT ck_readings_source     CHECK (source IN ('sensor','upload','importacao','demonstracao'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Resultado de cada imagem analisada ou registro importado';

CREATE TABLE IF NOT EXISTS detections (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    reading_id  INT         NOT NULL,
    kind        VARCHAR(10) NOT NULL,
    label       VARCHAR(40) NOT NULL,
    confidence  DOUBLE      NOT NULL,
    x           DOUBLE      NOT NULL,
    y           DOUBLE      NOT NULL,
    w           DOUBLE      NOT NULL,
    h           DOUBLE      NOT NULL,
    KEY ix_detections_reading_id (reading_id),
    CONSTRAINT fk_detections_reading FOREIGN KEY (reading_id) REFERENCES readings (id) ON DELETE CASCADE,
    CONSTRAINT ck_detections_kind CHECK (kind IN ('cacho','anomalia')),
    CONSTRAINT ck_detections_box  CHECK (x >= 0 AND y >= 0 AND w > 0 AND h > 0 AND x + w <= 1.0001 AND y + h <= 1.0001)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Caixas detectadas (normalizadas 0–1)';

CREATE TABLE IF NOT EXISTS sensor_telemetry (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    sensor_id    VARCHAR(20) NOT NULL,
    received_at  DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    battery      INT         NULL,
    signal_dbm   INT         NULL,
    firmware     VARCHAR(20) NULL,
    KEY ix_sensor_telemetry_sensor_time (sensor_id, received_at),
    CONSTRAINT fk_telemetry_sensor FOREIGN KEY (sensor_id) REFERENCES sensors (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Bateria, sinal e firmware informados pelos dispositivos';

CREATE TABLE IF NOT EXISTS environment_readings (
    id                 INT AUTO_INCREMENT PRIMARY KEY,
    sensor_id          VARCHAR(20) NOT NULL,
    measured_at        DATETIME(6) NOT NULL,
    temperature_c      DOUBLE      NULL,
    humidity_pct       DOUBLE      NULL,
    luminosity_lux     DOUBLE      NULL,
    soil_moisture_pct  DOUBLE      NULL,
    source             VARCHAR(20) NOT NULL DEFAULT 'sensor',
    UNIQUE KEY uq_environment_sensor_time (sensor_id, measured_at),
    KEY ix_environment_sensor_time (sensor_id, measured_at),
    CONSTRAINT fk_environment_sensor FOREIGN KEY (sensor_id) REFERENCES sensors (id) ON DELETE CASCADE,
    CONSTRAINT ck_environment_temperature CHECK (temperature_c IS NULL OR temperature_c BETWEEN -20 AND 60),
    CONSTRAINT ck_environment_humidity    CHECK (humidity_pct IS NULL OR humidity_pct BETWEEN 0 AND 100),
    CONSTRAINT ck_environment_luminosity  CHECK (luminosity_lux IS NULL OR luminosity_lux BETWEEN 0 AND 200000),
    CONSTRAINT ck_environment_soil        CHECK (soil_moisture_pct IS NULL OR soil_moisture_pct BETWEEN 0 AND 100),
    CONSTRAINT ck_environment_source      CHECK (source IN ('sensor','manual','importacao','demonstracao'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Medições ambientais do talhão';

CREATE TABLE IF NOT EXISTS import_jobs (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    kind         VARCHAR(20)  NOT NULL,
    filename     VARCHAR(255) NOT NULL,
    status       VARCHAR(20)  NOT NULL,
    total_rows   INT          NOT NULL DEFAULT 0,
    inserted     INT          NOT NULL DEFAULT 0,
    updated      INT          NOT NULL DEFAULT 0,
    duplicates   INT          NOT NULL DEFAULT 0,
    invalid      INT          NOT NULL DEFAULT 0,
    errors_json  TEXT         NOT NULL,
    created_by   INT          NULL,
    organization_id INT       NULL,
    created_at   DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_import_user FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL,
    CONSTRAINT fk_import_organization FOREIGN KEY (organization_id) REFERENCES organizations (id),
    CONSTRAINT ck_import_kind   CHECK (kind IN ('readings','sensors','environment')),
    CONSTRAINT ck_import_status CHECK (status IN ('concluida','parcial','sem_alteracoes','falhou'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Registro das importações de arquivos';

CREATE TABLE IF NOT EXISTS audit_log (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    created_at  DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actor       VARCHAR(160) NULL,
    action      VARCHAR(60)  NOT NULL,
    target      VARCHAR(160) NULL,
    details     TEXT         NULL,
    ip          VARCHAR(64)  NULL,
    KEY ix_audit_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Trilha de auditoria';
